"""MoveMark — off-site copies in Backblaze B2 (its S3-compatible API) and recovery from B2 alone.

    ../movemark-api-py/.venv/bin/python scripts/dr/offsite.py push-db <backup>.mmbk
    ../movemark-api-py/.venv/bin/python scripts/dr/offsite.py sync-evidence --key-file <key>
    ../movemark-api-py/.venv/bin/python scripts/dr/offsite.py pull --key-file <key> --to <empty dir>

push-db        uploads a scripts/dr/backup.py archive with its .sha256 and .json to the DB bucket under db/,
               then re-downloads it and checks the SHA-256.
sync-evidence  mirrors every object of the source storage (AWS_* = the branch's Neon Object Storage) into the
               evidence bucket under objects/<bucket>/<key>, each encrypted on its own (AES-256-GCM, the backup
               key, its bucket/key bound as associated data). Objects whose source ETag matches the newest
               manifest are skipped, so a run uploads only what changed. Then writes an encrypted manifest of
               the complete current set (manifests/<UTC>.tsv.mmob): bucket, key, bytes, sha256, source ETag.
pull           from B2 alone: the newest DB archive (hash-checked) and every object of the newest manifest,
               decrypted and checked against it, into --to: <archive files> and evidence/{manifest.tsv,objects/}.
               scripts/dr/restore.py --evidence <dir>/evidence restores both into a blank environment.

Credentials come from the environment and never from the repository; each bucket has its own key, restricted
to that bucket: B2_ENDPOINT (e.g. https://s3.us-west-004.backblazeb2.com), B2_REGION, B2_DB_BUCKET,
B2_DB_KEY_ID, B2_DB_APP_KEY, B2_EVIDENCE_BUCKET, B2_EVIDENCE_KEY_ID, B2_EVIDENCE_APP_KEY. The buckets use
Object Lock with a default retention, so nothing uploaded can be overwritten or deleted inside the window —
not by this script, and not by anyone holding its keys.
"""
from __future__ import annotations

import argparse
import base64
import datetime
import hashlib
import importlib.util
import os
import pathlib
import secrets
import sys

import boto3
from botocore.config import Config
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("backup", ROOT / "scripts" / "dr" / "backup.py")
backup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backup)

OBJECT_MAGIC = b"MMOB1\n"


def b2(which: str):
    """Client for one bucket, with that bucket's own key. Content-MD5 on every upload (Object Lock requires
    it); the newer SDK checksum headers stay off, as B2 doesn't take all of them."""
    env = {k: os.environ.get(f"B2_{which}_{k}", "") for k in ("BUCKET", "KEY_ID", "APP_KEY")}
    if not all(env.values()) or not os.environ.get("B2_ENDPOINT"):
        sys.exit(f"B2_ENDPOINT and B2_{which}_BUCKET/KEY_ID/APP_KEY must be set")
    client = boto3.client(
        "s3", endpoint_url=os.environ["B2_ENDPOINT"], region_name=os.environ.get("B2_REGION", "us-west-004"),
        aws_access_key_id=env["KEY_ID"], aws_secret_access_key=env["APP_KEY"],
        config=Config(request_checksum_calculation="when_required", response_checksum_validation="when_required",
                      retries={"max_attempts": 8, "mode": "adaptive"}),
    )
    return client, env["BUCKET"]


def put(client, bucket: str, key: str, body: bytes, **meta: str) -> None:
    md5 = base64.b64encode(hashlib.md5(body).digest()).decode()  # noqa: S324 — transport integrity, not security
    client.put_object(Bucket=bucket, Key=key, Body=body, ContentMD5=md5, Metadata=meta)


def seal(key: bytes, name: str, plain: bytes) -> bytes:
    nonce = secrets.token_bytes(12)
    return OBJECT_MAGIC + nonce + AESGCM(key).encrypt(nonce, plain, name.encode())


def unseal(key: bytes, name: str, sealed: bytes) -> bytes:
    if not sealed.startswith(OBJECT_MAGIC):
        raise ValueError(f"{name}: not a MoveMark encrypted object")
    body = sealed[len(OBJECT_MAGIC):]
    return AESGCM(key).decrypt(body[:12], body[12:], name.encode())  # raises if altered or moved


def newest(client, bucket: str, prefix: str, suffix: str) -> str | None:
    found = [o for page in client.get_paginator("list_objects_v2").paginate(Bucket=bucket, Prefix=prefix)
             for o in page.get("Contents", []) if o["Key"].endswith(suffix)]
    return max(found, key=lambda o: o["Key"])["Key"] if found else None  # keys carry a sortable UTC stamp


def read_manifest(client, bucket: str, key: bytes) -> tuple[str | None, list[tuple[str, str, int, str, str]]]:
    name = newest(client, bucket, "manifests/", ".tsv.mmob")
    if name is None:
        return None, []
    text = unseal(key, name, client.get_object(Bucket=bucket, Key=name)["Body"].read()).decode()
    rows = []
    for line in text.splitlines():
        src_bucket, obj_key, size, digest, etag = line.split("\t")
        rows.append((src_bucket, obj_key, int(size), digest, etag))
    return name, rows


