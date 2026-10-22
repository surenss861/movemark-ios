"""MoveMark — restore a backup (scripts/dr/backup.py) into a blank PostgreSQL 18 + a plain object directory.

    ../movemark-api-py/.venv/bin/python scripts/dr/restore.py --archive <file>.mmbk --key-file <key> \\
        --workdir /path/to/blank/dir [--port 5544]

Needs only the archive, its .sha256/.json siblings and the key: no Neon account, CLI or network. Creates a
fresh PostgreSQL 18 cluster in --workdir (initdb), recreates the roles the dump's grants name, provides the
one Neon-only function the schema calls (auth.user_id(), from the pg_session_jwt extension — here reading
PostgREST-style JWT claims), restores the dump, writes every object to <workdir>/objects/<bucket>/<key>, and
proves the result:
  - archive SHA-256, every chunk's authentication tag, every object against the manifest;
  - row counts equal the backup's;
  - the restored schema's catalog fingerprint equals a from-zero build of neon/migrations at the backup's
    ledger head (same check neon/migrate.py uses for drift);
  - every storage path any row references exists among the restored objects, and every immutable evidence
    source matches its recorded SHA-256.
Prints RESTORE_DRILL PASS/FAIL and the time each phase took (the measured RTO for this data size).
To serve the app from it, point DATABASE_URL at the cluster and upload <workdir>/objects to any
S3-compatible store with the same bucket names (see docs/disaster-recovery.md).
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import pathlib
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import time

import psycopg
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("migrate", ROOT / "neon" / "migrate.py")
migrate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migrate)
spec_b = importlib.util.spec_from_file_location("backup", ROOT / "scripts" / "dr" / "backup.py")
backup = importlib.util.module_from_spec(spec_b)
spec_b.loader.exec_module(backup)

PG_BIN = backup.PG_BIN
# Roles the dump's ownership/grants refer to (Neon platform roles + MoveMark's), all NOLOGIN here except the
# owner the restore runs as and the runtime roles the API/worker would use.
ROLES = ["neondb_owner LOGIN", "anonymous", "authenticated", "authenticator", "neon_auth", "neon_superuser",
         "movemark_backend", "movemark_api LOGIN BYPASSRLS", "movemark_worker LOGIN BYPASSRLS", "cloud_admin", "neon_service"]
PLATFORM = """
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.user_id() RETURNS text LANGUAGE sql STABLE AS
$$ SELECT nullif(current_setting('request.jwt.claims', true), '')::json ->> 'sub' $$;
GRANT USAGE ON SCHEMA auth TO anonymous, authenticated;
GRANT EXECUTE ON FUNCTION auth.user_id() TO anonymous, authenticated;
"""


def decrypt(src: pathlib.Path, dst: pathlib.Path, key: bytes) -> None:
    aead = AESGCM(key)
    with open(src, "rb") as fh, open(dst, "wb") as out:
        if fh.read(len(backup.MAGIC)) != backup.MAGIC:
            sys.exit("not a MoveMark backup archive")
        index = 0
        while True:
            header = fh.read(16)
            if not header:
                sys.exit("archive truncated: final chunk missing")
            nonce, length = header[:12], struct.unpack(">I", header[12:])[0]
            sealed = fh.read(length)
            for final in (1, 0):  # the tag only verifies with the right (index, final) pair
                try:
                    out.write(aead.decrypt(nonce, sealed, struct.pack(">QB", index, final)))
                    break
                except Exception:  # noqa: BLE001
                    if final == 0:
                        sys.exit(f"chunk {index} failed authentication (corrupt, reordered or wrong key)")
            if final == 1:
                if fh.read(1):
                    sys.exit("data after the final chunk")
                return
            index += 1


def pg(cmd: list[str], **kw) -> None:
    subprocess.run([str(PG_BIN / cmd[0]), *cmd[1:]], check=True, **kw)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--archive", type=pathlib.Path, required=True)
    ap.add_argument("--key-file", type=pathlib.Path, required=True)
    ap.add_argument("--workdir", type=pathlib.Path, required=True)
    ap.add_argument("--port", type=int, default=5544)
    args = ap.parse_args()
    archive = args.archive.expanduser()
    work = args.workdir.expanduser()
    if work.exists() and any(work.iterdir()):
        sys.exit("--workdir must be empty (a blank environment)")
    work.mkdir(parents=True, exist_ok=True)
    meta = json.loads(archive.with_suffix(".json").read_text())
    timings: dict[str, float] = {}
    problems: list[str] = []

    t0 = time.monotonic()
    expected = archive.with_name(archive.name + ".sha256").read_text().split()[0]
    if hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
        sys.exit("archive SHA-256 mismatch")
    plain = work / "archive.tar"
    decrypt(archive, plain, args.key_file.expanduser().read_bytes())
    with tarfile.open(plain) as tar:
        tar.extractall(work, filter="data")
    plain.unlink()
    for line in (work / "manifest.tsv").read_text().splitlines():
        bucket, key, size, digest = line.split("\t")
        data = (work / "objects" / bucket / key).read_bytes()
        if len(data) != int(size) or hashlib.sha256(data).hexdigest() != digest:
            problems.append(f"object {bucket}/{key} does not match the manifest")
    timings["verify_decrypt_s"] = round(time.monotonic() - t0, 2)

    t0 = time.monotonic()
    data_dir = work / "pgdata"
    sock = pathlib.Path(tempfile.mkdtemp(prefix="mmrs-"))  # socket paths are capped at 103 bytes
    pg(["initdb", "-D", str(data_dir), "-U", "postgres", "--auth=trust", "--no-instructions"], stdout=subprocess.DEVNULL)
    pg(["pg_ctl", "-D", str(data_dir), "-l", str(work / "postgres.log"), "-o",
        f"-p {args.port} -k {sock} -c listen_addresses=''", "-w", "start"], stdout=subprocess.DEVNULL)
    admin = f"host={sock} port={args.port} user=postgres dbname=postgres"
    try:
        with psycopg.connect(admin, autocommit=True) as conn:
            for role in ROLES:
                name, *attrs = role.split()
                conn.execute(f"CREATE ROLE {name} {' '.join(attrs) or 'NOLOGIN'}")
            conn.execute("GRANT anonymous, authenticated, movemark_backend, neon_auth TO neondb_owner WITH ADMIN OPTION")
            conn.execute("GRANT movemark_backend TO movemark_api, movemark_worker")
            conn.execute("ALTER ROLE neondb_owner BYPASSRLS CREATEROLE")
            conn.execute("CREATE DATABASE neondb OWNER neondb_owner")
        db = f"host={sock} port={args.port} user=postgres dbname=neondb"
        with psycopg.connect(db, autocommit=True) as conn:
            conn.execute(PLATFORM)
        listing = subprocess.run([str(PG_BIN / "pg_restore"), "--list", str(work / "db.dump")],
                                 check=True, capture_output=True, text=True).stdout
        keep = "\n".join(line for line in listing.splitlines() if "pg_session_jwt" not in line and " SCHEMA - auth " not in line)
        (work / "restore.list").write_text(keep + "\n")
        result = subprocess.run([str(PG_BIN / "pg_restore"), "--use-list", str(work / "restore.list"), "--exit-on-error",
                                 "--dbname", db, str(work / "db.dump")], capture_output=True, text=True)
        if result.returncode != 0:
            sys.exit(f"pg_restore failed:\n{result.stderr[-2000:]}")
        timings["restore_db_s"] = round(time.monotonic() - t0, 2)

        t0 = time.monotonic()
        with psycopg.connect(db) as conn:
            for table, count in meta["row_counts"].items():
                name = 'neon_auth."user"' if table == "neon_auth.user" else f"public.{table}"
                got = conn.execute(f"SELECT count(*) FROM {name}").fetchone()[0]
                if got != count:
                    problems.append(f"{table}: {got} rows restored, {count} backed up")
            head = conn.execute("SELECT max(version) FROM movemark_meta.schema_migrations").fetchone()[0]
            if head != meta["ledger_head"]:
                problems.append(f"ledger head {head} != {meta['ledger_head']}")
            restored_fp = migrate.fingerprint(conn)
            refs = conn.execute("""
                SELECT 'inspection-media', unnest(ARRAY[file_path, thumbnail_path, source_path]) FROM public.evidence_files
                  WHERE inspection_item_id IS NOT NULL
                UNION ALL SELECT 'maintenance-media', unnest(ARRAY[file_path, thumbnail_path, source_path]) FROM public.evidence_files
                  WHERE maintenance_issue_id IS NOT NULL
                UNION ALL SELECT 'exports', file_path FROM public.exports WHERE file_path IS NOT NULL""").fetchall()
            docs = conn.execute("SELECT document_type, file_path, thumbnail_path FROM public.property_documents").fetchall()
            sources = conn.execute("SELECT source_path, source_sha256 FROM public.evidence_files WHERE source_path IS NOT NULL").fetchall()
        # Documents live in a bucket per type (app/services/storage_keys.DOCUMENT_BUCKETS).
        doc_bucket = {"lease": "leases", "deposit_receipt": "deposit-receipts", "listing_screenshot": "listing-screenshots"}
        for kind, path, thumb in docs:
            refs += [(doc_bucket.get(kind, "documents"), p) for p in (path, thumb)]
        objects = {(b, k) for b, k, *_ in (line.split("\t") for line in (work / "manifest.tsv").read_text().splitlines())}
        missing = [f"{b}/{k}" for b, k in refs if k and (b, k) not in objects
                   and not any((other, k) in objects for other in backup.BUCKETS)]
        if missing and not meta.get("database_only"):
            problems.append(f"{len(missing)} referenced objects missing, e.g. {missing[:3]}")
        bad_sources = 0
        for path, digest in sources:
            found = next((work / "objects" / b / path for b in ("inspection-media", "maintenance-media")
                          if (work / "objects" / b / path).exists()), None)
            if found is None or hashlib.sha256(found.read_bytes()).hexdigest() != digest:
                bad_sources += 1
        if bad_sources and not meta.get("database_only"):
            problems.append(f"{bad_sources} evidence sources missing or not matching their recorded SHA-256")
        files = sorted(p for p in (ROOT / "neon" / "migrations").glob("*.sql") if p.name[:4] <= head)
        with migrate.scratch_db(files) as scratch:
            reference_fp = migrate.fingerprint(scratch)
        drift = migrate.diff(restored_fp, reference_fp, "restored", "from-zero")
        if drift:
            problems.append(f"schema differs from a from-zero build: {drift[:5]}")
        timings["verify_s"] = round(time.monotonic() - t0, 2)
    finally:
        pg(["pg_ctl", "-D", str(data_dir), "-m", "fast", "stop"], stdout=subprocess.DEVNULL)
        shutil.rmtree(sock, ignore_errors=True)

    report = {"backup": meta["created_utc"], "rows": sum(meta["row_counts"].values()), "objects": meta["objects"],
              "references_checked": len(refs), "sources_hash_checked": len(sources), "timings": timings}
    print(json.dumps(report))
    for p in problems:
        print("PROBLEM:", p)
    print("RESTORE_DRILL", "PASS" if not problems else "FAIL")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
