#!/bin/sh
# MoveMark — the scheduled off-site backup (Railway cron service `movemark-backup`, every 6 hours).
# Database: pg_dump as movemark_backup (read-only, migration 1010), encrypted, pushed to the B2 DB bucket and
# hash-checked after upload. Evidence: incremental, encrypted mirror into the B2 evidence bucket.
# Env (sealed Railway variables, this service only): BACKUP_DATABASE_URL, BACKUP_KEY_B64, B2_* , and the
# production Object Storage's read credentials AWS_*. Exits non-zero on any failure (Railway alerts on it).
set -eu
umask 077
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
printf %s "$BACKUP_KEY_B64" | base64 -d > "$work/backup.key"
[ "$(wc -c < "$work/backup.key" | tr -d ' ')" = 32 ] || { echo "BACKUP_KEY_B64 must decode to 32 bytes"; exit 2; }
cd /app
if [ "${BACKUP_BRANCH:-production}" = production ]; then
  target="--branch production --production --confirm br-solitary-glade-b5nc31al"
else
  target="--branch $BACKUP_BRANCH"  # drills against dev
fi
# shellcheck disable=SC2086
python scripts/dr/backup.py --project shiny-poetry-92207621 $target --database-only --dsn-env BACKUP_DATABASE_URL \
  --key-file "$work/backup.key" --out "$work/out"
python scripts/dr/offsite.py push-db "$(ls "$work"/out/*.mmbk)"
python scripts/dr/offsite.py sync-evidence --key-file "$work/backup.key"
echo "BACKUP_RUN OK $(date -u +%Y-%m-%dT%H:%M:%SZ)"
