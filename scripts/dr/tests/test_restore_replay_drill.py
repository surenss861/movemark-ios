"""Restore-and-replay drill: a deleted account stays deleted after a restore, and nothing current is lost.

Local only: a throwaway PostgreSQL 18 source cluster stands in for Neon, the fake B2 for Backblaze. It runs the
real backup.py, offsite.py (push-db, sync-evidence, pull), deletion_log.py, retention.py and restore.py:

    accounts A and B with rentals and files -> backup -> delete A and one rental of B -> export the log ->
    restore the backup taken BEFORE those deletions, with its files -> replay

    ../movemark-api-py/.venv/bin/python -m pytest scripts/dr/tests/test_restore_replay_drill.py -q
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from typing import Any, Iterator

import deletion_log as dl
import psycopg
import pytest
import retention
from conftest import DB, EV, SRC, World
from psycopg import errors

ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "neon" / "tests"))
from test_reconstruction import seed_rental  # noqa: E402

PG_BIN = pathlib.Path(os.getenv("MOVEMARK_PG18_BIN", "/opt/homebrew/opt/postgresql@18/bin"))
SOURCE_PORT, RESTORE_PORT = 5561, 5562
STAMP = "%Y%m%dT%H%M%SZ"
os.environ.setdefault("LC_ALL", "en_US.UTF-8")  # the postmaster refuses to start on macOS without a valid locale

pytestmark = pytest.mark.skipif(not (PG_BIN / "initdb").exists(), reason="needs PostgreSQL 18 binaries")


def utcnow() -> datetime.datetime:
    return datetime.datetime.now(datetime.UTC).replace(microsecond=0)


def pg(*cmd: str) -> None:
    subprocess.run([str(PG_BIN / cmd[0]), *cmd[1:]], check=True, capture_output=True)


@pytest.fixture(scope="module")
def source() -> Iterator[dict]:
    """PostgreSQL 18 on every migration, with a ledger, owned by `postgres` as restore.py expects of a dump."""
    base = pathlib.Path(tempfile.mkdtemp(prefix="mmdrill-"))
    data = base / "pgdata"
    pg("initdb", "-D", str(data), "-U", "postgres", "--auth=trust", "--no-instructions")
    pg("pg_ctl", "-D", str(data), "-l", str(base / "pg.log"), "-o",
       f"-p {SOURCE_PORT} -k {base} -c listen_addresses=127.0.0.1", "-w", "start")
    admin = f"postgresql://postgres@127.0.0.1:{SOURCE_PORT}/postgres"
    dsn = f"postgresql://postgres@127.0.0.1:{SOURCE_PORT}/neondb"
    try:
        with psycopg.connect(admin, autocommit=True) as conn:
            conn.execute("CREATE DATABASE neondb")
        build(dsn, sorted((ROOT / "neon" / "migrations").glob("*.sql")))
        yield {"admin": admin, "dsn": dsn}
    finally:
        subprocess.run([str(PG_BIN / "pg_ctl"), "-D", str(data), "-m", "immediate", "stop"], capture_output=True)
        shutil.rmtree(base, ignore_errors=True)


def build(dsn: str, files: list[pathlib.Path]) -> None:
    with psycopg.connect(dsn, autocommit=True) as conn:
        conn.execute((ROOT / "neon" / "tests" / "neon_platform_shim.sql").read_text())
        for path in files:
            conn.execute(path.read_text())
        conn.execute("CREATE SCHEMA IF NOT EXISTS movemark_meta")
        conn.execute("""CREATE TABLE movemark_meta.schema_migrations (version text PRIMARY KEY, filename text NOT NULL,
                        sha256 text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now(),
                        applied_by text NOT NULL DEFAULT current_user, method text NOT NULL, runner_commit text)""")
        conn.execute("INSERT INTO movemark_meta.schema_migrations (version, filename, sha256, method) VALUES (%s, 'x', 'x', 'runner')",
                     (files[-1].name[:4],))


def add_user(dsn: str, name: str) -> str:
    uid = str(uuid.uuid4())
    with psycopg.connect(dsn, autocommit=True) as conn:
        conn.execute('INSERT INTO neon_auth."user" (id, email) VALUES (%s, %s)', (uid, f"{name}@qa.test"))
    return uid


def add_rental(dsn: str, uid: str) -> str:
    with psycopg.connect(dsn, autocommit=True) as conn:
        return str(conn.execute("""INSERT INTO properties (user_id, title, address_line_1, city, province_state, postal_code, country)
            VALUES (%s, 'second', '1 Test St', 'Toronto', 'ON', 'M5J', 'CA') RETURNING id""", (uid,)).fetchone()[0])


def run_backup(dsn: str, key_file: pathlib.Path, out: pathlib.Path) -> pathlib.Path:
    result = subprocess.run([sys.executable, str(ROOT / "scripts" / "dr" / "backup.py"), "--project", "drill", "--branch", "drill",
                             "--key-file", str(key_file), "--out", str(out), "--database-only", "--dsn-env", "DRILL_DSN"],
                            capture_output=True, text=True, env={**os.environ, "DRILL_DSN": dsn})
    assert result.returncode == 0, result.stderr[-1500:]
    return pathlib.Path(re.search(r"backup written: (\S+)", result.stdout).group(1))


def export(world: World, dsn: str) -> None:
    with psycopg.connect(dsn) as conn:
        dl.export_batch(conn, world.db, DB, world.key, world.now)


def delete_account_as_the_api_does(dsn: str, uid: str) -> None:
    with psycopg.connect(dsn, autocommit=True) as conn:
        with conn.transaction():
            conn.execute("SELECT public.delete_user_owned_data(%s)", (uid,))
            conn.execute("DELETE FROM public.storage_upload_tickets WHERE user_id = %s", (uid,))
        conn.execute("SELECT public.delete_auth_user(%s)", (uid,))


@pytest.fixture(scope="module")
def scenario(source: dict, tmp_path_factory: pytest.TempPathFactory) -> Iterator[dict]:
    """The timeline, run once. The clock is real here, because backup.py stamps the archive itself."""
    tmp = tmp_path_factory.mktemp("scenario")
    mp = pytest.MonkeyPatch()
    mp.setenv("MOVEMARK_TEST_ADMIN_DSN", source["admin"])
    world = World(tmp, mp)
    dsn = source["dsn"]

    world.now = utcnow()
    export(world, dsn)  # an earlier heartbeat: batch 1, from before the backup

    a, b = add_user(dsn, "a"), add_user(dsn, "b")
    a_ids, b_ids = seed_rental(dsn, a), seed_rental(dsn, b)
    b_gone = add_rental(dsn, b)
    a_files = [(SRC, f"{a}/{a_ids['property']}/move-in/{a_ids['room']}/1.jpg"), (SRC, f"{a}/{a_ids['property']}/move-in/{a_ids['room']}/1_thumb.jpg"),
               ("leases", f"{a}/{a_ids['property']}/lease/l.pdf"), ("maintenance-media", f"{a.upper()}/{a_ids['property']}/old-swift.jpg")]
    b_files = [(SRC, f"{b}/{b_ids['property']}/move-in/{b_ids['room']}/1.jpg"), (SRC, f"{b}/{b_ids['property']}/move-in/{b_ids['room']}/1_thumb.jpg"),
               ("leases", f"{b}/{b_ids['property']}/lease/l.pdf")]
    b_gone_file = (SRC, f"{b}/{b_gone}/move-in/r/9.jpg")
    for bucket, key in a_files + [b_gone_file]:
        world.upload(key, bucket=bucket)
    b_bodies = {item: world.upload(item[1], bucket=item[0]) for item in b_files}

    # the backup that will be restored
    archive = run_backup(dsn, world.key_file, tmp / "out")
    world.now = utcnow() + datetime.timedelta(seconds=1)
    retention.offsite.push_db(argparse.Namespace(archive=archive))
    world.sync()
    export(world, dsn)
    before = tmp / "pulled-before-the-deletions"
    retention.offsite.pull(argparse.Namespace(key_file=world.key_file, to=before))

    # the deletions, after that backup
    delete_account_as_the_api_does(dsn, a)
    with psycopg.connect(dsn, autocommit=True) as conn:
        conn.execute("SELECT * FROM public.delete_property_owned_data(%s, %s)", (b, b_gone)).fetchall()
    for bucket, key in a_files + [b_gone_file]:
        world.remove(key, bucket=bucket)
    world.now = utcnow() + datetime.timedelta(seconds=2)
    export(world, dsn)
    world.sync()

    log = tmp / "log"
    dl.cmd_pull(argparse.Namespace(key_file=world.key_file, to=log))
    latest = tmp / "pulled-latest"
    retention.offsite.pull(argparse.Namespace(key_file=world.key_file, to=latest))
    yield {"world": world, "dsn": dsn, "a": a, "b": b, "a_files": a_files, "b_files": b_files, "b_gone": b_gone,
           "b_gone_file": b_gone_file, "b_bodies": b_bodies, "b_ids": b_ids, "before": before, "latest": latest, "log": log, "tmp": tmp}
    mp.undo()


class Restored:
    def __init__(self, result: subprocess.CompletedProcess, work: pathlib.Path) -> None:
        self.out, self.err, self.code, self.work = result.stdout, result.stderr, result.returncode, work
        match = re.search(r"RESTORED_CLUSTER host=(\S+) port=(\d+)", self.out)
        self.running = bool(match)
        self.host, self.port = match.groups() if match else ("", "")

    def dsn(self, role: str = "postgres") -> str:
        return f"postgresql://{role}@/neondb?host={self.host}&port={self.port}"

    def stop(self) -> None:
        if self.running:
            subprocess.run([str(PG_BIN / "pg_ctl"), "-D", str(self.work / "pgdata"), "-m", "fast", "stop"], capture_output=True)
            self.running = False

    def report(self) -> dict:
        return json.loads(next(line for line in self.out.splitlines() if line.startswith("{")))


def restore(scenario: dict, pulled: pathlib.Path, name: str, *extra: str, log: pathlib.Path | None = None, evidence: bool = True) -> Restored:
    work = scenario["tmp"] / name
    command = [sys.executable, str(ROOT / "scripts" / "dr" / "restore.py"), "--archive", str(next(pulled.glob("*.mmbk"))),
               "--key-file", str(scenario["world"].key_file), "--workdir", str(work),
               "--port", str(RESTORE_PORT), "--keep-running", *extra]
    if evidence:
        command += ["--evidence", str(pulled / "evidence")]
    if log is not None:
        command += ["--deletion-log", str(log)]
    return Restored(subprocess.run(command, capture_output=True, text=True, env=dict(os.environ)), work)


def count_for(conn: Any, uid: str) -> int:
    """Rows about one account, anywhere it can be named."""
    total = conn.execute('SELECT count(*) FROM neon_auth."user" WHERE id = %s', (uid,)).fetchone()[0]
    for (table,) in conn.execute("""SELECT table_name FROM information_schema.columns c JOIN information_schema.tables t
            USING (table_schema, table_name) WHERE c.table_schema = 'public' AND t.table_type = 'BASE TABLE'
            AND c.column_name = 'user_id'""").fetchall():
        total += conn.execute(f'SELECT count(*) FROM public."{table}" WHERE user_id = %s', (uid,)).fetchone()[0]
    return total + conn.execute("SELECT count(*) FROM public.profiles WHERE id = %s", (uid,)).fetchone()[0]


# -- the main path ------------------------------------------------------------------------

@pytest.fixture(scope="module")
def replayed(scenario: dict) -> Iterator[Restored]:
    result = restore(scenario, scenario["before"], "replayed", log=scenario["log"])
    yield result
    result.stop()


def test_the_restore_passes_and_opens(replayed: Restored) -> None:
    assert "RESTORE_DRILL PASS" in replayed.out, replayed.out[-1500:] + replayed.err[-1500:]
    assert "SERVICE_UNFENCED" in replayed.out


def test_the_backup_really_held_the_deleted_account(scenario: dict) -> None:
    """Otherwise the rest of this file proves nothing: the archive predates the deletion and has A's files."""
    manifest = (scenario["before"] / "evidence" / "manifest.tsv").read_text()
    assert scenario["a"] in manifest
    meta = json.loads(next(scenario["before"].glob("*.json")).read_text())
    assert meta["row_counts"]["neon_auth.user"] == 2


