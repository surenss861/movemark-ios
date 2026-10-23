# Gate 4 — Railway production cutover (2026-10-23)

| Item | Result |
|---|---|
| Code | `movemark-api-py` and `movemark-worker` deploy from `recovery/neon-api` (`5efbe13`), which contains every commit of the branches they ran before (`main`, `redesign/evidence-pdfs`) |
| `/api/health`, `/api/ready` | 200; database, export storage and Redis all ok |
| Docs / OpenAPI | 404 in production |
| Database roles | API sessions are `movemark_api` (application `movemark-api`), worker sessions `movemark_worker` (`movemark-worker`); separate passwords; no owner or migration credential in Railway |
| Supabase | `SUPABASE_*` removed from both services (applies with the next deploy); the code has no Supabase dependency |
| Two-account QA (`movemark-api-py/scripts/prod_qa_lifecycle.py`) | **41/41**: sign-up, rental, room, entry, 2 photos through upload tickets, lease, vault summary, byte-identical evidence download, worker-built move-in PDF downloaded; account B refused on 20 paths (Data API reads/updates/deletes/inserts, vault, capabilities, catalog, exports, signed downloads, storage deletes, report download, queuing a report, upload ticket) and A's data intact; both accounts deleted with zero residue in 12 tables, Neon Auth identities and all 7 buckets |
| RevenueCat webhook | wrong secret 401; real secret for an unmapped id 200 with no writes |
| Sentry | `SENTRY_DSN` set on both services; no synthetic error was raised in production |

Still open: sealing `DATABASE_URL`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `REVENUECAT_WEBHOOK_SECRET`
(dashboard action), and the `movemark-backup` cron service (needs the bucket-restricted B2 keys — Gate 3A).
