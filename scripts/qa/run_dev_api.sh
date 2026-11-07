#!/bin/zsh
# MoveMark QA — the local MoveMark API (127.0.0.1:8787) + export worker against Neon dev only.
#   scripts/qa/run_dev_api.sh [--no-worker]      (foreground; run it in its own terminal or background)
# API_DOCS=off is passed through when set (e.g. while a temporary tunnel exposes the API).
set -u
source ${0:A:h}/dev_env.sh || exit 1
cd $MOVEMARK_API_DIR
# Runtime roles (migration 0960), never the schema owner: scripts/db/runtime_roles.py writes these DSNs.
for role in movemark_api movemark_worker; do
  [[ -s $QA_DIR/$role.dsn ]] || { echo "missing $QA_DIR/$role.dsn: run scripts/db/runtime_roles.py --branch dev"; exit 1; }
done
export DATABASE_URL="$(<$QA_DIR/movemark_api.dsn)" APP_ENV=development EXPORT_BUCKET_NAME=exports PYTHONPATH=. \
       REVENUECAT_WEBHOOK_SECRET=$(python3 -c "import secrets;print(secrets.token_urlsafe(24))")
print -n "$REVENUECAT_WEBHOOK_SECRET" > $QA_DIR/hook.secret
pkill -f "uvicorn app[.]main:app --host 127[.]0[.]0[.]1 --port 8787"  # [.]: never matches a shell that mentions it
pkill -f "Python worker[.]py"   # the [.] keeps this pattern from matching the shell running it
[[ "${1:-}" == "--no-worker" ]] || { DATABASE_URL="$(<$QA_DIR/movemark_worker.dsn)" .venv/bin/python worker.py > $QA_DIR/worker.log 2>&1 & }
exec .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8787 --log-level info > $QA_DIR/uvicorn.log 2>&1