def push_db(args: argparse.Namespace) -> int:
    client, bucket = b2("DB")
    archive = args.archive.expanduser()
    for path in (archive, archive.with_name(archive.name + ".sha256"), archive.with_suffix(".json")):
        put(client, bucket, f"db/{path.name}", path.read_bytes())
    expected = archive.with_name(archive.name + ".sha256").read_text().split()[0]
    got = hashlib.sha256(client.get_object(Bucket=bucket, Key=f"db/{archive.name}")["Body"].read()).hexdigest()
    if got != expected:
        sys.exit(f"uploaded archive does not match: {got} != {expected}")
    print(f"PUSHED db/{archive.name} ({archive.stat().st_size} bytes, sha256 verified after upload)")
    return 0


def sync_evidence(args: argparse.Namespace) -> int:
    key = backup.load_key(args.key_file.expanduser())
    client, bucket = b2("EVIDENCE")
    source = boto3.client("s3", endpoint_url=os.environ["AWS_ENDPOINT_URL_S3"], region_name=os.getenv("AWS_REGION"))
    _, previous = read_manifest(client, bucket, key)
    known = {(b, k): (n, d, e) for b, k, n, d, e in previous}
    rows, uploaded, uploaded_bytes = [], 0, 0
    for src_bucket in backup.BUCKETS:
        for page in source.get_paginator("list_objects_v2").paginate(Bucket=src_bucket):
            for obj in page.get("Contents", []):
                etag = obj["ETag"].strip('"')
                prior = known.get((src_bucket, obj["Key"]))
                if prior and prior[2] == etag and not args.full:
                    rows.append((src_bucket, obj["Key"], prior[0], prior[1], etag))
                    continue
                body = source.get_object(Bucket=src_bucket, Key=obj["Key"])["Body"].read()
                digest = hashlib.sha256(body).hexdigest()
                name = f"objects/{src_bucket}/{obj['Key']}"
                put(client, bucket, name, seal(key, name, body), sha256=digest)
                rows.append((src_bucket, obj["Key"], len(body), digest, etag))
                uploaded, uploaded_bytes = uploaded + 1, uploaded_bytes + len(body)
    stamp = datetime.datetime.now(datetime.UTC).strftime("%Y%m%dT%H%M%SZ")
    name = f"manifests/{stamp}.tsv.mmob"
    text = "".join(f"{b}\t{k}\t{n}\t{d}\t{e}\n" for b, k, n, d, e in rows).encode()
    put(client, bucket, name, seal(key, name, text))
    print(f"SYNCED {len(rows)} objects ({sum(r[2] for r in rows)} bytes); uploaded {uploaded} "
          f"({uploaded_bytes} bytes); manifest {name}")
    return 0


def pull(args: argparse.Namespace) -> int:
    key = args.key_file.expanduser().read_bytes()
    out = args.to.expanduser()
    if out.exists() and any(out.iterdir()):
        sys.exit("--to must be empty")
    out.mkdir(parents=True, exist_ok=True)
    db_client, db_bucket = b2("DB")
    archive = newest(db_client, db_bucket, "db/", ".mmbk")
    if archive is None:
        sys.exit("no database archive in B2")
    for suffix in ("", ".sha256"):
        (out / pathlib.Path(archive + suffix).name).write_bytes(
            db_client.get_object(Bucket=db_bucket, Key=archive + suffix)["Body"].read())
    meta = archive.removesuffix(".mmbk") + ".json"
    (out / pathlib.Path(meta).name).write_bytes(db_client.get_object(Bucket=db_bucket, Key=meta)["Body"].read())
    local = out / pathlib.Path(archive).name
    if hashlib.sha256(local.read_bytes()).hexdigest() != (out / (local.name + ".sha256")).read_text().split()[0]:
        sys.exit("database archive SHA-256 mismatch")

    ev_client, ev_bucket = b2("EVIDENCE")
    manifest_name, rows = read_manifest(ev_client, ev_bucket, key)
    evidence = out / "evidence"
    (evidence / "objects").mkdir(parents=True)
    for src_bucket, obj_key, size, digest, _ in rows:
        name = f"objects/{src_bucket}/{obj_key}"
        plain = unseal(key, name, ev_client.get_object(Bucket=ev_bucket, Key=name)["Body"].read())
        if len(plain) != size or hashlib.sha256(plain).hexdigest() != digest:
            sys.exit(f"{name} does not match the manifest")
        target = evidence / "objects" / src_bucket / obj_key
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(plain)
    (evidence / "manifest.tsv").write_text("".join(f"{b}\t{k}\t{n}\t{d}\n" for b, k, n, d, _ in rows))
    print(f"PULLED {pathlib.Path(archive).name} and {len(rows)} objects from {manifest_name} into {out}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="command", required=True)
    p = sub.add_parser("push-db")
    p.add_argument("archive", type=pathlib.Path)
    p = sub.add_parser("sync-evidence")
    p.add_argument("--key-file", type=pathlib.Path, required=True)
    p.add_argument("--full", action="store_true", help="re-read and re-upload every object")
    p = sub.add_parser("pull")
    p.add_argument("--key-file", type=pathlib.Path, required=True)
    p.add_argument("--to", type=pathlib.Path, required=True)
    args = ap.parse_args()
    return {"push-db": push_db, "sync-evidence": sync_evidence, "pull": pull}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
