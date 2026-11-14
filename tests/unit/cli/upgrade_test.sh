#!/usr/bin/env bash

# shellcheck disable=SC2329 # Test functions are invoked indirectly by bashunit

function set_up() {
  WORK_DIR="$(mktemp -d)"
  export BASHUNIT_INSTALL_DIR="$WORK_DIR"
}

function tear_down() {
  unset BASHUNIT_INSTALL_DIR
  rm -rf "$WORK_DIR"
}

function fake_get_latest_tag() {
  echo "9.9.9"
}

function fake_get_empty_tag() {
  echo ""
}

function fake_download_fail() {
  echo "curl: (6) Could not resolve host: github.com" >&2
  return 1
}

FAKE_BINARY='#!/usr/bin/env bash
echo fake'

function _fake_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s\n' "$FAKE_BINARY" | shasum -a 256 | awk '{print $1}'
  else
    printf '%s\n' "$FAKE_BINARY" | sha256sum | awk '{print $1}'
  fi
}

function fake_download_success() {
  local url="$1"
  local output="$2"
  case "$url" in
  */checksum) printf '%s  bashunit\n' "$(_fake_sha256)" >"$output" ;;
  *) printf '%s\n' "$FAKE_BINARY" >"$output" ;;
  esac
}

function fake_download_bad_checksum() {
  local url="$1"
  local output="$2"
  case "$url" in
  */checksum) printf '%s  bashunit\n' "0000000000000000000000000000000000000000000000000000000000000000" >"$output" ;;
  *) printf '%s\n' "$FAKE_BINARY" >"$output" ;;
  esac
}

function fake_download_no_checksum() {
  local url="$1"
  local output="$2"
  case "$url" in
  */checksum)
    echo "curl: (22) The requested URL returned error: 404" >&2
    return 22
    ;;
  *) printf '%s\n' "$FAKE_BINARY" >"$output" ;;
  esac
}

function fake_download_empty() {
  local _url="$1"
  local output="$2"
  : >"$output"
}

function fake_download_partial() {
  printf 'partial binary\n' >"$2"
  return 1
}

function provide_upgrade_replacement_results() {
  bashunit::data_set fake_download_fail 1 previous
  bashunit::data_set fake_download_partial 1 previous
  bashunit::data_set fake_download_empty 1 previous
  bashunit::data_set fake_download_success 0 fake
}

# @data_provider provide_upgrade_replacement_results
function test_upgrade_replaces_the_previous_binary_only_after_a_valid_download() {
  local downloader="$1" expected_status="$2" expected_output="$3"
  printf '#!/usr/bin/env bash\necho previous\n' >"$WORK_DIR/bashunit"
  chmod 755 "$WORK_DIR/bashunit"
  bashunit::mock bashunit::helper::get_latest_tag fake_get_latest_tag
  bashunit::mock bashunit::io::download_to "$downloader"
  local status=0 output

  output=$(
    umask 022
    bashunit::upgrade::upgrade 2>&1
  ) || status=$?

  assert_equals "$expected_status" "$status"
  assert_file_exists "$WORK_DIR/bashunit"
  assert_same "$expected_output" "$("$WORK_DIR/bashunit")"
  if [ "$expected_status" -eq 0 ]; then
    assert_not_empty "$(find "$WORK_DIR/bashunit" -perm 0755 -print)"
  fi
  if [ "$expected_status" -ne 0 ]; then
    assert_contains 'Failed to download bashunit' "$output"
  fi
  local leftover
  leftover=$(find "$WORK_DIR" -name 'bashunit.download.*' -print)
  assert_empty "$leftover"
}

function test_upgrade_rejects_a_directory_at_the_binary_path() {
  mkdir "$WORK_DIR/bashunit"
  bashunit::mock bashunit::helper::get_latest_tag fake_get_latest_tag
  bashunit::mock bashunit::io::download_to fake_download_success
  local status=0 output
  output=$(bashunit::upgrade::upgrade 2>&1) || status=$?

  assert_general_error "" "" "$status"
  assert_contains 'not a file' "$output"
  assert_empty "$(find "$WORK_DIR/bashunit" -type f -print)"
}

function fake_get_current_tag() {
  echo "$BASHUNIT_VERSION"
}

function test_upgrade_aborts_when_download_fails() {
  bashunit::mock bashunit::helper::get_latest_tag fake_get_latest_tag
  bashunit::mock bashunit::io::download_to fake_download_fail

  local output
  local exit_code=0
  output="$(bashunit::upgrade::upgrade 2>&1)" || exit_code=$?

  assert_contains "Failed to download bashunit 9.9.9 from" "$output"
  assert_contains "https://github.com/TypedDevs/bashunit/releases/download/9.9.9/bashunit" "$output"
  assert_not_contains "upgraded successfully" "$output"
  assert_equals "1" "$exit_code"
  assert_file_not_exists "$WORK_DIR/bashunit"
}

function test_upgrade_surfaces_underlying_download_error_message() {
  bashunit::mock bashunit::helper::get_latest_tag fake_get_latest_tag
  bashunit::mock bashunit::io::download_to fake_download_fail

  local output
  output="$(bashunit::upgrade::upgrade 2>&1)" || true

  assert_contains "Reason:" "$output"
  assert_contains "Could not resolve host" "$output"
}

