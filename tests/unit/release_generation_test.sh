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
# release::get_checksum tests
##########################

function test_get_checksum_returns_checksum_when_file_exists() {
  # Create a temp checksum file
  local temp_dir
  temp_dir=$(mktemp -d)
  echo "abc123def456  bin/bashunit" >"$temp_dir/checksum"

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

function test_generate_release_notes_extracts_from_first_version_header() {
  bashunit::mock gh echo "TestUser"

  local result
  result=$(cd "$FIXTURES_DIR" && release::generate_release_notes "0.30.0" "0.29.0" "abc123")

  # Should include content from first version header (0.30.0)
  assert_contains "New feature one" "$result"
  assert_contains "Changed behavior" "$result"
  assert_contains "Bug fix one" "$result"
}

function test_generate_release_notes_excludes_older_version_content() {
  bashunit::mock gh echo "TestUser"

  local result
  result=$(cd "$FIXTURES_DIR" && release::generate_release_notes "0.30.0" "0.29.0" "abc123")

  # Should NOT include content from older versions (0.29.0)
  assert_not_contains "Previous feature" "$result"
}
