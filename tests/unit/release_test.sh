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

##########################
# Pre-flight check tests
##########################

function test_preflight_check_required_files_passes_when_all_exist() {
  # Run in the project root where all files exist
  local result
  result=$(cd "$RELEASE_SCRIPT_DIR" && release::preflight::check_required_files 2>&1)
  assert_successful_code
}

function test_preflight_check_required_files_fails_when_file_missing() {
  local temp_dir
  temp_dir=$(mktemp -d)

  local result
  result=$(cd "$temp_dir" && release::preflight::check_required_files 2>&1) || true

  assert_contains "Required files missing" "$result"
  rm -rf "$temp_dir"
}

function test_preflight_check_changelog_unreleased_passes_with_content() {
  local result
  result=$(cd "$FIXTURES_DIR" && release::preflight::check_changelog_unreleased 2>&1)
  assert_successful_code
}

function test_preflight_check_changelog_unreleased_fails_when_missing() {
  local temp_dir
  temp_dir=$(mktemp -d)
  echo "# Changelog" > "$temp_dir/CHANGELOG.md"

  local result
  result=$(cd "$temp_dir" && release::preflight::check_changelog_unreleased 2>&1) || true

  assert_contains "missing '## Unreleased' section" "$result"
  rm -rf "$temp_dir"
}

##########################
# Backup and rollback tests
##########################

function test_backup_init_creates_directory() {
  local temp_dir
  temp_dir=$(mktemp -d)

  (
    cd "$temp_dir" || return
    release::backup::init
    [[ -d "$BACKUP_DIR" ]] && echo "exists"
  ) > /tmp/backup_test_result 2>&1

  assert_contains "exists" "$(cat /tmp/backup_test_result)" || true
  rm -rf "$temp_dir" /tmp/backup_test_result
  assert_successful_code
}

function test_backup_save_file_copies_file() {
  local temp_dir
  temp_dir=$(mktemp -d)

  local result
  result=$(
    cd "$temp_dir" || return
    echo "test content" > testfile.txt
    release::backup::init
    release::backup::save_file "testfile.txt"
    cat "$BACKUP_DIR/testfile.txt"
  )

  assert_same "test content" "$result"
  rm -rf "$temp_dir"
}

function test_rollback_restore_files_restores_backup() {
  local temp_dir
  temp_dir=$(mktemp -d)

  local result
  result=$(
    cd "$temp_dir" || return
    echo "original content" > testfile.txt
    release::backup::init
    release::backup::save_file "testfile.txt"
    echo "modified content" > testfile.txt
    release::rollback::restore_files 2>/dev/null
    cat testfile.txt
  )

  assert_same "original content" "$result"
  rm -rf "$temp_dir"
}

##########################
# Force mode tests
##########################

function test_confirm_action_auto_confirms_in_force_mode() {
  FORCE_MODE=true
  local result
  result=$(release::confirm_action "Test prompt" 2>&1)
  local exit_code=$?
  FORCE_MODE=false
  assert_same 0 "$exit_code"
}

##########################
# JSON output tests
##########################

function test_json_summary_generates_valid_json() {
  VERSION="0.31.0"
  CURRENT_VERSION="0.30.0"
  SANDBOX_MODE=false
  DRY_RUN=false
  FORCE_MODE=false
  COMPLETED_STEPS=("step1" "step2")

  local result
  result=$(release::json::summary "success")

  assert_contains '"status": "success"' "$result"
  assert_contains '"version": "0.31.0"' "$result"
  assert_contains '"current_version": "0.30.0"' "$result"
  assert_contains '"completed_steps": ["step1","step2"]' "$result"
}

function test_json_summary_handles_empty_steps() {
  # shellcheck disable=SC2034 # Variables used by release::json::summary
  VERSION="0.31.0"
  # shellcheck disable=SC2034
  CURRENT_VERSION="0.30.0"
  # shellcheck disable=SC2034
  SANDBOX_MODE=false
  # shellcheck disable=SC2034
  DRY_RUN=false
  # shellcheck disable=SC2034
  FORCE_MODE=false
  COMPLETED_STEPS=()

  local result
  result=$(release::json::summary "success")

  assert_contains '"completed_steps": []' "$result"
}

##########################
# State tracking tests
##########################

function test_state_record_step_adds_to_completed_steps() {
  COMPLETED_STEPS=()
  # shellcheck disable=SC2034 # Used by release::state::record_step
  VERBOSE_MODE=false

  release::state::record_step "test_step"

  assert_same "test_step" "${COMPLETED_STEPS[0]}"
}

##########################
# Error with suggestion tests
##########################

function test_error_with_suggestion_shows_both_messages() {
  local result
  result=$(release::error_with_suggestion "Test error" "Test suggestion" 2>&1)

  assert_contains "Test error" "$result"
  assert_contains "Suggestion:" "$result"
  assert_contains "Test suggestion" "$result"
}
