#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SIM_ID="${SIM_ID:-98FACCED-3F83-4A94-8D7B-F8905AAF08D1}"
BUNDLE_ID="${BUNDLE_ID:-com.lexical.Lexical}"
SCHEME="${SCHEME:-Lexical}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/derived_data}"
APP_BUNDLE_DIR="/tmp/Lexical.app"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
ARTIFACT_DIR="${ARTIFACT_DIR:-$ROOT_DIR/build/e2e_artifacts/$RUN_ID}"
BUILD_LOG="$ARTIFACT_DIR/build.log"
REPORT_FILE="$ARTIFACT_DIR/report.txt"

mkdir -p "$ARTIFACT_DIR"

log() {
  echo "[E2E] $*" | tee -a "$REPORT_FILE"
}

fail() {
  echo "[E2E][FAIL] $*" | tee -a "$REPORT_FILE"
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [[ "$expected" != "$actual" ]]; then
    fail "$label (expected='$expected' actual='$actual')"
  fi
  log "[PASS] $label => $actual"
}

assert_empty() {
  local actual="$1"
  local label="$2"
  if [[ -n "$actual" ]]; then
    fail "$label (expected empty, actual='$actual')"
  fi
  log "[PASS] $label => empty"
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
  local binary="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Lexical"
  local resource_bundle="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Lexical_LexicalCore.bundle"
  local info_plist="$ROOT_DIR/Lexical/Info.plist"

  [[ -f "$binary" ]] || fail "Missing app binary at $binary"
  [[ -f "$info_plist" ]] || fail "Missing Info.plist at $info_plist"
  [[ -d "$resource_bundle" ]] || fail "Missing resource bundle at $resource_bundle"

  rm -rf "$APP_BUNDLE_DIR"
  mkdir -p "$APP_BUNDLE_DIR"
  cp "$binary" "$APP_BUNDLE_DIR/Lexical"
  cp "$info_plist" "$APP_BUNDLE_DIR/Info.plist"
  cp -R "$resource_bundle" "$APP_BUNDLE_DIR/Lexical_LexicalCore.bundle"
  echo "APPL????" > "$APP_BUNDLE_DIR/PkgInfo"
  codesign --force --sign - --timestamp=none "$APP_BUNDLE_DIR" >/dev/null
  log "[PASS] Packaged app bundle at $APP_BUNDLE_DIR"
}

install_fresh() {
  log "Installing fresh app state"
  xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$SIM_ID" "$APP_BUNDLE_DIR"
  log "[PASS] Fresh install complete"
}