def test_the_deleted_account_stays_deleted(replayed: Restored, scenario: dict) -> None:
    with psycopg.connect(replayed.dsn()) as conn:
        assert count_for(conn, scenario["a"]) == 0
        assert conn.execute('SELECT count(*) FROM neon_auth."user" WHERE email = %s', ("a@qa.test",)).fetchone()[0] == 0


def test_the_deleted_accounts_files_stay_deleted(replayed: Restored, scenario: dict) -> None:
    for bucket, key in scenario["a_files"]:
        assert not (replayed.work / "objects" / bucket / key).exists()
    manifest = (replayed.work / "manifest.tsv").read_text().lower()
    assert scenario["a"] not in manifest


def test_the_deleted_rental_and_its_file_stay_deleted(replayed: Restored, scenario: dict) -> None:
    with psycopg.connect(replayed.dsn()) as conn:
        assert conn.execute("SELECT count(*) FROM public.properties WHERE id = %s", (scenario["b_gone"],)).fetchone()[0] == 0
    bucket, key = scenario["b_gone_file"]
    assert not (replayed.work / "objects" / bucket / key).exists()


def test_the_other_account_is_untouched(replayed: Restored, scenario: dict) -> None:
    with psycopg.connect(replayed.dsn()) as conn:
        assert conn.execute('SELECT count(*) FROM neon_auth."user" WHERE id = %s', (scenario["b"],)).fetchone()[0] == 1
        for table, column, value in (("properties", "id", "property"), ("rooms", "id", "room"), ("inspections", "id", "inspection"),
                                     ("evidence_files", "id", "evidence"), ("property_documents", "id", "document")):
            assert conn.execute(f"SELECT count(*) FROM public.{table} WHERE {column} = %s", (scenario["b_ids"][value],)).fetchone()[0] == 1
    for (bucket, key), body in scenario["b_bodies"].items():
        assert (replayed.work / "objects" / bucket / key).read_bytes() == body


