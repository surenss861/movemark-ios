"""MoveMark QA — verify the physical-device evidence gate on Neon dev (read-only).

    source scripts/qa/dev_env.sh
    (cd movemark-api-py && PYTHONPATH=. .venv/bin/python ../movemork/scripts/qa/device_evidence_verify.py \
        qa-neon-a@movemark.test <audit-log> <out-dir>)

For every evidence row of the account: the stored source, derivative and thumbnail are downloaded with the
backend's storage credentials and checked against the row, the storage checksum and the phone's DEBUG audit
log (SHA-256 of the bytes the platform handed over). Image metadata comes from scripts/qa/image_meta.swift.
"""
import asyncio
import base64
import hashlib
import os
import pathlib
import subprocess
import sys

if "ep-steep-wind" in os.environ.get("DATABASE_URL", "") or "br-dark-scene" not in os.environ.get("AWS_ENDPOINT_URL_S3", ""):
    sys.exit("refusing: not the Neon dev branch")

from app import db, object_store  # noqa: E402

META = pathlib.Path(__file__).with_name("image_meta.swift")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def meta(paths: list[pathlib.Path]) -> dict[str, str]:
    out = subprocess.run(["swift", str(META), *map(str, paths)], capture_output=True, text=True).stdout
    return {line.split("\t")[0]: line.split("\t")[1] for line in out.splitlines() if "\t" in line}


async def main(email: str, audit_log: pathlib.Path, out: pathlib.Path) -> int:
    out.mkdir(parents=True, exist_ok=True)
    audit = {}
    for line in audit_log.read_text().splitlines():
        parts = dict(p.split("=", 1) for p in line.split()[2:] if "=" in p)
        audit[parts["sha256"]] = (line.split()[1], parts.get("type"), int(parts["bytes"]))
    user = await db.scalar('SELECT id::text FROM neon_auth."user" WHERE email = %s', email)
    if not user:
        print("no such account on dev"); return 1
    rows = await db.rows("SELECT ef.id, ef.file_path, ef.thumbnail_path, ef.source_path, ef.source_sha256, ef.source_byte_size, "
                         "ef.source_mime_type, ef.source_width, ef.source_height, ef.capture_source, ef.captured_at, ef.created_at "
                         "FROM evidence_files ef "
                         "JOIN properties p ON p.id = ef.property_id WHERE p.user_id = %s ORDER BY ef.created_at", user)
    sources = sorted({r["capture_source"] for r in rows})
    ok = {"camera", "library"} <= set(sources)
    print(f"evidence rows: {len(rows)} capture sources: {sources}" + ("" if ok else "  <- need one library AND one camera photo"))
    for i, row in enumerate(rows, 1):
        bucket = "inspection-media"
        files = {}
        for kind, key in (("source", row["source_path"]), ("derivative", row["file_path"]), ("thumbnail", row["thumbnail_path"])):
            data = await object_store.download(bucket, key) if key else None
            if data is None:
                print(f"  evidence {i}: {kind} missing ({key})"); ok = False; continue
            ext = pathlib.Path(key).suffix
            files[kind] = (out / f"e{i}_{kind}{ext}", data)
            files[kind][0].write_bytes(data)
        info = await object_store.head(bucket, row["source_path"]) if row["source_path"] else None
        facts = meta([p for p, _ in files.values()])
        src = files.get("source", (None, b""))[1]
        stored_b64 = info.checksum_sha256 if info else None
        stored_hex = base64.b64decode(stored_b64).hex() if stored_b64 else None
        platform = audit.get(row["source_sha256"] or "")
        print(f"\nEvidence {i} ({row['capture_source']}, id {row['id']}):")
        print(f"  platform bytes (audit log) : {platform[0] + ' ' + str(platform[2]) + ' bytes ' + str(platform[1]) if platform else 'NOT FOUND in audit log'}")
        print(f"  declared source sha256 (row): {row['source_sha256']}")
        print(f"  storage-recorded sha256     : {stored_hex}")
        print(f"  downloaded source sha256    : {sha(src)}")
        chain = platform is not None and row["source_sha256"] == stored_hex == sha(src)
        print(f"  hash chain identical        : {chain}")
        print(f"  row: mime={row['source_mime_type']} bytes={row['source_byte_size']} (downloaded {len(src)}) "
              f"dims={row['source_width']}x{row['source_height']} captured_at={row['captured_at']} created_at={row['created_at']}")
        for kind, (path, data) in files.items():
            print(f"  {kind:<10} {facts.get(str(path), '?')} bytes={len(data)}")
        ok &= chain and len(src) == row["source_byte_size"]
        ok &= "gps=none" in facts.get(str(files["derivative"][0]), "") and "gps=none" in facts.get(str(files["thumbnail"][0]), "")
    exports = await db.rows("SELECT id, status, file_path FROM exports WHERE user_id = %s ORDER BY created_at DESC", user)
    for e in exports[:1]:
        pdf = await object_store.download("exports", e["file_path"]) if e["file_path"] else None
        if pdf:
            (out / "report.pdf").write_bytes(pdf)
            images = pdf.count(b"/Subtype /Image") + pdf.count(b"/Subtype/Image")
            print(f"\nReport {e['id']}: status={e['status']} bytes={len(pdf)} embedded images={images} "
                  f"contains-GPS-tags={b'GPSLatitude' in pdf or b'GPS' in pdf}")
            ok &= e["status"] == "completed" and images >= len(rows) and b"GPSLatitude" not in pdf
        else:
            print(f"\nReport {e['id']}: status={e['status']} (no PDF yet)"); ok = False
    if not exports:
        print("\nno report generated"); ok = False
    await db.close_pool()
    print("\nDEVICE_EVIDENCE_GATE", "PASS" if ok else "FAIL")
    return 0 if ok else 1


sys.exit(asyncio.run(main(sys.argv[1], pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3]))))