launch_app() {
  local args=("$@")
  xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  if (( ${#args[@]} > 0 )); then
    xcrun simctl launch "$SIM_ID" "$BUNDLE_ID" --args "${args[@]}" >/dev/null
  else
    xcrun simctl launch "$SIM_ID" "$BUNDLE_ID" >/dev/null
  fi
}

terminate_app() {
  xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
}

screenshot() {
  local name="$1"
  local path="$ARTIFACT_DIR/${name}.png"
  xcrun simctl io "$SIM_ID" screenshot "$path" >/dev/null
  log "Screenshot: $path"
}

data_dir() {
  xcrun simctl get_app_container "$SIM_ID" "$BUNDLE_ID" data
}

db_path() {
  local d
  d="$(data_dir)"
  echo "$d/Documents/Lexical.sqlite"
}

prefs_plist_path() {
  local d
  d="$(data_dir)"
  echo "$d/Library/Preferences/${BUNDLE_ID}.plist"
}

sqlite_query() {
  local query="$1"
  sqlite3 "$(db_path)" "$query"
}

plist_read_key() {
  local key="$1"
  local plist
  plist="$(prefs_plist_path)"
  /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null || true
}

plist_set_bool() {
  local key="$1"
  local value="$2"
  local plist
  plist="$(prefs_plist_path)"
  /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist" >/dev/null 2>&1 || \
    /usr/libexec/PlistBuddy -c "Add :$key bool $value" "$plist" >/dev/null
}

plist_set_string() {
  local key="$1"
  local value="$2"
  local plist
  plist="$(prefs_plist_path)"
  /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist" >/dev/null 2>&1 || \
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist" >/dev/null
}

plist_delete_key() {
  local key="$1"
  local plist
  plist="$(prefs_plist_path)"
  /usr/libexec/PlistBuddy -c "Delete :$key" "$plist" >/dev/null 2>&1 || true
}

apple_epoch_now_sql() {
  echo "(strftime('%s','now') - strftime('%s','2001-01-01'))"
}

ensure_app_data_files() {
  local db
  local plist
  db="$(db_path)"
  plist="$(prefs_plist_path)"
  [[ -f "$db" ]] || fail "Expected DB at $db"
  [[ -f "$plist" ]] || fail "Expected preferences plist at $plist"
}

ensure_profile_and_ledger_exist() {
  local profile_count
  local ledger_count
  local now_expr
  now_expr="$(apple_epoch_now_sql)"

  profile_count="$(sqlite_query "SELECT COUNT(*) FROM ZUSERPROFILE;")"
  ledger_count="$(sqlite_query "SELECT COUNT(*) FROM ZUSAGELEDGER;")"

  if [[ "$profile_count" -lt 1 ]]; then
    local profile_pk
    profile_pk="$(sqlite_query "SELECT COALESCE(MAX(Z_PK),0)+1 FROM ZUSERPROFILE;")"
    sqlite_query "INSERT INTO ZUSERPROFILE (Z_PK,Z_ENT,Z_OPT,ZCYCLECOUNT,ZLEXICALRANK,ZCREATEDAT,ZEASYRATINGVELOCITY,ZENTITLEMENTUPDATEDAT,ZFSRSREQUESTRETENTION,ZSTATEUPDATEDAT,ZDISPLAYNAME,ZENTITLEMENTSOURCERAWVALUE,ZFSRSPARAMETERMODERAWVALUE,ZSUBSCRIPTIONTIERRAWVALUE,ZUSERID) VALUES ($profile_pk,8,1,0,2500,$now_expr,0,$now_expr,0.9,$now_expr,'Learner','local_cache','standard','free','local.default.user');"
    sqlite_query "UPDATE Z_PRIMARYKEY SET Z_MAX=(SELECT MAX(Z_PK) FROM ZUSERPROFILE) WHERE Z_NAME='UserProfile';"
    log "Bootstrapped missing UserProfile row"
  fi

  local user_id
  user_id="$(sqlite_query "SELECT ZUSERID FROM ZUSERPROFILE LIMIT 1;")"
  [[ -n "$user_id" ]] || fail "Unable to resolve user id for UsageLedger bootstrap"

  if [[ "$ledger_count" -lt 1 ]]; then
    local ledger_pk
    ledger_pk="$(sqlite_query "SELECT COALESCE(MAX(Z_PK),0)+1 FROM ZUSAGELEDGER;")"
    sqlite_query "INSERT INTO ZUSAGELEDGER (Z_PK,Z_ENT,Z_OPT,ZACTIVEWIDGETPROFILECOUNT,ZARTICLESGENERATEDINWINDOW,ZARTICLEWINDOWSTART,ZCREATEDAT,ZUPDATEDAT,ZUSERID) VALUES ($ledger_pk,7,1,0,0,$now_expr,$now_expr,$now_expr,'$user_id');"
    sqlite_query "UPDATE Z_PRIMARYKEY SET Z_MAX=(SELECT MAX(Z_PK) FROM ZUSAGELEDGER) WHERE Z_NAME='UsageLedger';"
    log "Bootstrapped missing UsageLedger row"
  fi
}

prepare_main_app_state() {
  plist_set_bool "lexical.onboarding.completed.v1" true
  plist_set_bool "lexical.onboarding.notification_prompted.v1" false
  launch_app
  sleep 3
  terminate_app
  ensure_app_data_files
  ensure_profile_and_ledger_exist
}

test_onboarding_gate() {
  log "Running test_onboarding_gate"
  install_fresh

  launch_app
  sleep 3
  screenshot "01_onboarding_first_launch"

  local onboarding_state
  onboarding_state="$(plist_read_key "lexical.onboarding.completed.v1")"
  if [[ "$onboarding_state" == "true" || "$onboarding_state" == "1" ]]; then
    fail "Onboarding should not be completed on fresh install"
  fi
  log "[PASS] Fresh install starts with onboarding incomplete"

  plist_set_bool "lexical.onboarding.completed.v1" true
  terminate_app
  launch_app
  sleep 3
  screenshot "02_main_after_onboarding_completed"

  onboarding_state="$(plist_read_key "lexical.onboarding.completed.v1")"
  assert_eq "true" "$onboarding_state" "Onboarding completion persisted"
  terminate_app
}

test_free_and_premium_gate_state() {
  log "Running test_free_and_premium_gate_state"
  prepare_main_app_state

  local user_id
  local now_expr
  now_expr="$(apple_epoch_now_sql)"
  user_id="$(sqlite_query "SELECT ZUSERID FROM ZUSERPROFILE LIMIT 1;")"
  [[ -n "$user_id" ]] || fail "Unable to resolve active user id"

  sqlite_query "UPDATE ZUSERPROFILE SET ZSUBSCRIPTIONTIERRAWVALUE='free', ZFSRSPARAMETERMODERAWVALUE='standard', ZENTITLEMENTEXPIRESAT=NULL WHERE ZUSERID='$user_id';"
  sqlite_query "UPDATE ZUSAGELEDGER SET ZARTICLESGENERATEDINWINDOW=1, ZARTICLEWINDOWSTART=$now_expr, ZUPDATEDAT=$now_expr WHERE ZUSERID='$user_id';"

  launch_app
  sleep 3
  screenshot "03_free_limit_state"
  terminate_app

  local free_tier
  local free_mode
  local free_count
  free_tier="$(sqlite_query "SELECT ZSUBSCRIPTIONTIERRAWVALUE FROM ZUSERPROFILE WHERE ZUSERID='$user_id' LIMIT 1;")"
  free_mode="$(sqlite_query "SELECT ZFSRSPARAMETERMODERAWVALUE FROM ZUSERPROFILE WHERE ZUSERID='$user_id' LIMIT 1;")"
  free_count="$(sqlite_query "SELECT ZARTICLESGENERATEDINWINDOW FROM ZUSAGELEDGER WHERE ZUSERID='$user_id' LIMIT 1;")"
  assert_eq "free" "$free_tier" "Free tier state set"
  assert_eq "standard" "$free_mode" "Free FSRS mode set"
  assert_eq "1" "$free_count" "Free weekly article usage set"

  sqlite_query "UPDATE ZUSERPROFILE SET ZSUBSCRIPTIONTIERRAWVALUE='premium', ZFSRSPARAMETERMODERAWVALUE='personalized', ZENTITLEMENTEXPIRESAT=NULL WHERE ZUSERID='$user_id';"
  sqlite_query "UPDATE ZUSAGELEDGER SET ZARTICLESGENERATEDINWINDOW=999, ZUPDATEDAT=$now_expr WHERE ZUSERID='$user_id';"

  launch_app
  sleep 3
  screenshot "04_premium_unlimited_state"
  terminate_app

  local premium_tier
  local premium_mode
  premium_tier="$(sqlite_query "SELECT ZSUBSCRIPTIONTIERRAWVALUE FROM ZUSERPROFILE WHERE ZUSERID='$user_id' LIMIT 1;")"
  premium_mode="$(sqlite_query "SELECT ZFSRSPARAMETERMODERAWVALUE FROM ZUSERPROFILE WHERE ZUSERID='$user_id' LIMIT 1;")"
  assert_eq "premium" "$premium_tier" "Premium tier state set"
  assert_eq "personalized" "$premium_mode" "Premium FSRS mode set"
}

test_pending_prompt_route_consumption() {
  log "Running test_pending_prompt_route_consumption"
  prepare_main_app_state

  plist_set_string "lexical.pending_prompt_lemma" "know"
  plist_set_string "lexical.pending_prompt_definition" "to perceive the truth or factuality of something"

  launch_app
  sleep 3
  screenshot "05_prompt_route_consumed"
  terminate_app

  local remaining_lemma
  local remaining_definition
  remaining_lemma="$(plist_read_key "lexical.pending_prompt_lemma")"
  remaining_definition="$(plist_read_key "lexical.pending_prompt_definition")"
  assert_empty "$remaining_lemma" "Pending prompt lemma consumed"
  assert_empty "$remaining_definition" "Pending prompt definition consumed"
}

test_regular_usage_day28_burst_perspective() {
  log "Running test_regular_usage_day28_burst_perspective"
  install_fresh

  launch_app --lexical-ui-tests --lexical-e2e-reset-state --lexical-e2e-complete-onboarding --lexical-e2e-scenario-regular-2words-day28-articles4
  sleep 4
  screenshot "06_regular_usage_day28_reading"
  terminate_app

  ensure_app_data_files

  local articles
  local states
  local events
  local acquired_approx
  local unique_days

  articles="$(sqlite_query "SELECT COUNT(*) FROM ZGENERATEDCONTENT;")"
  states="$(sqlite_query "SELECT COUNT(*) FROM ZUSERWORDSTATE;")"
  events="$(sqlite_query "SELECT COUNT(*) FROM ZREVIEWEVENT;")"
  acquired_approx="$(sqlite_query "SELECT COUNT(DISTINCT ZLEMMA) FROM ZREVIEWEVENT WHERE ZGRADE >= 3 AND lower(ZREVIEWSTATE) IN ('again','hard','good','easy');")"
  unique_days="$(sqlite_query "SELECT COUNT(DISTINCT date(datetime(ZREVIEWDATE + 978307200, 'unixepoch', 'localtime'))) FROM ZREVIEWEVENT WHERE lower(ZREVIEWSTATE) LIKE 'session_%' OR lower(ZREVIEWSTATE) IN ('again','hard','good','easy');")"

  assert_eq "4" "$articles" "Day-28 burst articles"
  assert_eq "56" "$states" "Two-word-per-day state rows over 28 days"
  assert_eq "56" "$acquired_approx" "Acquired-word estimate for scenario"
  assert_eq "28" "$unique_days" "Active review days in scenario"
  if [[ "$events" -lt 56 ]]; then
    fail "Expected at least 56 review events, found $events"
  fi
  log "[PASS] Review event volume looks realistic => $events"

  launch_app --lexical-ui-tests --lexical-e2e-complete-onboarding --lexical-e2e-scenario-regular-2words-day28-articles4 --lexical-debug-open-stats
  sleep 4
  screenshot "07_regular_usage_day28_stats"
  terminate_app
}

main() {
  log "Artifacts directory: $ARTIFACT_DIR"
  boot_simulator
  build_app
  package_app_bundle

  test_onboarding_gate
  test_free_and_premium_gate_state
  test_pending_prompt_route_consumption
  test_regular_usage_day28_burst_perspective

  log "E2E run completed successfully"
  log "Report: $REPORT_FILE"
}

main "$@"