def test_the_runtime_roles_can_log_in_afterwards(replayed: Restored, scenario: dict) -> None:
    with psycopg.connect(replayed.dsn("movemark_api")) as conn:
        assert conn.execute("SELECT count(*) FROM public.properties WHERE user_id = %s", (scenario["b"],)).fetchone()[0] == 1


def test_lifting_the_fence_gives_back_exactly_what_it_took(replayed: Restored, scenario: dict) -> None:
    query = """SELECT coalesce(r.rolname, 'PUBLIC'), a.privilege_type FROM pg_namespace n,
                      aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) a LEFT JOIN pg_roles r ON r.oid = a.grantee
                WHERE n.nspname = 'public' AND coalesce(r.rolname, 'PUBLIC') <> 'postgres' ORDER BY 1, 2"""
    with psycopg.connect(scenario["dsn"]) as before, psycopg.connect(replayed.dsn()) as after:
        assert after.execute(query).fetchall() == before.execute(query).fetchall()
        assert not dl.is_fenced(after)


def test_the_receipt_counts_and_identifies_no_one(replayed: Restored, scenario: dict) -> None:
    text = (replayed.work / "replay-receipt.json").read_text()
    receipt = json.loads(text)
    assert receipt["accounts_deleted"] == 1 and receipt["rentals_deleted"] == 1 and receipt["objects_removed"] == 5
    for subject in (scenario["a"], scenario["b"], scenario["b_gone"]):
        assert subject not in text


