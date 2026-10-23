"""MoveMark — B2-only disaster-recovery drill, end to end, on the Neon `dev` branch.

    source scripts/qa/dev_env.sh                      # dev DSN + dev Object Storage (AWS_*)
    export B2_ENDPOINT=… B2_DB_BUCKET=… B2_DB_KEY_ID=… B2_DB_APP_KEY=… \\
           B2_EVIDENCE_BUCKET=… B2_EVIDENCE_KEY_ID=… B2_EVIDENCE_APP_KEY=…   # omit all: local B2 stand-in
    ../movemark-api-py/.venv/bin/python scripts/dr/b2_drill.py --key-file ~/.movemark-dr/backup.key \\
        --workdir <empty dir> [--moto <path to moto_server>]

1. seeds dev with the QA account qa-neon-a@movemark.test: a rental, a documented room with two photos (+
   thumbnails) and a lease, through Neon Auth and the Data API as the app does, objects in dev storage;
2. backs up the database (scripts/dr/backup.py --database-only) and pushes it to the B2 DB bucket;
   mirrors the evidence into the B2 evidence bucket (scripts/dr/offsite.py sync-evidence);
3. recovers from B2 alone into the empty workdir (offsite.py pull), restores into a blank PostgreSQL 18
   cluster with every check of scripts/dr/restore.py, and uploads the objects into blank object storage;
4. boots the API on the restored database and storage: /api/ready, the vault summary, and signed downloads
   of the restored evidence as the restored user, byte-compared with what was seeded;
5. deletes the QA account from dev (account deletion) and confirms dev is zeroed.
Prints B2_DRILL PASS/FAIL. Refuses production.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import secrets
import signal
import subprocess
import sys
import time

import boto3
import httpx

ROOT = pathlib.Path(__file__).resolve().parents[2]
API = ROOT.parent / "movemark-api-py"
PY = str(API / ".venv" / "bin" / "python")
EMAIL = "qa-neon-a@movemark.test"
FAKE_B2_PORT, BLANK_S3_PORT, API_PORT = 5598, 5599, 8799
BUCKETS = ("inspection-media", "maintenance-media", "leases", "deposit-receipts", "listing-screenshots",
           "documents", "exports")


def run(cmd: list[str], **kw) -> str:
    out = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if out.returncode != 0:
        sys.exit(f"FAILED: {' '.join(cmd[:3])}\n{out.stdout[-1500:]}\n{out.stderr[-1500:]}")
    return out.stdout


def wait_http(url: str, seconds: float = 30) -> None:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        try:
            httpx.get(url, timeout=2)
            return
        except httpx.HTTPError:
            time.sleep(0.3)
    sys.exit(f"{url} did not come up")


def s3(port: int):
    return boto3.client("s3", endpoint_url=f"http://127.0.0.1:{port}", region_name="us-east-1",
                        aws_access_key_id="drill", aws_secret_access_key="drill")


def seed(auth: str, data_api: str, store) -> dict:
    """The QA rental, written the way the app writes it; returns ids, token and the seeded bytes."""
    with httpx.Client(timeout=30, headers={"Origin": auth.split("/neondb")[0]}) as c:
        r = c.post(f"{auth}/sign-up/email", json={"email": EMAIL, "password": secrets.token_urlsafe(24), "name": "QA A"})
        r.raise_for_status()
        uid, token = r.json()["user"]["id"].lower(), c.get(f"{auth}/token").json()["token"]
    h = {"Authorization": f"Bearer {token}", "Content-Type": "application/json", "Prefer": "return=representation"}
    with httpx.Client(base_url=data_api, timeout=30, headers=h) as c:
        def post(table: str, row: dict) -> str:
            res = c.post(f"/{table}", json=row)
            res.raise_for_status()
            return res.json()[0]["id"]
        prop = post("properties", {"user_id": uid, "title": "QA ONLY — DR drill", "address_line_1": "88 Harbour St",
                                   "city": "Toronto", "province_state": "ON", "postal_code": "M5J", "country": "CA"})
        room = post("rooms", {"property_id": prop, "name": "Kitchen", "sort_order": 0})
        insp = post("inspections", {"property_id": prop, "user_id": uid, "inspection_type": "move_in"})
        item = post("inspection_items", {"inspection_id": insp, "room_id": room, "notes": "Kitchen\nok", "condition_rating": 4})
        seeded, evidence = {}, []
        for n in range(2):
            path = f"{uid}/{prop}/move-in/{room}/drill-{n}.jpg"
            for key, body in ((path, secrets.token_bytes(40_000 + n)), (path[:-4] + "_thumb.jpg", secrets.token_bytes(4_000))):
                store.put_object(Bucket="inspection-media", Key=key, Body=body, ContentType="image/jpeg")
                seeded[("inspection-media", key)] = hashlib.sha256(body).hexdigest()
            evidence.append(post("evidence_files", {"property_id": prop, "inspection_item_id": item, "file_path": path,
                                                    "thumbnail_path": path[:-4] + "_thumb.jpg", "file_type": "image"}))
        lease = f"{uid}/{prop}/lease/drill.pdf"
        body = b"%PDF-1.4 drill " + secrets.token_bytes(10_000)
        store.put_object(Bucket="leases", Key=lease, Body=body, ContentType="application/pdf")
        seeded[("leases", lease)] = hashlib.sha256(body).hexdigest()
        post("property_documents", {"property_id": prop, "user_id": uid, "document_type": "lease", "file_path": lease,
                                    "file_name": "drill.pdf"})
    return {"uid": uid, "token": token, "property": prop, "evidence": evidence, "seeded": seeded}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--key-file", type=pathlib.Path, required=True)
    ap.add_argument("--workdir", type=pathlib.Path, required=True)
    ap.add_argument("--moto", default="moto_server", help="moto_server binary (local B2 stand-in, blank storage)")
    args = ap.parse_args()
    for var in ("DEV_DSN", "AWS_ENDPOINT_URL_S3", "NEON_AUTH_URL"):
        if not os.environ.get(var):
            sys.exit(f"{var} missing: source scripts/qa/dev_env.sh")
    if any("ep-steep-wind" in os.environ.get(v, "") or "br-solitary-glade" in os.environ.get(v, "")
           for v in ("DEV_DSN", "AWS_ENDPOINT_URL_S3", "NEON_AUTH_URL", "DEV_POOLED_DSN")):
        sys.exit("refused: the drill runs on dev only")
    work = args.workdir.expanduser()
    if work.exists() and any(work.iterdir()):
        sys.exit("--workdir must be empty")
    work.mkdir(parents=True, exist_ok=True)
    auth = os.environ["NEON_AUTH_URL"]
    data_api = auth.replace(".neonauth.", ".apirest.").replace("/neondb/auth", "/neondb/rest/v1")
    procs: list[subprocess.Popen] = []
    report: dict = {"b2": "real" if os.environ.get("B2_ENDPOINT") else "local stand-in (moto) — rerun with B2_*"}
    problems: list[str] = []
    cluster = None
    zero = [PY, str(ROOT / "scripts" / "qa" / "dev_zero_state.py")]
    zero_env = {**os.environ, "DATABASE_URL": os.environ["DEV_POOLED_DSN"], "APP_ENV": "development",
                "EXPORT_BUCKET_NAME": "exports", "PYTHONPATH": str(API), "REVENUECAT_WEBHOOK_SECRET": "x"}
    try:
        if not os.environ.get("B2_ENDPOINT"):
            procs.append(subprocess.Popen([args.moto, "-p", str(FAKE_B2_PORT)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            wait_http(f"http://127.0.0.1:{FAKE_B2_PORT}")
            fake = s3(FAKE_B2_PORT)
            for name in ("movemark-db-backups-drill", "movemark-evidence-backups-drill"):
                fake.create_bucket(Bucket=name, ObjectLockEnabledForBucket=True)
                fake.put_object_lock_configuration(Bucket=name, ObjectLockConfiguration={"ObjectLockEnabled": "Enabled",
                    "Rule": {"DefaultRetention": {"Mode": "GOVERNANCE", "Days": 1}}})
            os.environ.update({"B2_ENDPOINT": f"http://127.0.0.1:{FAKE_B2_PORT}", "B2_REGION": "us-east-1",
                               "B2_DB_BUCKET": "movemark-db-backups-drill", "B2_DB_KEY_ID": "drill", "B2_DB_APP_KEY": "drill",
                               "B2_EVIDENCE_BUCKET": "movemark-evidence-backups-drill", "B2_EVIDENCE_KEY_ID": "drill",
                               "B2_EVIDENCE_APP_KEY": "drill"})

        t0 = time.monotonic()
        run(zero, env=zero_env, cwd=API)  # refuses unless dev starts clean
        source = boto3.client("s3", endpoint_url=os.environ["AWS_ENDPOINT_URL_S3"], region_name=os.getenv("AWS_REGION"))
        fx = seed(auth, data_api, source)
        report["seeded_objects"] = len(fx["seeded"])

        out = run([PY, str(ROOT / "scripts" / "dr" / "backup.py"), "--project", "shiny-poetry-92207621", "--branch", "dev",
                   "--key-file", str(args.key_file), "--out", str(work / "local-backup"), "--database-only"])
        archive = pathlib.Path(re.search(r"backup written: (\S+)", out).group(1))
        report["push_db"] = run([PY, str(ROOT / "scripts" / "dr" / "offsite.py"), "push-db", str(archive)]).strip()
        report["sync_evidence"] = run([PY, str(ROOT / "scripts" / "dr" / "offsite.py"), "sync-evidence",
                                       "--key-file", str(args.key_file)]).strip()
        report["backup_s"] = round(time.monotonic() - t0, 1)

        t0 = time.monotonic()  # recovery: from B2 alone
        pulled = work / "from-b2"
        report["pull"] = run([PY, str(ROOT / "scripts" / "dr" / "offsite.py"), "pull", "--key-file", str(args.key_file),
                              "--to", str(pulled)]).strip()
        restored = subprocess.run([PY, str(ROOT / "scripts" / "dr" / "restore.py"), "--archive",
                                   str(next(pulled.glob("*.mmbk"))), "--key-file", str(args.key_file), "--workdir",
                                   str(work / "restored"), "--evidence", str(pulled / "evidence"), "--keep-running"],
                                  capture_output=True, text=True)
        report["restore"] = [line for line in restored.stdout.splitlines() if line.startswith(("{", "PROBLEM", "RESTORE_DRILL"))]
        match = re.search(r"RESTORED_CLUSTER host=(\S+) port=(\d+)", restored.stdout)
        if "RESTORE_DRILL PASS" not in restored.stdout or not match:
            sys.exit(f"restore failed:\n{restored.stdout[-2000:]}\n{restored.stderr[-1500:]}")
        cluster = (work / "restored" / "pgdata", match.group(1), match.group(2))

        procs.append(subprocess.Popen([args.moto, "-p", str(BLANK_S3_PORT)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
        wait_http(f"http://127.0.0.1:{BLANK_S3_PORT}")
        blank = s3(BLANK_S3_PORT)
        for bucket in BUCKETS:
            blank.create_bucket(Bucket=bucket)
        objects = 0
        for line in (pulled / "evidence" / "manifest.tsv").read_text().splitlines():
            bucket, key, _, digest = line.split("\t")
            blank.put_object(Bucket=bucket, Key=key, Body=(pulled / "evidence" / "objects" / bucket / key).read_bytes())
            objects += 1
        report["restored_objects"] = objects
        report["recovery_s"] = round(time.monotonic() - t0, 1)

        env = {**os.environ, "DATABASE_URL": f"postgresql://movemark_api@/neondb?host={cluster[1]}&port={cluster[2]}",
               "AWS_ENDPOINT_URL_S3": f"http://127.0.0.1:{BLANK_S3_PORT}", "AWS_ACCESS_KEY_ID": "drill",
               "AWS_SECRET_ACCESS_KEY": "drill", "AWS_REGION": "us-east-1", "EXPORT_BUCKET_NAME": "exports",
               "APP_ENV": "development", "REVENUECAT_WEBHOOK_SECRET": "drill", "REDIS_URL": "", "OBJECT_STORE": ""}
        procs.append(subprocess.Popen([PY, "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", str(API_PORT)],
                                      cwd=API, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
        base = f"http://127.0.0.1:{API_PORT}"
        wait_http(f"{base}/api/health")
        ready = httpx.get(f"{base}/api/ready", timeout=10)
        report["ready"] = ready.json()
        if ready.status_code != 200 or not ready.json().get("ok"):
            problems.append(f"/api/ready on the restored environment: {ready.status_code} {ready.text}")
        h = {"Authorization": f"Bearer {fx['token']}"}
        summary = httpx.get(f"{base}/api/vaults/{fx['property']}/summary", headers=h, timeout=10)
        if summary.status_code != 200 or summary.json()["walkthrough"]["documentedRooms"] != 1:
            problems.append(f"vault summary on the restored environment: {summary.status_code} {summary.text[:300]}")
        downloads = httpx.post(f"{base}/api/storage/downloads", headers=h, timeout=10,
                               json={"kind": "evidence", "ids": fx["evidence"]}).json()["items"]
        matched = 0
        for item in downloads:
            for url in (item["url"], item["thumbnailUrl"]):
                body = httpx.get(url, timeout=10).content
                if hashlib.sha256(body).hexdigest() in fx["seeded"].values():
                    matched += 1
        report["evidence_served_and_byte_identical"] = f"{matched}/{2 * len(fx['evidence'])}"
        if matched != 2 * len(fx["evidence"]):
            problems.append("restored evidence served by the API does not match what was seeded")
        restored_hashes = {(b, k): d for b, k, _, d in (l.split("\t") for l in
                           (pulled / "evidence" / "manifest.tsv").read_text().splitlines())}
        if any(restored_hashes.get(k) != v for k, v in fx["seeded"].items()):
            problems.append("a seeded object is missing from, or differs in, the B2 manifest")
    finally:
        for p in reversed(procs):
            p.send_signal(signal.SIGTERM)
            try:
                p.wait(timeout=10)
            except subprocess.TimeoutExpired:
                p.kill()
        if cluster:
            subprocess.run([str(pathlib.Path(os.getenv("MOVEMARK_PG18_BIN", "/opt/homebrew/opt/postgresql@18/bin")) / "pg_ctl"),
                            "-D", str(cluster[0]), "-m", "fast", "stop"], capture_output=True)
        cleanup = subprocess.run(zero, env=zero_env, cwd=API, capture_output=True, text=True)
        report["dev_after_cleanup"] = cleanup.stdout.strip().splitlines()[-1:] if cleanup.stdout else cleanup.stderr[-300:]
    print(json.dumps(report, indent=2))
    for p in problems:
        print("PROBLEM:", p)
    print("B2_DRILL", "PASS" if not problems else "FAIL")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
