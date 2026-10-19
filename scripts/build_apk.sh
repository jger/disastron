#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: $0 <version>}"

flutter build apk --release

mkdir -p dist
APK_NAME="disastron-${VERSION}.apk"
cp build/app/outputs/flutter-apk/app-release.apk "dist/${APK_NAME}"
(
  cd dist
  shasum -a 256 "${APK_NAME}" > "${APK_NAME}.sha256"
)

echo "Built dist/${APK_NAME} and dist/${APK_NAME}.sha256"
