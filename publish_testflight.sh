#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PUBSPEC_PATH="$SCRIPT_DIR/pubspec.yaml"
PBXPROJ_PATH="$SCRIPT_DIR/ios/Runner.xcodeproj/project.pbxproj"
APP_NAME="olden_era_wiki"
BUNDLE_ID="com.wiki.oldenera"
OLD_BUNDLE_ID="com.oldenera.oldenEraWiki"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
APP_VERSION="${1:-}"
# Auto-incrementing integer build number. Unless an explicit BUILD_NUMBER is
# provided, read the current "+N" build component from pubspec.yaml and bump it
# by one (1, 2, 3, ...). A missing or non-integer build (e.g. a legacy
# timestamp) resets the counter to 1. The resolved value is written back to
# pubspec.yaml later in this script, so it carries forward across runs.
if [ -z "${BUILD_NUMBER:-}" ]; then
  CURRENT_BUILD="$(grep -Eo '^version: [0-9]+\.[0-9]+\.[0-9]+\+[0-9]+' "$PUBSPEC_PATH" | head -n 1 | grep -Eo '[0-9]+$' || true)"
  # Only treat a small integer as a valid counter. A legacy timestamp build
  # (e.g. 202606151404) exceeds Android's 32-bit versionCode limit, so reset
  # the counter to 1 instead of continuing to grow it.
  if [ -n "$CURRENT_BUILD" ] && [ "$CURRENT_BUILD" -lt 1000000 ]; then
    BUILD_NUMBER="$((CURRENT_BUILD + 1))"
  else
    BUILD_NUMBER="1"
  fi
fi
TEAM_ID="${TEAM_ID:-9LK4YZ82JR}"
# App Store Connect API key for the upload step. The .p8 file lives in a
# standard altool location (e.g. ~/private_keys/AuthKey_<KEYID>.p8) and is
# discovered automatically by key ID.
ASC_KEY_ID="${ASC_KEY_ID:-2NSNUQ93S3}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-52948c26-8a96-4637-8cf2-a94362bce846}"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-$SCRIPT_DIR/build/testflight/$BUILD_NUMBER}"
EXPORT_OPTIONS_PLIST="$ARTIFACT_ROOT/ExportOptions.plist"
SYSTEM_TOOL_PATH="/usr/bin:/bin:/usr/sbin:/sbin"

if [ ! -d "$DEVELOPER_DIR" ]; then
  printf 'Missing Xcode developer directory: %s\n' "$DEVELOPER_DIR" >&2
  exit 1
fi

if [ ! -f "$PUBSPEC_PATH" ]; then
  printf 'Missing pubspec.yaml: %s\n' "$PUBSPEC_PATH" >&2
  exit 1
fi

if [ ! -f "$PBXPROJ_PATH" ]; then
  printf 'Missing project file: %s\n' "$PBXPROJ_PATH" >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  printf 'flutter is not on PATH\n' >&2
  exit 1
fi

# A supplied version must be MAJOR.MINOR.PATCH before it reaches pubspec.yaml.
if [ -n "$APP_VERSION" ] && ! printf '%s' "$APP_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  printf 'Invalid version "%s". Expected MAJOR.MINOR.PATCH, e.g. ./publish_testflight.sh 2.0.0\n' "$APP_VERSION" >&2
  exit 1
fi

# Read the current marketing version (the MAJOR.MINOR.PATCH before the "+build").
CURRENT_VERSION="$(grep -Eo '^version: [0-9]+\.[0-9]+\.[0-9]+' "$PUBSPEC_PATH" | head -n 1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')"
if [ -z "$CURRENT_VERSION" ]; then
  printf 'Could not read a MAJOR.MINOR.PATCH version from %s\n' "$PUBSPEC_PATH" >&2
  exit 1
fi

# Resolve the marketing version: a supplied argument wins; otherwise the
# current patch component is incremented.
if [ -n "$APP_VERSION" ]; then
  TARGET_VERSION="$APP_VERSION"
  printf 'Using version from argument: %s\n' "$TARGET_VERSION"
else
  MAJOR="${CURRENT_VERSION%%.*}"
  REST="${CURRENT_VERSION#*.}"
  MINOR="${REST%%.*}"
  PATCH="${REST#*.}"
  TARGET_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
  printf 'Auto-bumped marketing version: %s -> %s\n' "$CURRENT_VERSION" "$TARGET_VERSION"
fi

APP_VERSION="$TARGET_VERSION"

# Persist the resolved version and build number to pubspec.yaml.
TMP_PUBSPEC="$(mktemp)"
sed -E "s/^version: .*/version: $APP_VERSION+$BUILD_NUMBER/" "$PUBSPEC_PATH" > "$TMP_PUBSPEC"
mv "$TMP_PUBSPEC" "$PUBSPEC_PATH"
printf 'Updated pubspec.yaml version to %s+%s\n' "$APP_VERSION" "$BUILD_NUMBER"

# Ensure the Runner app target uses the desired bundle identifier. Only the
# exact "com.oldenera.oldenEraWiki;" lines are rewritten so the .RunnerTests
# identifiers stay untouched. Safe to run repeatedly.
if grep -q "PRODUCT_BUNDLE_IDENTIFIER = $OLD_BUNDLE_ID;" "$PBXPROJ_PATH"; then
  TMP_PBXPROJ="$(mktemp)"
  sed "s/PRODUCT_BUNDLE_IDENTIFIER = $OLD_BUNDLE_ID;/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;/g" "$PBXPROJ_PATH" > "$TMP_PBXPROJ"
  mv "$TMP_PBXPROJ" "$PBXPROJ_PATH"
  printf 'Updated bundle identifier to %s\n' "$BUNDLE_ID"
fi

mkdir -p "$ARTIFACT_ROOT"

cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>destination</key>
	<string>export</string>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
	<key>method</key>
	<string>app-store-connect</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>$TEAM_ID</string>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
EOF

printf 'Building and uploading %s\n' "$APP_NAME"
printf 'Bundle ID: %s\n' "$BUNDLE_ID"
printf 'Version: %s\n' "$APP_VERSION"
printf 'Build: %s\n' "$BUILD_NUMBER"
printf 'Artifacts: %s\n' "$ARTIFACT_ROOT"

# flutter build ipa archives, signs, and (with destination=export in the
# export options) writes a distribution-signed .ipa to build/ios/ipa/. The
# upload happens as a separate altool step below.
# Force Apple's rsync during IPA packaging. Homebrew rsync breaks exportArchive.
PATH="$SYSTEM_TOOL_PATH:$PATH" DEVELOPER_DIR="$DEVELOPER_DIR" flutter build ipa \
  --release \
  --build-name "$APP_VERSION" \
  --build-number "$BUILD_NUMBER" \
  --export-options-plist "$EXPORT_OPTIONS_PLIST"

IPA_PATH="$(ls "$SCRIPT_DIR/build/ios/ipa/"*.ipa 2>/dev/null | head -n1)"
if [ -z "$IPA_PATH" ]; then
  printf 'No IPA found in build/ios/ipa/ — export failed\n' >&2
  exit 1
fi

printf 'Uploading %s to App Store Connect\n' "$IPA_PATH"
PATH="$SYSTEM_TOOL_PATH:$PATH" DEVELOPER_DIR="$DEVELOPER_DIR" \
  xcrun altool --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"

printf 'Upload finished\n'
printf 'Build output: %s\n' "$IPA_PATH"
