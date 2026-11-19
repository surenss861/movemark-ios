"""MoveMark — provider-independent backup: Postgres (logical) + every evidence/document/export object.

    source scripts/qa/dev_env.sh      # AWS_* for the branch's Object Storage (dev shown)
    ../movemark-api-py/.venv/bin/python scripts/dr/backup.py --project shiny-poetry-92207621 --branch dev \\
        --key-file ~/.movemark-dr/backup.key --out ~/.movemark-dr/backups
    (production: add --production --confirm br-solitary-glade-b5nc31al; reading is all a backup does)

Produces, in --out:
  movemark-<branch>-<UTC timestamp>.mmbk   one encrypted archive (AES-256-GCM, 8 MiB chunks) holding
                                           db.dump (pg_dump custom format, PostgreSQL 18 client),
                                           objects/<bucket>/<key> and manifest.tsv (bucket, key, bytes, sha256)
  ....mmbk.sha256                          SHA-256 of the encrypted archive
  ....json                                 unencrypted metadata: when, source branch, sizes, row counts,
                                           migration ledger head — no personal data, no keys
The key file (32 random bytes, created on first use, mode 0600) must live outside both Neon and the backup
storage — e.g. in the team password manager — or the backup is unreadable. scripts/dr/restore.py reads only
these files: recovery needs neither the Neon account nor this machine's Neon CLI.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import importlib.util
import io
import json
import os
import pathlib
import secrets
import struct
import subprocess
import sys
import tarfile
import tempfile
import time

import boto3
import psycopg
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("migrate", ROOT / "neon" / "migrate.py")
migrate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migrate)

PG_BIN = pathlib.Path(os.getenv("MOVEMARK_PG18_BIN", "/opt/homebrew/opt/postgresql@18/bin"))
BUCKETS = ("inspection-media", "maintenance-media", "leases", "deposit-receipts", "listing-screenshots",
           "documents", "exports")  # = app/object_store.BUCKETS
MAGIC = b"MMBK1\n"
CHUNK = 8 * 1024 * 1024
TABLES = ("properties", "rooms", "inspections", "inspection_items", "evidence_files", "maintenance_issues",
          "property_documents", "disputes", "dispute_evidence_links", "exports", "profiles", "user_report_credits",
          "report_credit_events", "user_entitlements", "storage_upload_tickets")


def load_key(path: pathlib.Path) -> bytes:
    if not path.exists():
        path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "wb") as fh:
            fh.write(secrets.token_bytes(32))
        print(f"created a new backup key at {path} — store a copy outside Neon and the backup storage")
    key = path.read_bytes()
    if len(key) != 32:
        sys.exit("backup key must be exactly 32 bytes")
    return key


def encrypt_stream(src: io.BufferedReader, dst: io.BufferedWriter, key: bytes) -> None:
    """MAGIC, then per chunk: nonce(12) | ciphertext length(4) | ciphertext+tag. The chunk index is bound as
    associated data (with a final-chunk flag), so chunks can't be reordered, dropped or truncated."""
    aead = AESGCM(key)
    dst.write(MAGIC)
    index, chunk = 0, src.read(CHUNK)
    while True:
        following = src.read(CHUNK)
        aad = struct.pack(">QB", index, 1 if not following else 0)
        nonce = secrets.token_bytes(12)
        sealed = aead.encrypt(nonce, chunk, aad)
        dst.write(nonce + struct.pack(">I", len(sealed)) + sealed)
        if not following:
            return
        index, chunk = index + 1, following


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", required=True)
    ap.add_argument("--branch", required=True)
    ap.add_argument("--production", action="store_true")
    ap.add_argument("--confirm", default="")
    ap.add_argument("--key-file", type=pathlib.Path, required=True)
    ap.add_argument("--out", type=pathlib.Path, required=True)
    ap.add_argument("--database-only", action="store_true",
                    help="database only: evidence goes off-site incrementally (scripts/dr/offsite.py sync-evidence)")
    ap.add_argument("--dsn-env", default="",
                    help="read the connection string from this env var (the scheduled job's movemark_backup role) "
                         "instead of the Neon CLI owner login")
    args = ap.parse_args()
    try:
        if args.dsn_env:  # the scheduled job: no Neon CLI or owner login; same production flags, endpoint checked below
            if (args.branch == "production") != bool(args.production) or \
                    (args.production and args.confirm != migrate.PRODUCTION_BRANCH_ID):
                raise migrate.RefusedError(f"production requires --production --confirm {migrate.PRODUCTION_BRANCH_ID}")
        else:
            migrate.check_target(args)
    except migrate.RefusedError as error:
        sys.exit(f"refused: {error}")
    endpoint = os.environ.get("AWS_ENDPOINT_URL_S3", "")
    expected_store = "br-solitary-glade-b5nc31al" if args.branch == "production" else None
    if expected_store and expected_store not in endpoint and not args.database_only:
        sys.exit("refused: AWS_* does not point at the production branch's Object Storage")
    if not expected_store and "br-solitary-glade" in endpoint:
        sys.exit("refused: AWS_* points at production storage for a non-production backup")

    key = load_key(args.key_file.expanduser())
    out = args.out.expanduser()
    out.mkdir(mode=0o700, parents=True, exist_ok=True)
    stamp = datetime.datetime.now(datetime.UTC).strftime("%Y%m%dT%H%M%SZ")
    name = f"movemark-{args.branch}-{stamp}"
    if args.dsn_env:
        dsn = os.environ.get(args.dsn_env, "")
        endpoint_id = "ep-steep-wind-b56266ss" if args.branch == "production" else ""
        if not dsn.startswith("postgres") or (endpoint_id and endpoint_id not in dsn) or \
                (not endpoint_id and "ep-steep-wind" in dsn):
            sys.exit(f"refused: ${args.dsn_env} does not point at the {args.branch} branch")
    else:
        dsn = migrate.neon_dsn(args.project, args.branch)
    timings: dict[str, float] = {}

    with tempfile.TemporaryDirectory(prefix="mmbk-") as tmp:
        work = pathlib.Path(tmp)
        t0 = time.monotonic()
        # Consistent snapshot of the whole database (schema, data, grants, ledger, neon_auth identities).
        subprocess.run([str(PG_BIN / "pg_dump"), "--format=custom", "--compress=6", "--file", str(work / "db.dump"), dsn],
                       check=True)
        timings["pg_dump_s"] = round(time.monotonic() - t0, 2)
        with psycopg.connect(dsn) as conn:
            conn.execute("SET TRANSACTION READ ONLY")
            counts = {t: conn.execute(f"SELECT count(*) FROM public.{t}").fetchone()[0] for t in TABLES}
            counts["neon_auth.user"] = conn.execute('SELECT count(*) FROM neon_auth."user"').fetchone()[0]
            ledger_head = conn.execute("SELECT max(version) FROM movemark_meta.schema_migrations").fetchone()[0]

        t0 = time.monotonic()
        s3 = None if args.database_only else boto3.client("s3", endpoint_url=endpoint, region_name=os.getenv("AWS_REGION"))
        manifest = []
        for bucket in () if args.database_only else BUCKETS:
            for page in s3.get_paginator("list_objects_v2").paginate(Bucket=bucket):
                for obj in page.get("Contents", []):
                    body = s3.get_object(Bucket=bucket, Key=obj["Key"])["Body"].read()
                    target = work / "objects" / bucket / obj["Key"]
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(body)
                    manifest.append((bucket, obj["Key"], len(body), hashlib.sha256(body).hexdigest()))
        (work / "manifest.tsv").write_text("".join(f"{b}\t{k}\t{n}\t{h}\n" for b, k, n, h in manifest))
        timings["objects_s"] = round(time.monotonic() - t0, 2)

        t0 = time.monotonic()
        archive = work / "archive.tar"
        with tarfile.open(archive, "w") as tar:
            for item in ("db.dump", "manifest.tsv", "objects"):
                if (work / item).exists():
                    tar.add(work / item, arcname=item)
        sealed = out / f"{name}.mmbk"
        with open(archive, "rb") as src, open(sealed, "wb") as dst:
            encrypt_stream(src, dst, key)
        os.chmod(sealed, 0o600)
        timings["encrypt_s"] = round(time.monotonic() - t0, 2)
        digest = hashlib.sha256(sealed.read_bytes()).hexdigest()
        (out / f"{name}.mmbk.sha256").write_text(f"{digest}  {sealed.name}\n")
        meta = {
            "created_utc": stamp, "source": {"project": args.project, "branch": args.branch},
            "ledger_head": ledger_head, "row_counts": counts,
            "objects": {"count": len(manifest), "bytes": sum(n for _, _, n, _ in manifest)},
            "db_dump_bytes": (work / "db.dump").stat().st_size, "archive_bytes": sealed.stat().st_size,
            "archive_sha256": digest, "timings": timings, "format": "MMBK1 AES-256-GCM 8MiB chunks",
            "database_only": args.database_only,
        }
        (out / f"{name}.json").write_text(json.dumps(meta, indent=2) + "\n")
    print(json.dumps({k: meta[k] for k in ("created_utc", "ledger_head", "objects", "archive_bytes", "timings")}))
    print(f"backup written: {sealed}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
