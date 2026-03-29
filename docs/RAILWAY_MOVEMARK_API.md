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
