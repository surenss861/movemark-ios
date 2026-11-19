"""MoveMark QA — purge QA leftovers on Neon dev through the account-deletion path, then count what remains.

    (cd movemark-api-py && PYTHONPATH=. .venv/bin/python ../movemork/scripts/qa/dev_zero_state.py [--count-only])

Prints COUNTS {...} and DEV_ZEROED / DEV_NOT_ZEROED. Needs the env from scripts/qa/dev_env.sh.
Dev holds QA data only; this is never pointed at production (dev_env.sh refuses production credentials).
"""
import asyncio
import os
import sys

if "ep-steep-wind" in os.environ.get("DATABASE_URL", "") or "br-dark-scene" not in os.environ.get("AWS_ENDPOINT_URL_S3", ""):
    sys.exit("refusing: not the Neon dev branch")

from app import db, object_store  # noqa: E402
from app.services.delete_account import delete_account_for_user  # noqa: E402

QA_EMAILS = ("qa-neon-a@movemark.test", "qa-neon-b@movemark.test")


async def main(count_only: bool) -> None:
    if not count_only:
        ids = {r["id"] for r in await db.rows('SELECT id::text AS id FROM neon_auth."user" WHERE email = ANY(%s)', list(QA_EMAILS))}
        ids |= {r["id"] for r in await db.rows(
            """SELECT DISTINCT uid::text AS id FROM (SELECT user_id AS uid FROM properties UNION SELECT user_id FROM exports
               UNION SELECT user_id FROM storage_upload_tickets UNION SELECT id FROM profiles) t
               WHERE uid NOT IN (SELECT id FROM neon_auth."user")""")}
        live = {r["id"] for r in await db.rows('SELECT id::text AS id FROM neon_auth."user"')}
        for bucket in object_store.BUCKETS:
            for key in await object_store.list_prefix(bucket, ""):
                if (owner := key.split("/", 1)[0].lower()) not in live:
                    ids.add(owner)
        for uid in sorted(ids):
            await delete_account_for_user(uid)
            print("purged via account-deletion path:", uid)
    counts: dict = {"auth_users": await db.scalar('SELECT count(*) FROM neon_auth."user"')}
    for table in ("profiles", "properties", "rooms", "inspections", "inspection_items", "evidence_files", "property_documents",
                  "maintenance_issues", "disputes", "exports", "storage_upload_tickets", "user_entitlements", "user_report_credits"):
        counts[table] = await db.scalar(f"SELECT count(*) FROM public.{table}")
    counts["objects"] = {b: len(await object_store.list_prefix(b, "")) for b in object_store.BUCKETS}
    await db.close_pool()
    print("COUNTS", counts)
    clean = all(v == 0 for k, v in counts.items() if k != "objects") and not any(counts["objects"].values())
    print("DEV_ZEROED" if clean else "DEV_NOT_ZEROED")


asyncio.run(main("--count-only" in sys.argv))
