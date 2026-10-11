#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2024-2026 Jannis Gerardis
#
# Preflight before `patrol test`: Gradle connectedAndroidTest reinstalls the
# debug APK; INSTALL_FAILED_INSUFFICIENT_STORAGE surfaces as "Total: 0" tests.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PKG="dev.zardoz.disastron"
APP_APK="$REPO_ROOT/build/app/outputs/apk/debug/app-debug.apk"

ADB=(adb)
if [ -n "${1:-}" ]; then
  ADB=(adb -s "$1")
elif [ -n "${ADB_SERIAL:-}" ]; then
  ADB=(adb -s "$ADB_SERIAL")
fi

if ! "${ADB[@]}" get-state >/dev/null 2>&1; then
  echo "error: no adb device (pass DEVICE=<serial> or set ADB_SERIAL)." >&2
  exit 1
fi

# df -k /data → Filesystem 1K-blocks Used Available Use% Mount
read -r _fs total_kb used_kb avail_kb _pct _mount < <(
  "${ADB[@]}" shell df -k /data 2>/dev/null | tail -1 | tr -s ' '
)

total_kb="${total_kb:-0}"
avail_kb="${avail_kb:-0}"

apk_mb=400
if [ -f "$APP_APK" ]; then
  if stat -f%z "$APP_APK" >/dev/null 2>&1; then
    apk_bytes="$(stat -f%z "$APP_APK")"
  else
    apk_bytes="$(stat -c%s "$APP_APK")"
  fi
  apk_mb="$(( (apk_bytes + 1024 * 1024 - 1) / (1024 * 1024) ))"
fi

# Install sessions need headroom beyond the APK size (staged copy + dexopt).
need_free_mb="$(( apk_mb * 2 + 400 ))"
avail_mb="$(( avail_kb / 1024 ))"
total_gb="$(( (total_kb * 1024) / (1024 * 1024 * 1024) ))"

app_data_mb=""
if du_out="$("${ADB[@]}" shell run-as "$PKG" du -sk . 2>/dev/null | awk '{print $1}')"; then
  app_data_mb="$(( du_out / 1024 ))"
fi

fail=0

# userdata-qemu.img is sized at AVD creation; bumping config.ini alone does not grow it.
min_total_gb=18
if [ "$total_kb" -gt 0 ] && [ "$total_gb" -lt "$min_total_gb" ]; then
  echo "error: /data partition is ~${total_gb}G (Patrol + seeded model needs ≥${min_total_gb}G)." >&2
  echo "fix:   Android Studio → Device Manager → Pixel_10 (or this AVD) → Wipe Data," >&2
  echo "       then cold boot (config.ini disk.dataPartition.size=24G applies on fresh userdata)." >&2
  echo "       Re-seed: make patrol-prepare DEVICE=${1:-\$DEVICE}" >&2
  fail=1
fi

if [ "$avail_mb" -lt "$need_free_mb" ]; then
  echo "error: only ~${avail_mb}MB free on /data; need ~${need_free_mb}MB to reinstall app-debug.apk (~${apk_mb}MB)." >&2
  if [ -n "$app_data_mb" ]; then
    echo "note:  app sandbox is ~${app_data_mb}MB (model seed); do not pm clear the app to free space." >&2
  fi
  echo "fix:   wipe AVD data (see above) or use a device/AVD with a larger /data partition." >&2
  echo "symptom: Gradle report INSTALL_FAILED_INSUFFICIENT_STORAGE, Patrol summary Total: 0." >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "patrol device ok: /data ~${avail_mb}MB free (${total_gb}G total), apk ~${apk_mb}MB."
