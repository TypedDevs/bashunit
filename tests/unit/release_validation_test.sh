#!/usr/bin/env bash

# release.sh requires Bash 3.1+ (uses += array syntax)
# Skip this entire test file on Bash 3.0
if [[ "${BASH_VERSINFO[0]}" -eq 3 ]] && [[ "${BASH_VERSINFO[1]}" -lt 1 ]]; then
  # shellcheck disable=SC2317
  return 0 2>/dev/null || exit 0
fi

RELEASE_SCRIPT_DIR=""
FIXTURES_DIR=""

function set_up_before_script() {
  RELEASE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  FIXTURES_DIR="$(dirname "${BASH_SOURCE[0]}")/fixtures/release"

  # Source release.sh to get access to functions
  # shellcheck source=/dev/null
  source "$RELEASE_SCRIPT_DIR/release.sh"
}

##########################
# release::validate_semver tests
##########################

function test_validate_semver_accepts_valid_version() {
  # Should not exit (no output means success)
  local result
  result=$(release::validate_semver "0.30.0" 2>&1) || true
  assert_empty "$result"
}

function test_validate_semver_accepts_major_version() {
  local result
  result=$(release::validate_semver "1.0.0" 2>&1) || true
  assert_empty "$result"
}

function test_validate_semver_accepts_large_numbers() {
  local result
  result=$(release::validate_semver "10.20.30" 2>&1) || true
  assert_empty "$result"
}

function test_validate_semver_rejects_two_part_version() {
  local result
  result=$(release::validate_semver "0.30" 2>&1) || true
  assert_contains "Invalid version format" "$result"
}

function test_validate_semver_rejects_v_prefix() {
  local result
  result=$(release::validate_semver "v0.30.0" 2>&1) || true
  assert_contains "Invalid version format" "$result"
}

function test_validate_semver_rejects_prerelease_suffix() {
  local result
  result=$(release::validate_semver "0.30.0-beta" 2>&1) || true
  assert_contains "Invalid version format" "$result"
}

function test_validate_semver_rejects_empty_string() {
  local result
  result=$(release::validate_semver "" 2>&1) || true
  assert_contains "Invalid version format" "$result"
}

function test_validate_semver_rejects_text() {
  local result
  result=$(release::validate_semver "latest" 2>&1) || true
  assert_contains "Invalid version format" "$result"
}

##########################
# release::version_gt tests
##########################

function test_version_gt_returns_true_when_patch_greater() {
  release::version_gt "0.29.1" "0.29.0"
  assert_successful_code
}

function test_version_gt_returns_true_when_minor_greater() {
  release::version_gt "0.30.0" "0.29.0"
  assert_successful_code
}

function test_version_gt_returns_true_when_major_greater() {
  release::version_gt "1.0.0" "0.99.99"
  assert_successful_code
}

function test_version_gt_returns_false_when_equal() {
  assert_unsuccessful_code "$(release::version_gt "0.29.0" "0.29.0")"
}

function test_version_gt_returns_false_when_less() {
  assert_unsuccessful_code "$(release::version_gt "0.28.0" "0.29.0")"
}

function test_version_gt_returns_false_when_patch_less() {
  assert_unsuccessful_code "$(release::version_gt "0.29.0" "0.29.1")"
}

function test_version_gt_handles_large_numbers() {
  release::version_gt "10.20.31" "10.20.30"
  assert_successful_code
}

# Data provider for version comparison
# @data_provider provider_release::version_gt_true
function test_version_gt_with_provider_returns_true() {
  local v1="$1"
  local v2="$2"
  release::version_gt "$v1" "$v2"
  assert_successful_code
}

function provider_release::version_gt_true() {
  bashunit::data_set "0.30.0" "0.29.0"
  bashunit::data_set "1.0.0" "0.99.99"
  bashunit::data_set "0.29.1" "0.29.0"
  bashunit::data_set "2.0.0" "1.99.99"
}

# @data_provider provider_release::version_gt_false
function test_version_gt_with_provider_returns_false() {
  local v1="$1"
  local v2="$2"
  assert_unsuccessful_code "$(release::version_gt "$v1" "$v2")"
}

function provider_release::version_gt_false() {
  bashunit::data_set "0.29.0" "0.29.0"
  bashunit::data_set "0.28.0" "0.29.0"
  bashunit::data_set "0.29.0" "0.30.0"
  bashunit::data_set "0.99.99" "1.0.0"
}
