"""MoveMark — the deletion log: what a restore must delete again, kept outside the database it protects.

PROPOSED, not live. Nothing schedules this yet; see docs/backup-retention-design.md.

    ../movemark-api-py/.venv/bin/python scripts/dr/deletion_log.py export --key-file <key> --dsn-env BACKUP_DATABASE_URL
    ../movemark-api-py/.venv/bin/python scripts/dr/deletion_log.py pull   --key-file <key> --to <empty dir>
    ../movemark-api-py/.venv/bin/python scripts/dr/deletion_log.py fence  --dsn-env RESTORE_DATABASE_URL
    ../movemark-api-py/.venv/bin/python scripts/dr/deletion_log.py replay --key-file <key> --log <dir> \\
        --dsn-env RESTORE_DATABASE_URL --as-of <UTC stamp> [--objects <dir> --manifest <file>] [--accept-log-gap <reason>]

export   appends one batch to deletion-log/ in the B2 DB bucket: every row of public.deletion_tombstones (1060)
         not yet in the log. It writes a batch even when there is nothing new. That heartbeat is how replay
         tells "no deletions happened" from "the export had stopped".
pull     copies the log out of B2 and verifies it. It reads B2 only.
fence    closes a database to the service: runtime roles can't log in, the Data API roles lose schema public.
         scripts/dr/restore.py fences every restore itself. Use this for a restore done any other way, such as a
         Neon point-in-time restore, before anything can reach it.
replay   deletes every logged account and rental found in a restored database and its restored files, checks
         that none remain, and only then lifts the fence. Safe to run twice.

The log is a chain of batches sealed with the backup key. Each names the SHA-256 of the one before, so a
removed, altered or reordered batch stops replay. It holds salted hashes of opaque ids, the kind and the day:
no email, no name, no raw id. Replay finds its targets by hashing what is in the restored database.

Replay refuses a log it can't trust. A chain that fails verification is final. A log that doesn't span the
restored backup (a gap) means some deletions can't be known, and only --accept-log-gap continues, with the
reason written to the receipt. That decision belongs to the owner.
"""
from __future__ import annotations

import argparse
import dataclasses
import datetime
import hashlib
import importlib.util
import json
import os
import pathlib
import re
import sys

import psycopg
from psycopg import sql

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("offsite", ROOT / "scripts" / "dr" / "offsite.py")
offsite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(offsite)

PREFIX = "deletion-log/"
NAME = re.compile(r"^deletion-log/(\d{8}T\d{6}Z)-(\d{8})\.json\.mmob$")
SALT = "movemark-deletion-v1:"  # = public.record_deletion (1060)
TRACKER_DAYS = 120  # = public.record_deletion (1060), retention.Policy.tracker_days
KINDS = ("account", "property")
FENCED_LOGINS = ("movemark_api", "movemark_worker", "movemark_backup")
DATA_API_ROLES = ("anonymous", "authenticated")
STAMP = "%Y%m%dT%H%M%SZ"


class LogRefused(Exception):
    """The log can't be trusted. No override exists."""


class LogGap(Exception):
    """The log is sound but doesn't span the restore point."""


class ReplayFailed(Exception):
    """Replay ran and something deleted is still there. The fence stays up."""


def subject_hash(subject: str) -> str:
    return hashlib.sha256((SALT + subject.lower()).encode()).hexdigest()


# -- the log ---------------------------------------------------------------------------

@dataclasses.dataclass(frozen=True)
class Log:
    entries: dict[tuple[str, str], str]  # (kind, subject_hash): day
    batches: int
    oldest_stamp: str | None
    newest_stamp: str | None
    next_seq: int
    head_sha256: str
    genesis: bool  # the oldest batch is the first ever written, so nothing has aged out

    def hashes(self, kind: str) -> set[str]:
        return {h for k, h in self.entries if k == kind}


