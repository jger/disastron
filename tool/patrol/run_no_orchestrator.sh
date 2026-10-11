#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2024-2026 Jannis Gerardis
#
# Fallback Patrol runner for devices where Gradle's connectedAndroidTest
# cannot install test APKs (MIUI blocks `pm install -g` with
# INSTALL_GRANT_RUNTIME_PERMISSIONS unless "USB debugging (Security
# settings)" is enabled — see docs/patrol-chat-stop-investigation.md).
#
# Instead of `patrol test` (which delegates install+run to Gradle/UTP) this:
#   1. builds both APKs via `patrol build android` (Gradle build only),
#   2. installs them with plain `adb install -r` (no -g flag),
#   3. pre-grants runtime permissions with `pm grant` (allowed on MIUI),
#   4. runs `am instrument` once PER TEST — each test gets a fresh app
#      process, giving the same isolation the orchestrator would.
#
# Usage:
#   tool/patrol/run_no_orchestrator.sh                 # run all listed tests
#   ADB_SERIAL=XXXX tool/patrol/run_no_orchestrator.sh # pick a device
set -euo pipefail

PKG="dev.zardoz.disastron"
RUNNER="$PKG.test/pl.leancode.patrol.PatrolJUnitRunner"
TARGET="${TARGET:-patrol_test/chat_stop_regression_test.dart}"

# Keep in sync with the patrolTest() names in $TARGET.
# No commas/colons — `am instrument -e` splits arguments on commas.
TESTS=(
  "A stop mid-stream then continue immediately"
  "B stop mid-stream then drain then continue"
)

ADB=(adb)
if [ -n "${ADB_SERIAL:-}" ]; then
  ADB=(adb -s "$ADB_SERIAL")
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

echo "==> building app + test APKs (patrol build android)"
patrol build android --target "$TARGET"

APP_APK="build/app/outputs/apk/debug/app-debug.apk"
TEST_APK="build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
for f in "$APP_APK" "$TEST_APK"; do
  [ -f "$f" ] || { echo "error: expected APK not found: $f" >&2; exit 1; }
done

echo "==> installing APKs (plain install, no -g)"
"${ADB[@]}" install -r "$APP_APK"
"${ADB[@]}" install -r "$TEST_APK"

echo "==> pre-granting runtime permissions"
for PERM in android.permission.ACCESS_FINE_LOCATION \
            android.permission.ACCESS_COARSE_LOCATION \
            android.permission.POST_NOTIFICATIONS; do
  "${ADB[@]}" shell pm grant "$PKG" "$PERM" 2>/dev/null || true
done

FAILED=0
for NAME in "${TESTS[@]}"; do
  echo
  echo "=============================================================="
  echo "==> running: $NAME"
  echo "=============================================================="
  OUT=$("${ADB[@]}" shell "am instrument -w -e class \"$PKG.MainActivityTest#runDartTest[$NAME]\" $RUNNER" 2>&1 | tee /dev/stderr)
  if echo "$OUT" | grep -q "OK (1 test)"; then
    echo "==> PASSED: $NAME"
  else
    echo "==> FAILED: $NAME"
    FAILED=1
  fi
done

echo
if [ "$FAILED" -ne 0 ]; then
  echo "Result: at least one scenario FAILED — for scenario A that means the"
  echo "stop-then-continue bug REPRODUCED. Details are in the instrumentation"
  echo "output above and in: adb logcat -s flutter:V (look for"
  echo "[chat-stop-patrol ...] lines and time-to-first-chunk)."
  exit 1
fi
echo "Result: all scenarios passed — the chat survived stop-then-continue."
