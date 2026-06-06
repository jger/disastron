#!/bin/bash

# Get commit count from main branch
COMMIT_COUNT=$(git rev-list --count main)

# Read current version from pubspec.yaml
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')

# Remove existing build number if present
CURRENT_VERSION=${CURRENT_VERSION%+*}

# Extract version parts (assuming format like 1.9.3)
VERSION_PARTS=(${CURRENT_VERSION//./ })
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

# Create new version with commit count as build number
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}+${COMMIT_COUNT}"

# Update pubspec.yaml
sed -i.bak "s/^version: .*/version: ${NEW_VERSION}/" pubspec.yaml
rm pubspec.yaml.bak

echo "Updated version to: ${NEW_VERSION} (${COMMIT_COUNT} commits in main)"