def verify(batches: list[tuple[str, bytes]], key: bytes) -> Log:
    """Check a whole log: every batch authentic and at its own name, numbered without a hole, each chained
    to the one before. Raises LogRefused otherwise."""
    entries: dict[tuple[str, str], str] = {}
    previous: dict | None = None
    head = ""
    oldest = newest = None
    genesis = False
    for name, sealed in sorted(batches, key=lambda item: _seq(item[0])):
        try:
            body = json.loads(offsite.unseal(key, name, sealed))
        except Exception as error:  # noqa: BLE001 — wrong key, altered, moved or not JSON: all mean the same here
            raise LogRefused(f"{name}: can't be authenticated ({type(error).__name__})") from error
        stamp, seq = _parts(name)
        if body.get("v") != 1 or body.get("seq") != seq or body.get("created_utc") != stamp:
            raise LogRefused(f"{name}: header doesn't match its name")
        if previous is None:
            oldest = stamp
            genesis = seq == 1 and body.get("prev_sha256") == ""
        else:
            if seq != previous["seq"] + 1:
                raise LogRefused(f"{name}: batch {previous['seq'] + 1} is missing")
            if body.get("prev_sha256") != head:
                raise LogRefused(f"{name}: doesn't chain to the batch before it")
            if stamp < previous["created_utc"]:
                raise LogRefused(f"{name}: older than the batch before it")
        for entry in body.get("entries", ()):
            if entry.get("k") not in KINDS or not re.fullmatch(r"[0-9a-f]{64}", entry.get("h", "")):
                raise LogRefused(f"{name}: malformed entry")
            entries[(entry["k"], entry["h"])] = entry.get("d", "")
        previous, newest, head = body, stamp, hashlib.sha256(sealed).hexdigest()
    next_seq = previous["seq"] + 1 if previous else 1
    return Log(entries, len(batches), oldest, newest, next_seq, head, genesis)


def _parts(name: str) -> tuple[str, int]:
    match = NAME.match(name)
    if not match:
        raise LogRefused(f"unexpected file in the log: {name}")
    return match.group(1), int(match.group(2))


def _seq(name: str) -> int:
    return _parts(name)[1]


def read_remote(client, bucket: str) -> list[tuple[str, bytes]]:
    names = [o["Key"] for page in client.get_paginator("list_objects_v2").paginate(Bucket=bucket, Prefix=PREFIX)
             for o in page.get("Contents", [])]
    return [(name, client.get_object(Bucket=bucket, Key=name)["Body"].read()) for name in names]


def read_dir(path: pathlib.Path) -> list[tuple[str, bytes]]:
    return [(PREFIX + item.name, item.read_bytes()) for item in sorted(path.iterdir()) if not item.name.startswith(".")]


def check_span(log: Log, as_of: str) -> None:
    """Does the log cover everything from the restore point until now? Raises LogGap if not."""
    if not log.batches:
        raise LogGap("the deletion log is empty")
    if not log.genesis and log.oldest_stamp > as_of:
        raise LogGap(f"the log starts at {log.oldest_stamp}, after the restore point {as_of}: older deletions aged out")
    if log.newest_stamp < as_of:
        raise LogGap(f"the log stops at {log.newest_stamp}, before the restore point {as_of}: the export had stopped")


def export_batch(conn: psycopg.Connection, client, bucket: str, key: bytes, now: datetime.datetime) -> tuple[str, int]:
    """Append what the database knows and the log doesn't. Compares contents rather than tracking a position:
    a restore rewinds the database, and a position would then skip what was deleted next."""
    if conn.execute("SELECT to_regclass('public.deletion_tombstones')").fetchone()[0] is None:
        raise SystemExit("public.deletion_tombstones doesn't exist on this database (migration 1060)")
    log = verify(read_remote(client, bucket), key)
    floor = (now - datetime.timedelta(days=TRACKER_DAYS)).date()
    rows = conn.execute("SELECT kind, subject_hash, deleted_on FROM public.deletion_tombstones "
                        "WHERE deleted_on >= %s ORDER BY deleted_on, kind, subject_hash", (floor,)).fetchall()
    fresh = [{"k": k, "h": h, "d": d.isoformat()} for k, h, d in rows if (k, h) not in log.entries]
    stamp = now.strftime(STAMP)
    if log.newest_stamp and stamp < log.newest_stamp:
        raise SystemExit(f"this clock ({stamp}) is behind the newest batch ({log.newest_stamp})")
    name = f"{PREFIX}{stamp}-{log.next_seq:08d}.json.mmob"
    body = {"v": 1, "seq": log.next_seq, "created_utc": stamp, "prev_sha256": log.head_sha256, "entries": fresh}
    offsite.put(client, bucket, name, offsite.seal(key, name, json.dumps(body, sort_keys=True).encode()))
    return name, len(fresh)


# -- the fence ---------------------------------------------------------------------------