function test_upgrade_aborts_when_downloaded_file_is_empty() {
  bashunit::mock bashunit::helper::get_latest_tag fake_get_latest_tag
  bashunit::mock bashunit::io::download_to fake_download_empty

  local output
  local exit_code=0
  output="$(bashunit::upgrade::upgrade 2>&1)" || exit_code=$?

  assert_contains "empty file" "$output"
  assert_not_contains "upgraded successfully" "$output"
  assert_equals "1" "$exit_code"
  assert_file_not_exists "$WORK_DIR/bashunit"
}

function test_upgrade_aborts_when_latest_tag_cannot_be_resolved() {
  bashunit::mock bashunit::helper::get_latest_tag fake_get_empty_tag

  local output
  local exit_code=0
  output="$(bashunit::upgrade::upgrade 2>&1)" || exit_code=$?

  assert_contains "Failed to resolve latest bashunit version" "$output"
  assert_equals "1" "$exit_code"
}

function test_upgrade_reports_success_when_download_succeeds() {
  bashunit::mock bashunit::helper::get_latest_tag fake_get_latest_tag
  bashunit::mock bashunit::io::download_to fake_download_success

  local output
  output="$(bashunit::upgrade::upgrade 2>&1)"

  assert_contains "Upgrading bashunit to latest version" "$output"
  assert_contains "upgraded successfully to latest version 9.9.9" "$output"
  assert_not_contains "Failed to download" "$output"
  assert_file_exists "$WORK_DIR/bashunit"
  assert_successful_code "$([ -x "$WORK_DIR/bashunit" ] && echo 0 || echo 1)"
}

function test_upgrade_skips_when_already_on_latest() {
  bashunit::mock bashunit::helper::get_latest_tag fake_get_current_tag

  local output
  output="$(bashunit::upgrade::upgrade 2>&1)"

  assert_contains "You are already on latest version" "$output"
  assert_not_contains "Failed to download" "$output"
  assert_not_contains "upgraded successfully" "$output"
}

function _install_previous_binary() {
  printf '#!/usr/bin/env bash\necho previous\n' >"$WORK_DIR/bashunit"
  chmod 755 "$WORK_DIR/bashunit"
}

function test_upgrade_keeps_the_previous_binary_when_the_checksum_does_not_match() {
  _install_previous_binary
  bashunit::mock bashunit::helper::get_latest_tag fake_get_latest_tag
  bashunit::mock bashunit::io::download_to fake_download_bad_checksum

  local status=0 output
  output="$(bashunit::upgrade::upgrade 2>&1)" || status=$?

  assert_same 1 "$status"
  assert_contains "checksum mismatch for bashunit 9.9.9" "$output"
  assert_not_contains "upgraded successfully" "$output"
  assert_same "previous" "$("$WORK_DIR/bashunit")"
  assert_empty "$(find "$WORK_DIR" -name 'bashunit.download.*' -print)"
}

function test_upgrade_reports_a_verified_checksum() {
  bashunit::mock bashunit::helper::get_latest_tag fake_get_latest_tag
  bashunit::mock bashunit::io::download_to fake_download_success

  local output
  output="$(bashunit::upgrade::upgrade 2>&1)"

  assert_contains "Checksum verified" "$output"
  assert_same "fake" "$("$WORK_DIR/bashunit")"
}

function test_upgrade_warns_and_continues_when_the_checksum_asset_is_missing() {
  _install_previous_binary
  bashunit::mock bashunit::helper::get_latest_tag fake_get_latest_tag
  bashunit::mock bashunit::io::download_to fake_download_no_checksum

  local status=0 output
  output="$(unset BASHUNIT_VERIFY_CHECKSUM; bashunit::upgrade::upgrade 2>&1)" || status=$?

  assert_same 0 "$status"
  assert_contains "Skipping checksum verification" "$output"
  assert_same "fake" "$("$WORK_DIR/bashunit")"
}

function test_upgrade_fails_on_a_missing_checksum_when_verification_is_required() {
  _install_previous_binary
  bashunit::mock bashunit::helper::get_latest_tag fake_get_latest_tag
  bashunit::mock bashunit::io::download_to fake_download_no_checksum

  local status=0 output
  output="$(BASHUNIT_VERIFY_CHECKSUM=true bashunit::upgrade::upgrade 2>&1)" || status=$?

  assert_same 1 "$status"
  assert_contains "could not download the checksum" "$output"
  assert_same "previous" "$("$WORK_DIR/bashunit")"
  assert_empty "$(find "$WORK_DIR" -name 'bashunit.download.*' -print)"
}

function test_upgrade_skips_the_checksum_when_verification_is_disabled() {
  _install_previous_binary
  bashunit::mock bashunit::helper::get_latest_tag fake_get_latest_tag
  bashunit::mock bashunit::io::download_to fake_download_bad_checksum

  local status=0 output
  output="$(BASHUNIT_VERIFY_CHECKSUM=false bashunit::upgrade::upgrade 2>&1)" || status=$?

  assert_same 0 "$status"
  assert_not_contains "Checksum verified" "$output"
  assert_same "fake" "$("$WORK_DIR/bashunit")"
}
