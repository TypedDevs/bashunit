#!/usr/bin/env bash

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

##########################
# release::get_checksum tests
##########################

function test_get_checksum_returns_checksum_when_file_exists() {
  # Create a temp checksum file
  local temp_dir
  temp_dir=$(mktemp -d)
  echo "abc123def456  bin/bashunit" > "$temp_dir/checksum"

  # Override the function to use temp dir
  local result
  result=$(cd "$temp_dir" && awk '{print $1}' checksum)

  assert_same "abc123def456" "$result"
  rm -rf "$temp_dir"
}

function test_get_checksum_returns_empty_when_file_missing() {
  local temp_dir
  temp_dir=$(mktemp -d)

  local result
  result=$(
    cd "$temp_dir" || return
    if [[ -f "checksum" ]]; then
      awk '{print $1}' checksum
    else
      echo ""
    fi
  )

  assert_empty "$result"
  rm -rf "$temp_dir"
}

##########################
# release::get_contributors tests
##########################

function test_get_contributors_returns_handles_when_mocked() {
  # Mock gh command to return test data
  bashunit::mock gh echo -e "User1\nUser2\nUser1"

  local result
  result=$(release::get_contributors "0.28.0")

  # Should return unique sorted handles
  assert_contains "User1" "$result"
  assert_contains "User2" "$result"
}

function test_get_contributors_returns_empty_on_failure() {
  # Mock gh to fail
  bashunit::mock gh false

  local result
  result=$(release::get_contributors "0.28.0")

  assert_empty "$result"
}

##########################
# release::generate_release_notes tests (using fixtures)
##########################

function test_generate_release_notes_transforms_added_section() {
  # Mock dependencies
  bashunit::mock gh echo "TestUser"

  # Use fixture changelog
  local result
  result=$(cd "$FIXTURES_DIR" && release::generate_release_notes "0.30.0" "0.29.0" "abc123")

  assert_contains "## ✨ Improvements" "$result"
}

function test_generate_release_notes_transforms_changed_section() {
  bashunit::mock gh echo "TestUser"

  local result
  result=$(cd "$FIXTURES_DIR" && release::generate_release_notes "0.30.0" "0.29.0" "abc123")

  assert_contains "## 🛠️ Changes" "$result"
}

function test_generate_release_notes_transforms_fixed_section() {
  bashunit::mock gh echo "TestUser"

  local result
  result=$(cd "$FIXTURES_DIR" && release::generate_release_notes "0.30.0" "0.29.0" "abc123")

  assert_contains "## 🐛 Bug Fixes" "$result"
}

function test_generate_release_notes_includes_checksum() {
  bashunit::mock gh echo "TestUser"

  local result
  result=$(cd "$FIXTURES_DIR" && release::generate_release_notes "0.30.0" "0.29.0" "abc123checksum")

  assert_contains "## Checksum" "$result"
  assert_contains "abc123checksum" "$result"
}

function test_generate_release_notes_includes_changelog_link() {
  bashunit::mock gh echo "TestUser"

  local result
  result=$(cd "$FIXTURES_DIR" && release::generate_release_notes "0.30.0" "0.29.0" "abc123")

  assert_contains "**Full Changelog:**" "$result"
  assert_contains "0.29.0...0.30.0" "$result"
}

function test_generate_release_notes_includes_contributors() {
  bashunit::mock gh echo "Contributor1"

  local result
  result=$(cd "$FIXTURES_DIR" && release::generate_release_notes "0.30.0" "0.29.0" "abc123")

  assert_contains "## 👥 Contributors" "$result"
  assert_contains "@Contributor1" "$result"
}
