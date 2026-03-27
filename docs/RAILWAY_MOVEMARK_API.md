# MoveMark Railway API (first pass)

## Endpoints

- `GET /api/health`
- `POST /api/exports/move-in`
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

- `POST /api/exports/move-in` currently generates a simple text-based PDF placeholder buffer for pipeline validation.
- It writes export records to `exports` table and uploads files to Supabase Storage.
- Contract returns `status: queued` for client compatibility, even though processing is synchronous in v1.
