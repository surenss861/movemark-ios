#!/usr/bin/env bash
# Applies supabase/migrations/20260328000001_exports_requested_completed_at.sql to the linked remote DB.
# Requires: `supabase link` and `npx` (uses latest Supabase CLI for `db query --linked`).
set -euo pipefail
cd "$(dirname "$0")/.."
npx supabase@latest db query --linked \
  -f supabase/migrations/20260328000001_exports_requested_completed_at.sql \
  --yes
