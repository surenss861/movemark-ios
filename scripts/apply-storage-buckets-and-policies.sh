#!/usr/bin/env bash
# Applies supabase/migrations/20260329000001_storage_buckets_and_policies.sql to the remote DB.
# Use when `supabase db push` fails due to migration history mismatch (see supabase/migrations/README.md).
#
# Execution order:
#   1) If DATABASE_URL or SUPABASE_DB_URL is set → `psql` (direct Postgres; get URI from Dashboard → Database).
#   2) Else → `npx supabase@latest db query --linked` (needs `supabase link`; uses latest CLI — global
#      supabase before ~v2.5x has no `db query`, so do not call bare `supabase db query`).
set -euo pipefail
cd "$(dirname "$0")/.."
SQL_FILE="supabase/migrations/20260329000001_storage_buckets_and_policies.sql"

if [[ -n "${DATABASE_URL:-}" ]] || [[ -n "${SUPABASE_DB_URL:-}" ]]; then
  echo "Applying via psql: $SQL_FILE"
  psql "${DATABASE_URL:-$SUPABASE_DB_URL}" -v ON_ERROR_STOP=1 -f "$SQL_FILE"
  echo "OK: applied $SQL_FILE (direct Postgres)."
  exit 0
fi

echo "Applying via linked project (npx supabase@latest db query). You may see: Initialising login role…"
npx supabase@latest db query --linked -f "$SQL_FILE" --yes
echo "OK: applied $SQL_FILE to the linked Supabase project. Verify: Dashboard → Storage → buckets/policies."
