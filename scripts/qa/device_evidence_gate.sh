#!/bin/zsh
# Device evidence gate (Neon dev only): reset the QA account, run DeviceEvidenceGateUITests on the paired iPhone,
# copy the DEBUG audit log off it. Then: device_evidence_verify.py, then testDeleteAccountThroughApp. See README.
set -u
D=$HOME/.movemark-qa/dev; cd /Volumes/sss/movemark/movemork
DEV=00008120-001A35112187C01E; CORE=81FDCD25-55F8-5A3B-BB86-0E7B80BAF64D
zsh -c 'source scripts/qa/dev_env.sh; cd $MOVEMARK_API_DIR; DATABASE_URL="$DEV_POOLED_DSN" APP_ENV=development EXPORT_BUCKET_NAME=exports PYTHONPATH=. REVENUECAT_WEBHOOK_SECRET=x .venv/bin/python ../movemork/scripts/qa/dev_zero_state.py' | tail -1
AUTH=https://ep-quiet-salad-b55aeba0.neonauth.c-7.us-east-2.aws.neon.tech/neondb/auth; O=https://ep-quiet-salad-b55aeba0.neonauth.c-7.us-east-2.aws.neon.tech
curl -s -o /dev/null -w 'qa sign-up %{http_code}\n' -H "Origin: $O" -H 'Content-Type: application/json' -X POST $AUTH/sign-up/email -d "{\"email\":\"qa-neon-a@movemark.test\",\"password\":\"$(cat $D/qa-a.password)\",\"name\":\"QA A\"}"
TEST_RUNNER_MM_QA_PASSWORD=$(cat $D/qa-a.password) xcodebuild test -project movemork.xcodeproj -scheme movemork \
  -destination "id=$DEV" -allowProvisioningUpdates -parallel-testing-enabled NO \
  "-only-testing:movemorkUITests/DeviceEvidenceGateUITests/testDeviceEvidenceGate" > $D/device-test.log 2>&1
grep -E 'error:|TEST (SUCCEEDED|FAILED)|Testing failed' $D/device-test.log | tail -5
rm -f $D/device-audit.log
xcrun devicectl device copy from --device $CORE --domain-type appDataContainer --domain-identifier movemark.movemork \
  --source Documents/evidence-audit.log --destination $D/device-audit.log > /dev/null 2>&1 && echo "audit log copied: $(wc -l < $D/device-audit.log) lines" || echo "audit log copy FAILED"