def test_replaying_again_changes_nothing(replayed: Restored, scenario: dict) -> None:
    log = dl.verify(dl.read_dir(scenario["log"]), scenario["world"].key)
    with psycopg.connect(replayed.dsn(), autocommit=True) as conn:
        receipt = dl.replay(conn, log, json.loads(next(scenario["before"].glob("*.json")).read_text())["created_utc"])
    assert receipt["accounts_deleted"] == 0 and receipt["rentals_deleted"] == 0


def test_a_deletion_after_the_restore_reaches_the_log(replayed: Restored, scenario: dict) -> None:
    """A restored database rewound its table. The next export still has to carry the next deletion."""
    world = scenario["world"]
    uid = None
    with psycopg.connect(replayed.dsn(), autocommit=True) as conn:
        uid = str(conn.execute('SELECT id FROM neon_auth."user" WHERE email = %s', ("b@qa.test",)).fetchone()[0])
        conn.execute("SELECT public.record_deletion('account', %s)", (uid,))
        world.now = utcnow() + datetime.timedelta(seconds=3)
        dl.export_batch(conn, world.db, DB, world.key, world.now)
        conn.execute("DELETE FROM public.deletion_tombstones WHERE subject_hash = %s", (dl.subject_hash(uid),))
    log = dl.verify(dl.read_remote(world.db, DB), world.key)
    assert ("account", dl.subject_hash(uid)) in log.entries
    world.db.items = [i for i in world.db.items if not i.key.startswith("deletion-log/") or i.key in {
        f"deletion-log/{p.name}" for p in scenario["log"].iterdir()}]  # keep later tests on the original log