def fence(conn: psycopg.Connection) -> None:
    """Close the database to the service with role attributes and schema grants, so it holds without any API
    change. What it takes away is written down, so lifting it gives back exactly that and adds nothing. A second
    fence keeps the first record."""
    conn.execute("CREATE SCHEMA IF NOT EXISTS movemark_meta")
    conn.execute("CREATE TABLE IF NOT EXISTS movemark_meta.restore_fence (role text NOT NULL, what text NOT NULL, "
                 "PRIMARY KEY (role, what))")
    for (role,) in conn.execute("SELECT rolname FROM pg_roles WHERE rolname = ANY(%s) AND rolcanlogin",
                                (list(FENCED_LOGINS),)).fetchall():
        conn.execute("INSERT INTO movemark_meta.restore_fence VALUES (%s, 'login') ON CONFLICT DO NOTHING", (role,))
        conn.execute(sql.SQL("ALTER ROLE {} NOLOGIN").format(sql.Identifier(role)))
        conn.execute("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = %s", (role,))
    # From the schema's real ACL: PUBLIC holds USAGE on public by default, so revoking the two roles alone does nothing.
    for (grantee,) in conn.execute("""
            SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE r.rolname END
              FROM pg_namespace n, aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) a
              LEFT JOIN pg_roles r ON r.oid = a.grantee
             WHERE n.nspname = 'public' AND a.privilege_type = 'USAGE' AND (a.grantee = 0 OR r.rolname = ANY(%s))""",
                                   (list(DATA_API_ROLES),)).fetchall():
        conn.execute("INSERT INTO movemark_meta.restore_fence VALUES (%s, 'usage') ON CONFLICT DO NOTHING", (grantee,))
        conn.execute(sql.SQL("REVOKE USAGE ON SCHEMA public FROM {}").format(_grantee(grantee)))
    open_roles = conn.execute("""SELECT rolname FROM pg_roles WHERE (rolname = ANY(%s) AND has_schema_privilege(rolname, 'public', 'USAGE'))
                                 OR (rolname = ANY(%s) AND rolcanlogin)""", (list(DATA_API_ROLES), list(FENCED_LOGINS))).fetchall()
    if open_roles:
        raise ReplayFailed(f"the fence didn't close: {[r[0] for r in open_roles]}")


def _grantee(name: str) -> sql.Composable:
    return sql.SQL("PUBLIC") if name == "PUBLIC" else sql.Identifier(name)


def lift_fence(conn: psycopg.Connection) -> None:
    for role, what in conn.execute("SELECT role, what FROM movemark_meta.restore_fence").fetchall():
        statement = "ALTER ROLE {} LOGIN" if what == "login" else "GRANT USAGE ON SCHEMA public TO {}"
        conn.execute(sql.SQL(statement).format(_grantee(role)))
    conn.execute("DROP TABLE movemark_meta.restore_fence")


def is_fenced(conn: psycopg.Connection) -> bool:
    return conn.execute("SELECT to_regclass('movemark_meta.restore_fence')").fetchone()[0] is not None


# -- replay ----------------------------------------------------------------------------

def _user_columns(conn: psycopg.Connection) -> list[tuple[str, str]]:
    """Every public table column that names an account. Found from the catalog so that a table added later
    is checked without anyone remembering to list it here."""
    return [(t, c) for t, c in conn.execute("""
        SELECT c.table_name, c.column_name FROM information_schema.columns c
          JOIN information_schema.tables t USING (table_schema, table_name)
         WHERE c.table_schema = 'public' AND t.table_type = 'BASE TABLE' AND c.data_type = 'uuid'
           AND c.column_name = 'user_id'""").fetchall()] + [("profiles", "id")]


def _accounts_present(conn: psycopg.Connection) -> set[str]:
    found = {str(r[0]) for r in conn.execute('SELECT id FROM neon_auth."user"').fetchall()}
    for table, column in _user_columns(conn):
        query = sql.SQL("SELECT DISTINCT {} FROM {} WHERE {} IS NOT NULL").format(
            sql.Identifier(column), sql.Identifier("public", table), sql.Identifier(column))
        found |= {str(r[0]) for r in conn.execute(query).fetchall()}
    return found


def _matches(conn: psycopg.Connection, log_accounts: set[str], log_properties: set[str]) -> tuple[list[str], list[tuple[str, str]]]:
    accounts = sorted(u for u in _accounts_present(conn) if subject_hash(u) in log_accounts)
    rentals = [(str(p), str(u)) for p, u in conn.execute("SELECT id, user_id FROM public.properties").fetchall()
               if subject_hash(str(p)) in log_properties]
    return accounts, rentals


