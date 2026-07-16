# generate-dispute-packet (DEPRECATED)

This Edge Function builds an **HTML** dispute packet and is a legacy parallel path.

**Canonical path (use this):** Railway `movemark-api`

- `POST /api/exports/dispute-packet` enqueues a PDF job (`status=queued`)
- Worker (`npm run start:worker`) builds the PDF checklist with `pdf-lib`
- Client polls `GET /api/exports` / download when `completed`

Do **not** add new features here. Prefer deleting this function after confirming no clients still call `supabase.functions.invoke("generate-dispute-packet")`.
