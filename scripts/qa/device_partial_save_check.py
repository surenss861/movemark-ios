"""MoveMark QA — after the device partial-save test: exactly one row per photo, nothing left behind (read-only).

    source scripts/qa/dev_env.sh
    (cd movemark-api-py && PYTHONPATH=. .venv/bin/python ../movemork/scripts/qa/device_partial_save_check.py \
        qa-neon-a@movemark.test 2)

Checks for the account: `expected` evidence rows with distinct source hashes (no duplicates); every upload
ticket either consumed by a row or abandoned (none left issued/finalized); every object in the evidence
bucket under the account's folder referenced by a row (no orphans).
"""
import asyncio
import os
import sys

if "ep-steep-wind" in os.environ.get("DATABASE_URL", "") or "br-dark-scene" not in os.environ.get("AWS_ENDPOINT_URL_S3", ""):
    sys.exit("refusing: not the Neon dev branch")

from app import db, object_store  # noqa: E402

BUCKET = "inspection-media"


async def main(email: str, expected: int) -> int:
    user = await db.scalar('SELECT id::text FROM neon_auth."user" WHERE email = %s', email)
    if not user:
        print("no such account on dev"); return 1
    rows = await db.rows(
        "SELECT ef.id, ef.source_sha256, ef.capture_source, ef.source_path, ef.file_path, ef.thumbnail_path "
        "FROM evidence_files ef JOIN properties p ON p.id = ef.property_id WHERE p.user_id = %s ORDER BY ef.created_at", user)
    tickets = await db.rows(
        "SELECT state, count(*) AS n FROM storage_upload_tickets WHERE user_id = %s AND kind = 'evidence' GROUP BY state", user)
    referenced = {k for r in rows for k in (r["source_path"], r["file_path"], r["thumbnail_path"]) if k}
    stored = set(await object_store.list_prefix(BUCKET, f"{user}/"))
    await db.close_pool()

    shas = [r["source_sha256"] for r in rows]
    by_state = {t["state"]: t["n"] for t in tickets}
    open_tickets = by_state.get("issued", 0) + by_state.get("finalized", 0)
    orphans = stored - referenced
    missing = referenced - stored
    print(f"evidence rows      : {len(rows)} (expected {expected}) sources: {[r['capture_source'] for r in rows]}")
    print(f"distinct sources   : {len(set(shas))}  duplicates: {len(shas) - len(set(shas))}")
    print(f"upload tickets     : {dict(sorted(by_state.items()))}  open: {open_tickets}")
    print(f"objects            : {len(stored)} stored, {len(referenced)} referenced, "
          f"{len(orphans)} unreferenced, {len(missing)} missing")
    for key in sorted(orphans):
        print(f"  unreferenced: {key.rsplit('/', 1)[-1]}")
    ok = (len(rows) == expected and len(set(shas)) == len(shas) and open_tickets == 0
          and not orphans and not missing and by_state.get("consumed", 0) == expected)
    print("PARTIAL_SAVE_CHECK", "PASS" if ok else "FAIL")
    return 0 if ok else 1


sys.exit(asyncio.run(main(sys.argv[1], int(sys.argv[2]))))