def _tombstones_held(conn: psycopg.Connection) -> set[tuple[str, str]]:
    """What the restored database itself recorded. A pre-1060 backup has none."""
    if conn.execute("SELECT to_regclass('public.deletion_tombstones')").fetchone()[0] is None:
        return set()
    return {(k, h) for k, h in conn.execute("SELECT kind, subject_hash FROM public.deletion_tombstones").fetchall()}


def replay_database(conn: psycopg.Connection, targets: set[tuple[str, str]]) -> dict:
    """Delete the matched accounts and rentals the way the API does, all or nothing, then prove none remain."""
    log_accounts = {h for k, h in targets if k == "account"}
    log_properties = {h for k, h in targets if k == "property"}
    with conn.transaction():
        accounts = _matches(conn, log_accounts, log_properties)[0]
        for user_id in accounts:  # = delete_account_for_user in movemark-api
            conn.execute("SELECT public.delete_user_owned_data(%s)", (user_id,))
            conn.execute("DELETE FROM public.storage_upload_tickets WHERE user_id = %s", (user_id,))
            conn.execute("SELECT public.delete_auth_user(%s)", (user_id,))
        rentals = _matches(conn, log_accounts, log_properties)[1]  # those not already gone with their account
        for property_id, user_id in rentals:
            conn.execute("SELECT * FROM public.delete_property_owned_data(%s, %s)", (user_id, property_id))
        left_accounts, left_rentals = _matches(conn, log_accounts, log_properties)
        if left_accounts or left_rentals:
            raise ReplayFailed(f"{len(left_accounts)} accounts and {len(left_rentals)} rentals survived replay")
    return {"accounts_deleted": len(accounts), "rentals_deleted": len(rentals)}


def _doomed(relative: str, accounts: set[str], rentals: set[str]) -> bool:
    """Keys are <user id>/<property id>/…; old Swift keys used uppercase ids, which subject_hash folds."""
    parts = relative.split("/")
    return subject_hash(parts[0]) in accounts or (len(parts) > 1 and subject_hash(parts[1]) in rentals)


def replay_objects(objects: pathlib.Path, manifest: pathlib.Path | None, targets: set[tuple[str, str]]) -> dict:
    """Remove the files of logged accounts and rentals from <objects>/<bucket>/<key>, and their manifest rows,
    which are what an operator uploads from. Matched by path, so files no row points at go too."""
    accounts = {h for k, h in targets if k == "account"}
    rentals = {h for k, h in targets if k == "property"}
    removed = 0
    for bucket_dir in (p for p in sorted(objects.iterdir()) if p.is_dir()):
        for item in [p for p in bucket_dir.rglob("*") if p.is_file()]:
            if _doomed(item.relative_to(bucket_dir).as_posix(), accounts, rentals):
                item.unlink()
                removed += 1
    if manifest is not None:
        lines = manifest.read_text().splitlines(keepends=True)
        manifest.write_text("".join(line for line in lines if not _doomed(line.split("\t")[1], accounts, rentals)))
    left = sum(1 for bucket_dir in objects.iterdir() if bucket_dir.is_dir() for p in bucket_dir.rglob("*")
               if p.is_file() and _doomed(p.relative_to(bucket_dir).as_posix(), accounts, rentals))
    if left:
        raise ReplayFailed(f"{left} files survived replay")
    return {"objects_removed": removed}


def replay(conn: psycopg.Connection, log: Log, as_of: str, objects: pathlib.Path | None = None,
           manifest: pathlib.Path | None = None, accept_gap: str = "") -> dict:
    """The whole step except lifting the fence, which the caller does once its own checks pass. Counts only in
    the receipt: nothing in it identifies anyone."""
    gap = ""
    try:
        check_span(log, as_of)
    except LogGap as error:
        if not accept_gap.strip():
            raise
        gap = str(error)
    # The restored database's own record counts too: its rows may never have reached the log.
    held = _tombstones_held(conn)
    targets = set(log.entries) | held
    receipt = {"as_of": as_of, "log_batches": log.batches, "log_head_sha256": log.head_sha256, "log_entries": len(log.entries),
               "tombstones_only_in_restored_database": len(held - set(log.entries))}
    receipt |= replay_database(conn, targets)
    if objects is not None:
        receipt |= replay_objects(objects, manifest, targets)
    if gap:
        receipt |= {"accepted_log_gap": gap, "accepted_log_gap_reason": accept_gap}
    return receipt


