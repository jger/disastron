#!/usr/bin/env bash
set -euo pipefail

# Get commit count from main branch
COMMIT_COUNT=$(git rev-list --count main)

# Use version passed as argument if provided, otherwise read from pubspec.yaml
if [ -n "${1:-}" ]; then
  BASE_VERSION="$1"
else
  BASE_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
fi

# Remove existing build number if present
BASE_VERSION=${BASE_VERSION%+*}

# Create new version with commit count as build number
NEW_VERSION="${BASE_VERSION}+${COMMIT_COUNT}"

# Update pubspec.yaml
sed -i.bak "s/^version: .*/version: ${NEW_VERSION}/" pubspec.yaml
rm -f pubspec.yaml.bak

echo "Updated version to: ${NEW_VERSION} (${COMMIT_COUNT} commits in main)"
