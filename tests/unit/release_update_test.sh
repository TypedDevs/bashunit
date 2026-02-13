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
# Update function tests
##########################

function test_update_file_pattern_modifies_file() {
  local temp_dir
  temp_dir=$(mktemp -d)

  echo 'VERSION="1.0.0"' >"$temp_dir/test.txt"

  DRY_RUN=false
  (
    cd "$temp_dir" || return
    release::update_file_pattern "test.txt" 'VERSION="[^"]*"' 'VERSION="2.0.0"' "version" 2>/dev/null
  )

  local result
  result=$(cat "$temp_dir/test.txt")
  assert_contains 'VERSION="2.0.0"' "$result"

  rm -rf "$temp_dir"
}

function test_update_file_pattern_logs_dry_run() {
  local temp_dir
  temp_dir=$(mktemp -d)

  echo 'VERSION="1.0.0"' >"$temp_dir/test.txt"

  DRY_RUN=true
  local output
  output=$(
    cd "$temp_dir" || return
    release::update_file_pattern "test.txt" 'VERSION="[^"]*"' 'VERSION="2.0.0"' "version" 2>&1
  )
  DRY_RUN=false

  # File should NOT be modified
  local result
  result=$(cat "$temp_dir/test.txt")
  assert_contains 'VERSION="1.0.0"' "$result"
  assert_contains "DRY-RUN" "$output"

  rm -rf "$temp_dir"
}

function test_update_bashunit_version_changes_version_string() {
  local temp_dir
  temp_dir=$(mktemp -d)

  cp "$FIXTURES_DIR/mock_bashunit" "$temp_dir/bashunit"

  DRY_RUN=false
  (
    cd "$temp_dir" || return
    release::update_bashunit_version "0.31.0" 2>/dev/null
  )

  local result
  result=$(cat "$temp_dir/bashunit")
  assert_contains 'BASHUNIT_VERSION="0.31.0"' "$result"

  rm -rf "$temp_dir"
}

function test_update_install_version_changes_version_string() {
  local temp_dir
  temp_dir=$(mktemp -d)

  cp "$FIXTURES_DIR/mock_install.sh" "$temp_dir/install.sh"

  DRY_RUN=false
  (
    cd "$temp_dir" || return
    release::update_install_version "0.31.0" 2>/dev/null
  )

  local result
  result=$(cat "$temp_dir/install.sh")
  assert_contains 'LATEST_BASHUNIT_VERSION="0.31.0"' "$result"

  rm -rf "$temp_dir"
}

function test_update_package_json_version_changes_version_string() {
  local temp_dir
  temp_dir=$(mktemp -d)

  cp "$FIXTURES_DIR/mock_package.json" "$temp_dir/package.json"

  DRY_RUN=false
  (
    cd "$temp_dir" || return
    release::update_package_json_version "0.31.0" 2>/dev/null
  )

  local result
  result=$(cat "$temp_dir/package.json")
  assert_contains '"version": "0.31.0"' "$result"

  rm -rf "$temp_dir"
}

function test_update_changelog_adds_new_unreleased_section() {
  local temp_dir
  temp_dir=$(mktemp -d)

  cp "$FIXTURES_DIR/CHANGELOG.md" "$temp_dir/CHANGELOG.md"

  DRY_RUN=false
  GITHUB_REPO_URL="https://github.com/TypedDevs/bashunit"
  (
    cd "$temp_dir" || return
    release::update_changelog "0.31.0" "0.30.0" 2>/dev/null
  )

  local result
  result=$(cat "$temp_dir/CHANGELOG.md")
  # Should have a new Unreleased section at the top
  assert_contains "## Unreleased" "$result"
  # Should have the new version header
  assert_contains "[0.31.0]" "$result"

  rm -rf "$temp_dir"
}

function test_update_changelog_dry_run_does_not_modify() {
  local temp_dir
  temp_dir=$(mktemp -d)

  cp "$FIXTURES_DIR/CHANGELOG.md" "$temp_dir/CHANGELOG.md"
  local original
  original=$(cat "$temp_dir/CHANGELOG.md")

  DRY_RUN=true
  GITHUB_REPO_URL="https://github.com/TypedDevs/bashunit"
  (
    cd "$temp_dir" || return
    release::update_changelog "0.31.0" "0.30.0" 2>/dev/null
  )
  DRY_RUN=false

  local result
  result=$(cat "$temp_dir/CHANGELOG.md")
  assert_equals "$original" "$result"

  rm -rf "$temp_dir"
}

function test_update_checksum_updates_package_json() {
  local temp_dir
  temp_dir=$(mktemp -d)

  cp "$FIXTURES_DIR/mock_package.json" "$temp_dir/package.json"
  mkdir -p "$temp_dir/bin"
  echo "newchecksum123  bin/bashunit" >"$temp_dir/bin/checksum"

  DRY_RUN=false
  (
    cd "$temp_dir" || return
    release::update_checksum 2>/dev/null
  )

  local result
  result=$(cat "$temp_dir/package.json")
  assert_contains '"checksum": "newchecksum123"' "$result"

  rm -rf "$temp_dir"
}

##########################
# Dry-run mode tests
##########################

function test_dry_run_does_not_modify_any_files() {
  local temp_dir
  temp_dir=$(mktemp -d)

  # Copy all fixture files
  cp "$FIXTURES_DIR/mock_bashunit" "$temp_dir/bashunit"
  cp "$FIXTURES_DIR/mock_install.sh" "$temp_dir/install.sh"
  cp "$FIXTURES_DIR/mock_package.json" "$temp_dir/package.json"
  cp "$FIXTURES_DIR/CHANGELOG.md" "$temp_dir/CHANGELOG.md"

  # Save originals
  local orig_bashunit orig_install orig_package orig_changelog
  orig_bashunit=$(cat "$temp_dir/bashunit")
  orig_install=$(cat "$temp_dir/install.sh")
  orig_package=$(cat "$temp_dir/package.json")
  orig_changelog=$(cat "$temp_dir/CHANGELOG.md")

  DRY_RUN=true
  # shellcheck disable=SC2034 # Used by release:: functions
  GITHUB_REPO_URL="https://github.com/TypedDevs/bashunit"
  (
    cd "$temp_dir" || return
    release::update_bashunit_version "0.31.0" 2>/dev/null
    release::update_install_version "0.31.0" 2>/dev/null
    release::update_package_json_version "0.31.0" 2>/dev/null
    release::update_changelog "0.31.0" "0.30.0" 2>/dev/null
  )
  DRY_RUN=false

  # All files should be unchanged
  assert_equals "$orig_bashunit" "$(cat "$temp_dir/bashunit")"
  assert_equals "$orig_install" "$(cat "$temp_dir/install.sh")"
  assert_equals "$orig_package" "$(cat "$temp_dir/package.json")"
  assert_equals "$orig_changelog" "$(cat "$temp_dir/CHANGELOG.md")"

  rm -rf "$temp_dir"
}

function test_dry_run_logs_what_would_happen() {
  local temp_dir
  temp_dir=$(mktemp -d)

  cp "$FIXTURES_DIR/mock_bashunit" "$temp_dir/bashunit"

  DRY_RUN=true
  local output
  output=$(
    cd "$temp_dir" || return
    release::update_bashunit_version "0.31.0" 2>&1
  )
  DRY_RUN=false

  assert_contains "DRY-RUN" "$output"
  assert_contains "Would update" "$output"

  rm -rf "$temp_dir"
}