def test_stop_main_cluster(replayed: Restored) -> None:
    replayed.stop()  # one restore cluster at a time from here on
    assert not replayed.running


def test_the_export_command_works_as_the_read_only_backup_role(scenario: dict, source: dict, monkeypatch: pytest.MonkeyPatch) -> None:
    """The scheduled job reads with movemark_backup (1010), not the owner."""
    world = scenario["world"]
    original = list(world.db.items)
    monkeypatch.setenv("EXPORT_DSN", source["dsn"].replace("postgres@", "movemark_backup@"))
    assert dl.cmd_export(argparse.Namespace(key_file=world.key_file, dsn_env="EXPORT_DSN")) == 0
    log = dl.verify(dl.read_remote(world.db, DB), world.key)
    assert log.batches == 4 and len(log.entries) == 3  # a heartbeat, nothing repeated
    world.db.items = original


# -- the fence ----------------------------------------------------------------------------

def test_without_a_replay_the_service_can_not_start(scenario: dict) -> None:
    fenced = restore(scenario, scenario["before"], "fenced")
    try:
        assert "RESTORE_DRILL PASS" in fenced.out and "SERVICE_FENCED" in fenced.out, fenced.out[-1500:] + fenced.err[-800:]
        with pytest.raises(psycopg.OperationalError, match="not permitted to log in"):
            psycopg.connect(fenced.dsn("movemark_api"))
        with pytest.raises(psycopg.OperationalError, match="not permitted to log in"):
            psycopg.connect(fenced.dsn("movemark_worker"))
        for role in ("authenticated", "anonymous"):  # the Data API
            with psycopg.connect(fenced.dsn()) as conn:
                conn.execute(f"SET ROLE {role}")
                with pytest.raises(errors.InsufficientPrivilege):
                    conn.execute("SELECT * FROM public.properties")
        with psycopg.connect(fenced.dsn()) as conn:
            assert count_for(conn, scenario["a"]) > 0  # the account is back, and that is why the fence is up
        assert not (fenced.work / "objects").exists() and (fenced.work / "objects-fenced").is_dir()

        # the operator's second step finishes it, through the real command
        env = {**os.environ, "RESTORE_DSN": fenced.dsn()}
        created = next(scenario["before"].glob("*.json"))
        step = subprocess.run([sys.executable, str(ROOT / "scripts" / "dr" / "deletion_log.py"), "replay", "--key-file",
                               str(scenario["world"].key_file), "--log", str(scenario["log"]), "--dsn-env", "RESTORE_DSN",
                               "--as-of", json.loads(created.read_text())["created_utc"], "--objects",
                               str(fenced.work / "objects-fenced"), "--manifest", str(fenced.work / "manifest.tsv")],
                              capture_output=True, text=True, env=env)
        assert step.returncode == 0 and "REPLAY PASS" in step.stdout, step.stdout + step.stderr
        assert (fenced.work / "objects").is_dir() and not (fenced.work / "objects-fenced").exists()
        with psycopg.connect(fenced.dsn("movemark_api")) as conn:
            assert conn.execute('SELECT 1').fetchone() == (1,)
        with psycopg.connect(fenced.dsn()) as conn:
            assert count_for(conn, scenario["a"]) == 0
    finally:
        fenced.stop()


