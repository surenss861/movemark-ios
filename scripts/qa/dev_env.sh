#!/bin/zsh
# MoveMark QA — dev-branch credentials for the local harness, fetched from the Neon CLI (never committed).
#   source scripts/qa/dev_env.sh          # exports QA_DIR, DEV_DSN, DEV_POOLED_DSN and the dev AWS_* (Object Storage)
# Writes to $MOVEMARK_QA_HOME (default ~/.movemark-qa/dev, mode 0700). Refuses anything that resolves to production.
set -u
: ${MOVEMARK_QA_HOME:=$HOME/.movemark-qa/dev}
NEON_PROJECT=shiny-poetry-92207621
DEV_ENDPOINT=ep-quiet-salad-b55aeba0
DEV_STORAGE=br-dark-scene-b582uffs
PROD_ENDPOINT=ep-steep-wind-b56266ss
QA_DIR=$MOVEMARK_QA_HOME
( umask 077; mkdir -p $QA_DIR/link )
if [[ ! -s $QA_DIR/dev.env || ! -s $QA_DIR/dev.dsn || ! -s $QA_DIR/dev-pooled.dsn ]]; then
  ( umask 077; cd $QA_DIR/link
    neon link --project-id $NEON_PROJECT --branch dev -y --no-env-pull >/dev/null 2>&1
    neon env pull --file $QA_DIR/dev.env >/dev/null 2>&1
    neon connection-string dev --project-id $NEON_PROJECT --role-name neondb_owner --database-name neondb > $QA_DIR/dev.dsn
    neon connection-string dev --project-id $NEON_PROJECT --role-name neondb_owner --database-name neondb --pooled > $QA_DIR/dev-pooled.dsn )
fi
grep -q $PROD_ENDPOINT $QA_DIR/dev.dsn $QA_DIR/dev-pooled.dsn $QA_DIR/dev.env && { echo "refusing: production credentials in $QA_DIR"; return 1 2>/dev/null || exit 1; }
grep -q $DEV_ENDPOINT $QA_DIR/dev.dsn || { echo "refusing: $QA_DIR/dev.dsn is not the dev endpoint"; return 1 2>/dev/null || exit 1; }
set -a; . $QA_DIR/dev.env; set +a; unset OBJECT_STORE
[[ "$AWS_ENDPOINT_URL_S3" == *$DEV_STORAGE* ]] || { echo "refusing: storage is not the dev branch"; return 1 2>/dev/null || exit 1; }
export QA_DIR DEV_DSN="$(cat $QA_DIR/dev.dsn)" DEV_POOLED_DSN="$(cat $QA_DIR/dev-pooled.dsn)"
export NEON_AUTH_URL=https://$DEV_ENDPOINT.neonauth.c-7.us-east-2.aws.neon.tech/neondb/auth
export NEON_DATA_API_URL=https://$DEV_ENDPOINT.apirest.c-7.us-east-2.aws.neon.tech/neondb/rest/v1
export MOVEMARK_API_DIR=${MOVEMARK_API_DIR:-${0:A:h}/../../../movemark-api-py}
