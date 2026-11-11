#!/usr/bin/env bash
# Regenerates the feature catalog, then commits and pushes only if the
# analyzer is clean and every test passes. Usage: tools/ship.sh "message"
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/gen_features.py
flutter analyze 2>&1 | tee /tmp/pct-analyze.log | tail -1
grep -q "No issues found" /tmp/pct-analyze.log || { grep -E "error|warning|info" /tmp/pct-analyze.log | head -20; exit 1; }
if ! flutter test > /tmp/pct-test.log 2>&1; then
  grep -E "^\s+(Expected|Actual|Which)|\[E\]|The following|_test.dart:[0-9]+|Error:" /tmp/pct-test.log | head -40
  exit 1
fi
tail -1 /tmp/pct-test.log
if grep -rn "TODO\|FIXME" lib android/app/src/main/kotlin; then echo "TODO left in shipped code"; exit 1; fi
git add -A
git commit -qm "$1

Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01NYP52rDeb6B3Gn1kn3scKt"
git push -q origin HEAD:claude/productivity-challenger-timer-android-hpketf
git push -q origin HEAD:main
echo SHIPPED
