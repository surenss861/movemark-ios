#!/usr/bin/env bash
# Applies supabase/migrations/20260329000001_storage_buckets_and_policies.sql to the linked remote DB.
# Use when `supabase db push` fails due to migration history mismatch (see supabase/migrations/README.md).
# Requires: `supabase link` and `npx` (uses latest Supabase CLI for `db query --linked`).
set -euo pipefail
cd "$(dirname "$0")/.."
npx supabase@latest db query --linked \
  -f supabase/migrations/20260329000001_storage_buckets_and_policies.sql \
  --yes
