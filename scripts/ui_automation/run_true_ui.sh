#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SIM_ID="${SIM_ID:-98FACCED-3F83-4A94-8D7B-F8905AAF08D1}"
BUNDLE_ID="${BUNDLE_ID:-com.lexical.Lexical}"
SCHEME="${SCHEME:-Lexical}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/derived_data}"
APP_BUNDLE_DIR="/tmp/Lexical.app"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
ARTIFACT_DIR="${ARTIFACT_DIR:-$ROOT_DIR/build/ui_automation_artifacts/$RUN_ID}"
BUILD_LOG="$ARTIFACT_DIR/build.log"
REPORT_FILE="$ARTIFACT_DIR/report.txt"

mkdir -p "$ARTIFACT_DIR"

log() {
  echo "[UI-AUTO] $*" | tee -a "$REPORT_FILE"
}

fail() {
  echo "[UI-AUTO][FAIL] $*" | tee -a "$REPORT_FILE"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

boot_simulator() {
  log "Booting simulator $SIM_ID"
  open -a Simulator >/dev/null 2>&1 || true
  xcrun simctl boot "$SIM_ID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$SIM_ID" -b
}

build_app() {
  log "Building app (scheme=$SCHEME)"
  (
    cd "$ROOT_DIR"
    xcodebuild \
      -scheme "$SCHEME" \
      -sdk iphonesimulator \
      -destination "platform=iOS Simulator,id=$SIM_ID" \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      build
  ) >"$BUILD_LOG" 2>&1 || {
    tail -n 120 "$BUILD_LOG"
    fail "Build failed. Full log: $BUILD_LOG"
  }
  log "[PASS] Build succeeded"
}

package_app_bundle() {
  local built_app="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Lexical.app"
  local legacy_binary="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Lexical"
  local legacy_resource_bundle="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Lexical_LexicalCore.bundle"
  local info_plist="$ROOT_DIR/Lexical/Info.plist"

  rm -rf "$APP_BUNDLE_DIR"

  if [[ -d "$built_app" ]]; then
    cp -R "$built_app" "$APP_BUNDLE_DIR"
    log "[PASS] Packaged app bundle from build output at $APP_BUNDLE_DIR"
    return 0
  fi

  [[ -f "$legacy_binary" ]] || fail "Missing app binary at $legacy_binary"
  [[ -f "$info_plist" ]] || fail "Missing Info.plist at $info_plist"
  [[ -d "$legacy_resource_bundle" ]] || fail "Missing resource bundle at $legacy_resource_bundle"

  mkdir -p "$APP_BUNDLE_DIR"
  cp "$legacy_binary" "$APP_BUNDLE_DIR/Lexical"
  cp "$info_plist" "$APP_BUNDLE_DIR/Info.plist"
  cp -R "$legacy_resource_bundle" "$APP_BUNDLE_DIR/Lexical_LexicalCore.bundle"
  echo "APPL????" > "$APP_BUNDLE_DIR/PkgInfo"
  codesign --force --sign - --timestamp=none "$APP_BUNDLE_DIR" >/dev/null
  log "[PASS] Packaged legacy app bundle at $APP_BUNDLE_DIR"
}

install_fresh() {
  log "Installing fresh app state"
  idb terminate --udid "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$SIM_ID" "$APP_BUNDLE_DIR" >/dev/null
  log "[PASS] Fresh install complete"
}

launch_app() {
  local args=("$@")
  idb terminate --udid "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  idb launch --udid "$SIM_ID" "$BUNDLE_ID" \
    --lexical-ui-tests \
    --lexical-e2e-no-bootstrap \
    "${args[@]}" >/dev/null
}

terminate_app() {
  idb terminate --udid "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
}

screenshot() {
  local name="$1"
  local path="$ARTIFACT_DIR/${name}.png"
  xcrun simctl io "$SIM_ID" screenshot "$path" >/dev/null
  log "Screenshot: $path"
}

ui_dump() {
  idb ui describe-all --udid "$SIM_ID" --json
}

id_exists() {
  local id="$1"
  ui_dump | jq -e --arg id "$id" 'any(.[]; (.AXUniqueId // "") == $id)' >/dev/null
}

wait_for_id() {
  local id="$1"
  local timeout="${2:-12}"
  local start
  start="$(date +%s)"
  while true; do
    if id_exists "$id"; then
      log "[PASS] Found accessibility id: $id"
      return 0
    fi
    if (( $(date +%s) - start >= timeout )); then
      fail "Timed out waiting for accessibility id: $id"
    fi
    sleep 1
  done
}

wait_for_label_contains() {
  local snippet="$1"
  local timeout="${2:-12}"
  local start
  start="$(date +%s)"
  while true; do
    if ui_dump | jq -e --arg snippet "$snippet" 'any(.[]; ((.AXLabel // "") | contains($snippet)))' >/dev/null; then
      log "[PASS] Found label containing: $snippet"
      return 0
    fi
    if (( $(date +%s) - start >= timeout )); then
      fail "Timed out waiting for label containing: $snippet"
    fi
    sleep 1
  done
}

label_for_id() {
  local id="$1"
  ui_dump | jq -r --arg id "$id" 'first(.[] | select((.AXUniqueId // "") == $id) | (.AXLabel // "")) // ""'
}

assert_id_absent() {
  local id="$1"
  if id_exists "$id"; then
    fail "Expected accessibility id to be absent: $id"
  fi
  log "[PASS] Accessibility id absent as expected: $id"
}

assert_label_for_id_contains() {
  local id="$1"
  local snippet="$2"
  local label
  label="$(label_for_id "$id")"
  [[ "$label" == *"$snippet"* ]] || fail "Expected '$id' label to contain '$snippet' but got '$label'"
  log "[PASS] $id label contains '$snippet'"
}

center_for_id() {
  local id="$1"
  ui_dump | jq -r --arg id "$id" '
    first(.[] | select((.AXUniqueId // "") == $id)) as $e
    | if $e == null then "" else "\((($e.frame.x + ($e.frame.width / 2))|floor)) \((($e.frame.y + ($e.frame.height / 2))|floor))" end
  '
}

tap_id() {
  local id="$1"
  local coords
  local x
  local y

  wait_for_id "$id" 12
  coords="$(center_for_id "$id")"
  [[ -n "$coords" ]] || fail "Unable to resolve coordinates for id: $id"
  x="${coords%% *}"
  y="${coords##* }"

  idb ui tap --udid "$SIM_ID" "$x" "$y" >/dev/null
  log "Tapped id=$id at ($x,$y)"
  sleep 1
}

test_onboarding_visible() {
  log "Running test_onboarding_visible"
  launch_app --lexical-e2e-reset-state --lexical-e2e-show-onboarding

  wait_for_id onboarding.title
  wait_for_id onboarding.welcomeHeadline
  wait_for_id onboarding.primaryButton
  assert_label_for_id_contains onboarding.primaryButton "Get Started"
  assert_id_absent onboarding.skipButton

  screenshot "01_onboarding_visible"
  terminate_app
}

test_onboarding_primary_progress() {
  log "Running test_onboarding_primary_progress"
  launch_app --lexical-e2e-reset-state --lexical-e2e-show-onboarding

  wait_for_id onboarding.primaryButton
  assert_label_for_id_contains onboarding.primaryButton "Get Started"
  tap_id onboarding.primaryButton
  wait_for_id onboarding.primaryButton
  assert_id_absent onboarding.welcomeHeadline

  wait_for_id onboarding.fsrsGoodButton
  tap_id onboarding.fsrsGoodButton

  tap_id onboarding.primaryButton
  wait_for_id onboarding.calibrationHeadline
  wait_for_id onboarding.primaryButton
  assert_label_for_id_contains onboarding.primaryButton "Continue"
  assert_id_absent onboarding.skipButton

  screenshot "02_onboarding_primary_progress"
  terminate_app
}

test_onboarding_premium_step_free_path() {
  log "Running test_onboarding_premium_step_free_path"
  launch_app --lexical-e2e-reset-state --lexical-e2e-onboarding-premium-step

  wait_for_id onboarding.premiumHeadline
  wait_for_id onboarding.continueFreeButton
  assert_label_for_id_contains onboarding.continueFreeButton "Continue with Free"
  screenshot "03_onboarding_premium_step"

  tap_id onboarding.continueFreeButton
  wait_for_id onboarding.completionHeadline
  wait_for_id onboarding.primaryButton
  assert_label_for_id_contains onboarding.primaryButton "Start Learning"
  screenshot "04_onboarding_completion_after_free_path"

  terminate_app
}

test_free_limit_state() {
  log "Running test_free_limit_state"
  launch_app --lexical-e2e-reset-state --lexical-e2e-complete-onboarding --lexical-e2e-free-limit

  wait_for_id reading.headerTitle
  wait_for_id reading.quotaLabel
  wait_for_id reading.upgradeButton
  assert_label_for_id_contains reading.quotaLabel "Free: 0/1"
  assert_id_absent reading.generateButton

  screenshot "05_free_limit_state"
  terminate_app
}

test_premium_state() {
  log "Running test_premium_state"
  launch_app --lexical-e2e-reset-state --lexical-e2e-complete-onboarding --lexical-e2e-premium

  wait_for_id reading.headerTitle
  wait_for_id reading.quotaLabel
  wait_for_id reading.generateButton
  assert_label_for_id_contains reading.quotaLabel "Premium: Unlimited"
  assert_id_absent reading.upgradeButton

  screenshot "06_premium_unlimited_state"
  terminate_app
}

test_explore_screen_and_sheet() {
  log "Running test_explore_screen_and_sheet"
  launch_app --lexical-e2e-reset-state --lexical-e2e-complete-onboarding --lexical-debug-open-explore

  wait_for_id explore.headerTitle
  wait_for_id explore.subtitle
  wait_for_id explore.node.root
  screenshot "07_explore_screen"

  tap_id explore.node.root
  wait_for_id wordinfo.title
  wait_for_id wordinfo.addToDeckButton
  screenshot "08_explore_word_sheet"

  terminate_app
}

test_prompt_route_open_and_close() {
  log "Running test_prompt_route_open_and_close"
  launch_app --lexical-e2e-reset-state --lexical-e2e-complete-onboarding --lexical-e2e-pending-prompt

  wait_for_id prompt.title
  wait_for_id prompt.closeButton
  screenshot "09_prompt_open"

  tap_id prompt.closeButton
  wait_for_id review.headerTitle
  screenshot "10_prompt_closed_to_review"

  terminate_app
}

main() {
  log "Artifacts directory: $ARTIFACT_DIR"
  require_cmd xcodebuild
  require_cmd xcrun
  require_cmd idb
  require_cmd jq

  boot_simulator
  build_app
  package_app_bundle
  install_fresh

  test_onboarding_visible
  test_onboarding_primary_progress
  test_onboarding_premium_step_free_path
  test_free_limit_state
  test_premium_state
  test_explore_screen_and_sheet
  test_prompt_route_open_and_close

  log "All true UI automation tests passed"
}

main "$@"
