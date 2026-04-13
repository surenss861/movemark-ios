#!/usr/bin/env bash
# Applies supabase/migrations/20260328000001_exports_requested_completed_at.sql to the remote DB.
# See apply-storage-buckets-and-policies.sh for DATABASE_URL vs npx behavior and CLI version notes.
set -euo pipefail
cd "$(dirname "$0")/.."
SQL_FILE="supabase/migrations/20260328000001_exports_requested_completed_at.sql"

if [[ -n "${DATABASE_URL:-}" ]] || [[ -n "${SUPABASE_DB_URL:-}" ]]; then
  echo "Applying via psql: $SQL_FILE"
  psql "${DATABASE_URL:-$SUPABASE_DB_URL}" -v ON_ERROR_STOP=1 -f "$SQL_FILE"
  echo "OK: applied $SQL_FILE (direct Postgres)."
  exit 0
fi

echo "Applying via linked project (npx supabase@latest db query). You may see: Initialising login role…"
npx supabase@latest db query --linked -f "$SQL_FILE" --yes
echo "OK: applied $SQL_FILE to the linked Supabase project."
