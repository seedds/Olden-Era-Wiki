#!/usr/bin/env bash
#
# Fully automated screenshot capture for Olden Era Wiki.
#
# Boots an iOS simulator, runs the integration test, and saves screenshots
# to the screenshots/ directory at the project root.
#
# Usage:
#   ./scripts/take_screenshots.sh                     # uses default device
#   ./scripts/take_screenshots.sh "iPhone 17 Pro"     # pick a specific sim
#   ./scripts/take_screenshots.sh --skip-build         # skip flutter pub get
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DEVICE_NAME="iPhone 17 Pro"
SKIP_BUILD=false

# ── Parse arguments ──────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=true ;;
    *) DEVICE_NAME="$arg" ;;
  esac
done

# ── Locate the simulator ────────────────────────────────────────────────
echo "Looking for simulator: $DEVICE_NAME ..."

DEVICE_ID=$(
  xcrun simctl list devices available \
    | grep "$DEVICE_NAME" \
    | grep -oE '[A-F0-9a-f-]{36}' \
    | head -1
)

if [ -z "$DEVICE_ID" ]; then
  echo "Error: No available simulator found matching '$DEVICE_NAME'."
  echo "Available simulators:"
  xcrun simctl list devices available | grep -E "iPhone|iPad"
  exit 1
fi

echo "Using simulator: $DEVICE_NAME ($DEVICE_ID)"

# ── Boot the simulator if needed ─────────────────────────────────────────
DEVICE_STATE=$(xcrun simctl list devices | grep "$DEVICE_ID" | grep -o 'Booted' || true)
if [ "$DEVICE_STATE" != "Booted" ]; then
  echo "Booting simulator ..."
  xcrun simctl boot "$DEVICE_ID"
  # Give the simulator a moment to finish booting.
  sleep 5
fi

# Open Simulator.app so the window is visible (needed for screenshots).
open -a Simulator

# ── Ensure dependencies ──────────────────────────────────────────────────
cd "$PROJECT_DIR"

if [ "$SKIP_BUILD" = false ]; then
  echo "Running flutter pub get ..."
  flutter pub get
fi

# ── Ensure screenshots directory exists ──────────────────────────────────
mkdir -p "$PROJECT_DIR/screenshots"

# ── Run the integration test ─────────────────────────────────────────────
echo ""
echo "Running screenshot integration test ..."
echo ""

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d "$DEVICE_ID"

# ── Summary ──────────────────────────────────────────────────────────────
echo ""
echo "Screenshots saved to screenshots/:"
ls -1 "$PROJECT_DIR/screenshots/"*.png 2>/dev/null || echo "  (no screenshots found — the test may have failed)"
echo ""
echo "Done."