def test_a_tampered_log_keeps_the_fence_up(scenario: dict) -> None:
    log = scenario["tmp"] / "tampered-log"
    shutil.copytree(scenario["log"], log)
    victim = sorted(log.iterdir())[-1]
    victim.write_bytes(victim.read_bytes()[:-1] + b"\x00")
    bad = restore(scenario, scenario["before"], "tampered", log=log)
    bad.stop()
    assert bad.code != 0 and "RESTORE_DRILL FAIL" in bad.out and "LogRefused" in bad.out and "SERVICE_FENCED" in bad.out
    assert not bad.running and (bad.work / "objects-fenced").is_dir()


def test_a_missing_batch_keeps_the_fence_up(scenario: dict) -> None:
    log = scenario["tmp"] / "holed-log"
    shutil.copytree(scenario["log"], log)
    sorted(log.iterdir())[1].unlink()
    bad = restore(scenario, scenario["before"], "holed", log=log)
    bad.stop()
    assert bad.code != 0 and "is missing" in bad.out and "SERVICE_FENCED" in bad.out


def test_a_log_that_stops_before_the_backup_keeps_the_fence_up_until_the_owner_decides(scenario: dict) -> None:
    log = scenario["tmp"] / "stale-log"
    log.mkdir()
    first = sorted(scenario["log"].iterdir())[0]
    shutil.copy(first, log / first.name)
    bad = restore(scenario, scenario["before"], "stale", log=log)
    bad.stop()
    assert bad.code != 0 and "LogGap" in bad.out and "SERVICE_FENCED" in bad.out

    accepted = restore(scenario, scenario["before"], "stale-accepted", "--accept-log-gap", "owner decision, incident 1", log=log)
    try:
        assert "SERVICE_UNFENCED" in accepted.out, accepted.out[-1500:]
        receipt = json.loads((accepted.work / "replay-receipt.json").read_text())
        assert receipt["accepted_log_gap_reason"] == "owner decision, incident 1"
        with psycopg.connect(accepted.dsn()) as conn:  # the risk being accepted, in plain view
            assert count_for(conn, scenario["a"]) > 0
    finally:
        accepted.stop()


def test_the_latest_manifest_restores_too(scenario: dict) -> None:
    """The usual case: backup older than the manifest. The rows of A point at files already gone from it,
    which must not fail the restore, because replay removes those rows first."""
    good = restore(scenario, scenario["latest"], "latest", log=scenario["log"])
    try:
        assert "RESTORE_DRILL PASS" in good.out and "SERVICE_UNFENCED" in good.out, good.out[-1500:] + good.err[-800:]
        with psycopg.connect(good.dsn()) as conn:
            assert count_for(conn, scenario["a"]) == 0
    finally:
        good.stop()


def test_a_database_only_restore_replays_too(scenario: dict) -> None:
    good = restore(scenario, scenario["before"], "database-only", log=scenario["log"], evidence=False)
    try:
        assert "RESTORE_DRILL PASS" in good.out and "SERVICE_UNFENCED" in good.out, good.out[-1500:] + good.err[-800:]
        with psycopg.connect(good.dsn()) as conn:
            assert count_for(conn, scenario["a"]) == 0
    finally:
        good.stop()


