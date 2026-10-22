#!/bin/zsh
# Device partial-save test (Neon dev only): reset the QA account, arm fault_proxy.py for one API outage at
# the second photo's finalize, run DeviceEvidenceGateUITests/testPartialSaveIsReportedAndRetried on the
# paired iPhone. Then: device_partial_save_check.py <email> 2. See README.
set -u
D=$HOME/.movemark-qa/dev; cd /Volumes/sss/movemark/movemork
DEV=00008120-001A35112187C01E
zsh -c 'source scripts/qa/dev_env.sh; cd $MOVEMARK_API_DIR; DATABASE_URL="$DEV_POOLED_DSN" APP_ENV=development EXPORT_BUCKET_NAME=exports PYTHONPATH=. REVENUECAT_WEBHOOK_SECRET=x .venv/bin/python ../movemork/scripts/qa/dev_zero_state.py' | tail -1
AUTH=https://ep-quiet-salad-b55aeba0.neonauth.c-7.us-east-2.aws.neon.tech/neondb/auth; O=https://ep-quiet-salad-b55aeba0.neonauth.c-7.us-east-2.aws.neon.tech
curl -s -o /dev/null -w 'qa sign-up %{http_code}\n' -H "Origin: $O" -H 'Content-Type: application/json' -X POST $AUTH/sign-up/email -d "{\"email\":\"qa-neon-a@movemark.test\",\"password\":\"$(cat $D/qa-a.password)\",\"name\":\"QA A\"}"
echo outage-second-finalize > $D/fault.mode; echo "proxy armed"
TEST_RUNNER_MM_QA_PASSWORD=$(cat $D/qa-a.password) xcodebuild test -project movemork.xcodeproj -scheme movemork \
  -destination "id=$DEV" -allowProvisioningUpdates -parallel-testing-enabled NO \
  "-only-testing:movemorkUITests/DeviceEvidenceGateUITests/testPartialSaveIsReportedAndRetried" > $D/device-partial.log 2>&1
grep -E 'error:|TEST (SUCCEEDED|FAILED)|Testing failed' $D/device-partial.log | tail -5
echo "proxy mode after run: $(cat $D/fault.mode)"; echo off > $D/fault.mode
