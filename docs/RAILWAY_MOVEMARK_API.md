# MoveMark Railway API (first pass)

## Endpoints

- `GET /` — service identity JSON
- `GET /api/health`
- `GET /api/exports` — requires `Authorization: Bearer <Supabase access token>`
- `POST /api/exports/move-in` — same auth; body `{ "propertyId": "<uuid>", "format": "pdf" }`
- `GET /api/exports/:id/download` — same auth; signed URL when export is `completed`
- `POST /api/webhooks/revenuecat`

## Required Railway variables

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `EXPORT_BUCKET_NAME` (use `exports` if using Supabase Storage bucket `exports`)
- `REVENUECAT_WEBHOOK_SECRET` (optional but recommended)
- `APP_ENV=production`

## Local run

```bash
cd movemark-api
npm install
npm run dev
```

## Notes

- `POST /api/exports/move-in` runs **synchronously**: insert row (`queued` in DB briefly), generate PDF, upload to Storage, then finalize the row to `completed`.
- Successful JSON response uses **`status: "completed"`** (matches DB and client contract).
- Rows still use internal statuses (`queued`, `completed`, etc.) for list/download; download returns **404** if the export belongs to another user.

## Troubleshooting `GET /api/exports` → 500 `Failed to load exports`

The route uses the **service role** (bypasses RLS). A **500** means PostgREST returned an error (not auth). Check **Railway runtime logs** for:

`[movemark-api:exports] list query failed` with `message`, `code`, `details`, `hint`.

Typical causes: **`exports` table or column missing** in the linked Supabase project (migrate schema), wrong **`SUPABASE_URL`**, or invalid **`SUPABASE_SERVICE_ROLE_KEY`**.

The list route orders by **`created_at`** and does not require **`requested_at`** (some DBs never had that column).
