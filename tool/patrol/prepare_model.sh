#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2024-2026 Jannis Gerardis
#
# One-time model seeding for the Patrol chat tests.
#
# The inference model download is slow (2.4GB for the default preset), so it
# must NEVER happen inside a test run. This script:
#
#   1. downloads the model ONCE into a host-side cache
#      (~/.cache/disastron/models, resumable, reused forever),
#   2. copies it into the app's private storage on the connected device at
#      files/patrol_seed/<filename> via `run-as` (debug builds only — which is
#      what `patrol test` builds),
#   3. pre-grants runtime permissions so no native permission dialog can
#      interrupt a test (important on MIUI, where UiAutomator-side dismissal
#      may be blocked).
#
# The test then installs the model from the seed file (local copy, fast) and,
# because app data is never cleared between runs (no clearPackageData) and the
# app restores its model registry on cold start, every later test run starts
# with the model already installed. Re-running this script is a no-op when the
# seed on the device already has the right size.
#
# Usage:
#   tool/patrol/prepare_model.sh [preset-id | url]
#   HF_TOKEN=hf_xxx tool/patrol/prepare_model.sh gemma3_270m_q8   # gated preset
#   ADB_SERIAL=XXXX tool/patrol/prepare_model.sh                  # pick a device
set -euo pipefail

PKG="dev.zardoz.disastron"
CACHE_DIR="${DISASTRON_MODEL_CACHE:-$HOME/.cache/disastron/models}"
PRESET="${1:-gemma4_e2b_litertlm}"

ADB=(adb)
if [ -n "${ADB_SERIAL:-}" ]; then
  ADB=(adb -s "$ADB_SERIAL")
fi

# Keep these URLs in sync with assets/data/inference_models.yaml.
case "$PRESET" in
  gemma4_e2b_litertlm)
    URL="https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm"
    ;;
  gemma4_e4b_litertlm)
    URL="https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm"
    ;;
  gemma3_270m_q8)
    # Gated on Hugging Face: export HF_TOKEN=hf_... (with Gemma license accepted).
    # NOTE: mediapipe backend — a litert-specific hang may NOT reproduce on it.
    URL="https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.task"
    ;;
  http://*|https://*)
    URL="$PRESET"
    ;;
  *)
    echo "error: unknown preset '$PRESET'." >&2
    echo "known: gemma4_e2b_litertlm (default) gemma4_e4b_litertlm gemma3_270m_q8, or a direct URL" >&2
    exit 1
    ;;
esac

FILE="$(basename "$URL")"
CACHED="$CACHE_DIR/$FILE"

echo "==> preset: $PRESET"
echo "==> file:   $FILE"

# --- 1. host-side cache (download once, resume partial downloads) -----------
mkdir -p "$CACHE_DIR"
if [ -s "$CACHED" ]; then
  echo "==> host cache hit: $CACHED ($(du -h "$CACHED" | cut -f1)) — skipping download"
else
  echo "==> downloading to $CACHED (resumable — re-run on interruption)"
  # NOTE: macOS ships bash 3.2, where expanding an EMPTY array under
  # `set -u` is an "unbound variable" error - hence the ${arr[@]+...} idiom.
  CURL_AUTH=()
  if [ -n "${HF_TOKEN:-}" ]; then
    CURL_AUTH=(-H "Authorization: Bearer $HF_TOKEN")
  fi
  curl -L --fail --retry 3 -C - ${CURL_AUTH[@]+"${CURL_AUTH[@]}"} -o "$CACHED.partial" "$URL"
  mv "$CACHED.partial" "$CACHED"
fi
LOCAL_SIZE=$(wc -c < "$CACHED" | tr -d ' ')
echo "==> local size: $LOCAL_SIZE bytes"

# --- 2. device checks --------------------------------------------------------
"${ADB[@]}" get-state >/dev/null || { echo "error: no adb device" >&2; exit 1; }

if ! "${ADB[@]}" shell pm path "$PKG" >/dev/null 2>&1; then
  cat >&2 <<EOF
error: $PKG is not installed on the device.

Install a DEBUG build first (run-as only works on debuggable apps), e.g.:
  fvm flutter build apk --debug
  adb install -r build/app/outputs/flutter-apk/app-debug.apk
or simply run 'patrol test' once (it installs the debug app), then re-run
this script, then run the test again.
EOF
  exit 1
fi

# --- 3. seed into app-private storage (idempotent) ---------------------------
DEVICE_SEED="files/patrol_seed/$FILE"
EXISTING=$("${ADB[@]}" shell run-as "$PKG" sh -c "\"wc -c < $DEVICE_SEED\"" 2>/dev/null | tr -d '[:space:]' || echo 0)
if [ "${EXISTING:-0}" = "$LOCAL_SIZE" ]; then
  echo "==> device seed already up to date ($DEVICE_SEED, $EXISTING bytes) — skipping push"
else
  echo "==> pushing to /data/local/tmp/$FILE"
  "${ADB[@]}" push "$CACHED" "/data/local/tmp/$FILE"
  echo "==> moving into app sandbox via run-as (debug build required)"
  "${ADB[@]}" shell run-as "$PKG" mkdir -p files/patrol_seed
  # run-as uid cannot read /data/local/tmp, but shell can: pipe across.
  "${ADB[@]}" shell "cat /data/local/tmp/$FILE | run-as $PKG sh -c 'cat > $DEVICE_SEED'"
  "${ADB[@]}" shell rm -f "/data/local/tmp/$FILE"
  SEEDED=$("${ADB[@]}" shell run-as "$PKG" sh -c "\"wc -c < $DEVICE_SEED\"" | tr -d '[:space:]')
  if [ "$SEEDED" != "$LOCAL_SIZE" ]; then
    echo "error: size mismatch after seeding (device $SEEDED vs local $LOCAL_SIZE)" >&2
    exit 1
  fi
  echo "==> seeded $DEVICE_SEED ($SEEDED bytes)"
fi

# --- 4. pre-grant runtime permissions (no native dialogs during tests) -------
echo "==> pre-granting runtime permissions"
for PERM in android.permission.ACCESS_FINE_LOCATION \
            android.permission.ACCESS_COARSE_LOCATION \
            android.permission.POST_NOTIFICATIONS; do
  "${ADB[@]}" shell pm grant "$PKG" "$PERM" 2>/dev/null || true
done

cat <<EOF

Done. Next:
  patrol test --target integration_test/chat_stop_regression_test.dart
(or: make patrol-test)

The first test run installs the model from the seed (one local copy,
~1-2 min); every run after that cold-start-restores it in seconds.
EOF