# -- commands --------------------------------------------------------------------------

def _dsn(name: str) -> str:
    value = os.environ.get(name, "")
    if not value.startswith("postgres"):
        sys.exit(f"${name} is not a connection string")
    return value


def _refuse_production(dsn: str) -> None:
    """Replay and fence write. Production gets them only from an owner-approved runbook, not by a stray variable."""
    if "ep-steep-wind" in dsn and os.environ.get("MOVEMARK_REPLAY_PRODUCTION") != "br-solitary-glade-b5nc31al":
        sys.exit("refused: this is the production endpoint")


def cmd_export(args: argparse.Namespace) -> int:
    client, bucket = offsite.b2("DB")
    with psycopg.connect(_dsn(args.dsn_env)) as conn:
        conn.execute("SET TRANSACTION READ ONLY")
        name, count = export_batch(conn, client, bucket, args.key_file.expanduser().read_bytes(),
                                   datetime.datetime.now(datetime.UTC))
    print(f"DELETION_LOG EXPORTED {count} new entries in {pathlib.PurePosixPath(name).name}")
    return 0


def cmd_pull(args: argparse.Namespace) -> int:
    out = args.to.expanduser()
    if out.exists() and any(out.iterdir()):
        sys.exit("--to must be empty")
    client, bucket = offsite.b2("DB")
    batches = read_remote(client, bucket)
    log = verify(batches, args.key_file.expanduser().read_bytes())
    out.mkdir(parents=True, exist_ok=True)
    for name, sealed in batches:
        (out / pathlib.PurePosixPath(name).name).write_bytes(sealed)
    print(f"DELETION_LOG PULLED {log.batches} batches, {len(log.entries)} entries, {log.oldest_stamp} to {log.newest_stamp}")
    return 0


def cmd_fence(args: argparse.Namespace) -> int:
    dsn = _dsn(args.dsn_env)
    _refuse_production(dsn)
    with psycopg.connect(dsn, autocommit=True) as conn:
        fence(conn)
    print("SERVICE_FENCED")
    return 0


def cmd_replay(args: argparse.Namespace) -> int:
    dsn = _dsn(args.dsn_env)
    _refuse_production(dsn)
    if args.objects and not args.objects.expanduser().is_dir():
        sys.exit(f"--objects is not a directory: {args.objects}")
    log = verify(read_dir(args.log.expanduser()), args.key_file.expanduser().read_bytes())
    with psycopg.connect(dsn, autocommit=True) as conn:
        fence(conn)  # whatever state it was left in, replay runs behind the fence
        receipt = replay(conn, log, args.as_of, args.objects.expanduser() if args.objects else None,
                         args.manifest.expanduser() if args.manifest else None, args.accept_log_gap)
        lift_fence(conn)
    if args.objects and args.objects.expanduser().name == "objects-fenced":
        args.objects.expanduser().rename(args.objects.expanduser().with_name("objects"))
    print(json.dumps(receipt))
    print("REPLAY PASS: fence lifted")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)
    p = sub.add_parser("export")
    p.add_argument("--key-file", type=pathlib.Path, required=True)
    p.add_argument("--dsn-env", required=True)
    p = sub.add_parser("pull")
    p.add_argument("--key-file", type=pathlib.Path, required=True)
    p.add_argument("--to", type=pathlib.Path, required=True)
    p = sub.add_parser("fence")
    p.add_argument("--dsn-env", required=True)
    p = sub.add_parser("replay")
    p.add_argument("--key-file", type=pathlib.Path, required=True)
    p.add_argument("--log", type=pathlib.Path, required=True)
    p.add_argument("--dsn-env", required=True)
    p.add_argument("--as-of", required=True, help="the restore point, UTC, as 20261107T061700Z")
    p.add_argument("--objects", type=pathlib.Path)
    p.add_argument("--manifest", type=pathlib.Path)
    p.add_argument("--accept-log-gap", default="", help="owner's reason for continuing past a gap; lands in the receipt")
    args = ap.parse_args()
    try:
        return {"export": cmd_export, "pull": cmd_pull, "fence": cmd_fence, "replay": cmd_replay}[args.command](args)
    except (LogRefused, LogGap, ReplayFailed) as error:
        print(f"{type(error).__name__}: {error}\nSERVICE STAYS FENCED", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