def test_a_backup_from_before_1060_can_still_be_replayed(source: dict, scenario: dict) -> None:
    """No tombstones table and the old function bodies: the log alone must be enough."""
    dsn = source["admin"].rsplit("/", 1)[0] + "/pre1060"
    with psycopg.connect(source["admin"], autocommit=True) as admin:
        admin.execute("DROP DATABASE IF EXISTS pre1060 WITH (FORCE)")
        admin.execute("CREATE DATABASE pre1060")
    build(dsn, [p for p in sorted((ROOT / "neon" / "migrations").glob("*.sql")) if p.name[:4] <= "1050"])
    gone, kept = add_user(dsn, "gone"), add_user(dsn, "kept")
    seed_rental(dsn, gone)
    seed_rental(dsn, kept)
    log = dl.Log({("account", dl.subject_hash(gone)): "2026-11-07"}, 1, "20260101T000000Z", "20991231T000000Z", 2, "", True)
    with psycopg.connect(dsn, autocommit=True) as conn:
        receipt = dl.replay(conn, log, "20260601T000000Z")
        assert receipt["accounts_deleted"] == 1
        assert count_for(conn, gone) == 0 and count_for(conn, kept) > 0


# -- end to end with retention, last because it moves the clock ----------------------------

def test_85_days_on_a_prune_removes_the_deleted_and_a_restore_still_has_everything_current(scenario: dict) -> None:
    world, dsn, tmp = scenario["world"], scenario["dsn"], scenario["tmp"]
    world.now = utcnow() + datetime.timedelta(days=85)
    world.sync()
    export(world, dsn)
    # a real backup, renamed to the simulated date so the clocks agree
    fresh = run_backup(dsn, world.key_file, tmp / "out-85")
    stamp = world.now.strftime(STAMP)
    moved = fresh.with_name(re.sub(r"\d{8}T\d{6}Z", stamp, fresh.name))
    fresh.rename(moved)
    fresh.with_name(fresh.name + ".sha256").rename(moved.with_name(moved.name + ".sha256"))
    meta = json.loads(fresh.with_suffix(".json").read_text()) | {"created_utc": stamp}
    fresh.with_suffix(".json").unlink()
    moved.with_suffix(".json").write_text(json.dumps(meta))
    retention.offsite.push_db(argparse.Namespace(archive=moved))

    a_names = {f"objects/{bucket}/{key}" for bucket, key in scenario["a_files"]}
    assert a_names <= world.ev.keys(EV, "objects/"), "the deleted account's copies were still in B2 before the prune"
    code, report = retention.run(world.db, DB, world.ev, EV, world.key, world.now, retention.Policy(), True, True)
    assert code == 0, report
    assert not a_names & world.ev.keys(EV, "objects/"), "still stored, in any version"
    assert world.ev.bypass_requests == 0
    assert {f"objects/{bucket}/{key}" for bucket, key in scenario["b_files"]} <= world.ev.keys(EV, "objects/")

    pulled, log = tmp / "pulled-85", tmp / "log-85"
    retention.offsite.pull(argparse.Namespace(key_file=world.key_file, to=pulled))
    dl.cmd_pull(argparse.Namespace(key_file=world.key_file, to=log))
    good = restore(scenario, pulled, "restored-85", log=log)
    try:
        assert "RESTORE_DRILL PASS" in good.out and "SERVICE_UNFENCED" in good.out, good.out[-1500:] + good.err[-800:]
        for (bucket, key), body in scenario["b_bodies"].items():
            assert (good.work / "objects" / bucket / key).read_bytes() == body
        with psycopg.connect(good.dsn()) as conn:
            assert count_for(conn, scenario["a"]) == 0
            assert conn.execute('SELECT count(*) FROM neon_auth."user" WHERE id = %s', (scenario["b"],)).fetchone()[0] == 1
    finally:
        good.stop()
