#!/bin/zsh
# MoveMark QA — the iOS lifecycle gate (movemorkTests/NeonDevLifecycleTests) against Neon dev, serially.
#   scripts/qa/ios_lifecycle.sh [refresh-wait-seconds=960] [simulator-udid]
# Needs scripts/qa/run_dev_api.sh running (API + worker). Purges QA leftovers and refuses to start unless dev is
# zeroed; relays the password-reset token (QA addresses can't receive mail); reports dev state after the run
# BEFORE any purge, so a cleanup leak is visible.
set -u
source ${0:A:h}/dev_env.sh || exit 1
WAIT=${1:-960}; SIM=${2:-995B6115-724C-4B50-AAA8-CBC12BB60D89}
REPO=${0:A:h}/../..; E2E=$QA_DIR/ios-e2e; RUN_ID=$(date +%Y%m%d%H%M%S)-$(openssl rand -hex 2)
zero_state() { (cd $MOVEMARK_API_DIR && DATABASE_URL="$DEV_POOLED_DSN" APP_ENV=development EXPORT_BUCKET_NAME=exports PYTHONPATH=. \
                REVENUECAT_WEBHOOK_SECRET=x .venv/bin/python $REPO/scripts/qa/dev_zero_state.py "$@") }

echo "=== run $RUN_ID: pre-run purge"
pre=$(zero_state); echo "$pre"
grep -q '^DEV_ZEROED' <<<"$pre" || { echo "refusing to start: dev is not zeroed"; exit 2; }
curl -sf http://127.0.0.1:8787/api/ready >/dev/null || { echo "refusing: dev API not running (scripts/qa/run_dev_api.sh)"; exit 2; }
xcrun simctl list devices | grep "$SIM" | grep -q Booted || { xcrun simctl boot $SIM; xcrun simctl bootstatus $SIM -b >/dev/null; }

rm -rf $E2E; mkdir -p $E2E
( for i in $(seq 1 3000); do
    if [[ -f $E2E/reset-request ]]; then
      uid=$(cat $E2E/reset-request)
      tok=$(psql -X "$DEV_DSN" -Atc "select substring(identifier from 16) from neon_auth.verification where identifier like 'reset-password:%' and value = '$uid' order by \"createdAt\" desc limit 1")
      [[ -n "$tok" ]] && { print -n "$tok" > $E2E/reset-token; break; }
    fi
    sleep 1
  done ) &
RELAY=$!
echo "=== run $RUN_ID: xcodebuild (serial)"
(cd $REPO && TEST_RUNNER_MM_E2E_DIR=$E2E TEST_RUNNER_MM_E2E_PHOTO=$REPO/movemorkTests/Fixtures/snap-kitchen.jpg \
  TEST_RUNNER_MM_E2E_REFRESH_WAIT=$WAIT TEST_RUNNER_MM_E2E_STOREKIT=$REPO/MoveMark.storekit TEST_RUNNER_MM_E2E_RUN_ID=$RUN_ID \
  xcodebuild test -project movemork.xcodeproj -scheme movemork -destination "id=$SIM" \
  -parallel-testing-enabled NO -only-testing:movemorkTests/NeonDevLifecycleTests > $E2E/xcodebuild.log 2>&1)
RC=$?
kill $RELAY 2>/dev/null
echo "xcodebuild exit=$RC"; grep -E '\*\* TEST' $E2E/xcodebuild.log | tail -1
R=$(grep -oE '/[^ ]+\.xcresult' $E2E/xcodebuild.log | tail -1)
[[ -n "$R" ]] && xcrun xcresulttool get test-results summary --path "$R" 2>/dev/null | python3 -c "import json,sys;d=json.load(sys.stdin);print('SUMMARY',{k:d.get(k) for k in ('result','totalTestCount','passedTests','failedTests','skippedTests')});[print('ISSUE:',f['failureText']) for f in d.get('testFailures',[])]"
echo "--- steps"; cat $E2E/steps.log 2>/dev/null; echo "--- last checkpoint: $(cat $E2E/last-step 2>/dev/null)"
echo "=== run $RUN_ID: post-run state (before any purge)"
zero_state --count-only
exit $RC
