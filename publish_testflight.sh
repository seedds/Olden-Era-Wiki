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
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
TEAM_ID="${TEAM_ID:-9LK4YZ82JR}"
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
	<string>upload</string>
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

# flutter build ipa archives, signs, and (with destination=upload in the
# export options) uploads to App Store Connect via xcodebuild -exportArchive.
# Force Apple's rsync during IPA packaging. Homebrew rsync breaks exportArchive.
PATH="$SYSTEM_TOOL_PATH:$PATH" DEVELOPER_DIR="$DEVELOPER_DIR" flutter build ipa \
  --release \
  --build-name "$APP_VERSION" \
  --build-number "$BUILD_NUMBER" \
  --export-options-plist "$EXPORT_OPTIONS_PLIST"

printf 'Upload finished\n'
printf 'Build output: %s\n' "$SCRIPT_DIR/build/ios/ipa"
