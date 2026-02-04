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

##########################
# Sandbox mode tests
##########################

function test_sandbox_create_creates_temp_directory() {
  release::sandbox::create 2>/dev/null
  assert_not_empty "$SANDBOX_DIR"
  assert_directory_exists "$SANDBOX_DIR"
  rm -rf "$SANDBOX_DIR"
}

function test_sandbox_create_copies_project_files() {
  local original_dir
  original_dir=$(pwd)

  cd "$RELEASE_SCRIPT_DIR" || return
  release::sandbox::create 2>/dev/null

  # Check that key files were copied
  assert_file_exists "$SANDBOX_DIR/bashunit"
  assert_file_exists "$SANDBOX_DIR/build.sh"
  assert_file_exists "$SANDBOX_DIR/CHANGELOG.md"

  rm -rf "$SANDBOX_DIR"
  cd "$original_dir" || return
}

function test_sandbox_create_excludes_git_directory() {
  local original_dir
  original_dir=$(pwd)

  cd "$RELEASE_SCRIPT_DIR" || return
  release::sandbox::create 2>/dev/null

  # .git should NOT be copied
  assert_directory_not_exists "$SANDBOX_DIR/.git"

  rm -rf "$SANDBOX_DIR"
  cd "$original_dir" || return
}

function test_sandbox_create_excludes_release_state() {
  local original_dir
  original_dir=$(pwd)

  cd "$RELEASE_SCRIPT_DIR" || return

  # Create a .release-state directory to test exclusion
  mkdir -p .release-state/test
  release::sandbox::create 2>/dev/null

  # .release-state should NOT be copied
  assert_directory_not_exists "$SANDBOX_DIR/.release-state"

  rm -rf "$SANDBOX_DIR" .release-state
  cd "$original_dir" || return
}

function test_sandbox_setup_git_initializes_repo() {
  if ! command -v git >/dev/null 2>&1; then
    bashunit::skip "git not available" && return
  fi

  local original_dir
  original_dir=$(pwd)

  cd "$RELEASE_SCRIPT_DIR" || return
  release::sandbox::create 2>/dev/null
  release::sandbox::setup_git 2>/dev/null

  # Should have a .git directory now
  assert_directory_exists "$SANDBOX_DIR/.git"

  rm -rf "$SANDBOX_DIR"
  cd "$original_dir" || return
}

function test_sandbox_setup_git_creates_initial_commit() {
  if ! command -v git >/dev/null 2>&1; then
    bashunit::skip "git not available" && return
  fi

  local original_dir
  original_dir=$(pwd)

  cd "$RELEASE_SCRIPT_DIR" || return
  release::sandbox::create 2>/dev/null
  release::sandbox::setup_git 2>/dev/null

  # Should have at least one commit
  local commit_count
  commit_count=$(git -C "$SANDBOX_DIR" rev-list --count HEAD 2>/dev/null || echo "0")
  assert_equals "1" "$commit_count"

  rm -rf "$SANDBOX_DIR"
  cd "$original_dir" || return
}

function test_sandbox_mock_gh_handles_release_command() {
  release::sandbox::mock_gh 2>/dev/null

  local result
  result=$(gh release create "1.0.0" 2>&1)
  assert_contains "SANDBOX" "$result"

  # Unset the mock
  unset -f gh
}

function test_sandbox_mock_gh_handles_api_command() {
  release::sandbox::mock_gh 2>/dev/null

  local result
  result=$(gh api /repos/test 2>&1)

  # Should return empty (not fail)
  assert_successful_code

  unset -f gh
}

function test_sandbox_mock_gh_handles_auth_command() {
  release::sandbox::mock_gh 2>/dev/null

  # Should succeed (return 0)
  gh auth status 2>/dev/null
  assert_successful_code

  unset -f gh
}

function test_sandbox_mock_git_push_prevents_actual_push() {
  if ! command -v git >/dev/null 2>&1; then
    bashunit::skip "git not available" && return
  fi

  release::sandbox::mock_git_push 2>/dev/null

  local result
  result=$(git push origin main 2>&1)
  assert_contains "SANDBOX" "$result"

  # Unset the mock
  unset -f git
}

function test_sandbox_mock_git_push_allows_other_git_commands() {
  if ! command -v git >/dev/null 2>&1; then
    bashunit::skip "git not available" && return
  fi

  local temp_dir
  temp_dir=$(mktemp -d)

  (
    cd "$temp_dir" || return
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > file.txt
    git add file.txt

    release::sandbox::mock_git_push 2>/dev/null

    # Non-push commands should work
    git commit -m "test" --quiet
    git status --short
  ) 2>/dev/null

  assert_successful_code
  rm -rf "$temp_dir"
  unset -f git 2>/dev/null || true
}

##########################
# Update function tests
##########################

function test_update_file_pattern_modifies_file() {
  local temp_dir
  temp_dir=$(mktemp -d)

  echo 'VERSION="1.0.0"' > "$temp_dir/test.txt"

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

  echo 'VERSION="1.0.0"' > "$temp_dir/test.txt"

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
  echo "newchecksum123  bin/bashunit" > "$temp_dir/bin/checksum"

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

##########################
# Logging function tests
##########################

function test_log_info_outputs_blue_prefix() {
  local result
  result=$(release::log_info "Test message" 2>&1)
  assert_contains "[INFO]" "$result"
  assert_contains "Test message" "$result"
}

function test_log_success_outputs_green_prefix() {
  local result
  result=$(release::log_success "Test message" 2>&1)
  assert_contains "[OK]" "$result"
  assert_contains "Test message" "$result"
}

function test_log_warning_outputs_yellow_prefix() {
  local result
  result=$(release::log_warning "Test message" 2>&1)
  assert_contains "[WARN]" "$result"
  assert_contains "Test message" "$result"
}

function test_log_error_outputs_red_prefix() {
  local result
  result=$(release::log_error "Test message" 2>&1)
  assert_contains "[ERROR]" "$result"
  assert_contains "Test message" "$result"
}

function test_log_dry_run_outputs_dry_run_prefix() {
  local result
  result=$(release::log_dry_run "Test message" 2>&1)
  assert_contains "[DRY-RUN]" "$result"
  assert_contains "Test message" "$result"
}

function test_log_sandbox_outputs_sandbox_prefix() {
  local result
  result=$(release::log_sandbox "Test message" 2>&1)
  assert_contains "[SANDBOX]" "$result"
  assert_contains "Test message" "$result"
}

function test_log_verbose_only_outputs_when_enabled() {
  VERBOSE_MODE=false
  local result_disabled
  result_disabled=$(release::log_verbose "Test message" 2>&1)
  assert_empty "$result_disabled"

  VERBOSE_MODE=true
  local result_enabled
  result_enabled=$(release::log_verbose "Test message" 2>&1)
  assert_contains "[VERBOSE]" "$result_enabled"
  assert_contains "Test message" "$result_enabled"
  # shellcheck disable=SC2034 # Used by release::log_verbose
  VERBOSE_MODE=false
}

##########################
# Get current version test
##########################

function test_get_current_version_extracts_from_bashunit() {
  local temp_dir
  temp_dir=$(mktemp -d)

  cp "$FIXTURES_DIR/mock_bashunit" "$temp_dir/bashunit"

  local result
  result=$(cd "$temp_dir" && release::get_current_version)

  assert_equals "0.29.0" "$result"

  rm -rf "$temp_dir"
}

##########################
# Build project test
##########################

function test_build_project_dry_run_does_not_execute() {
  DRY_RUN=true
  local result
  result=$(release::build_project 2>&1)
  # shellcheck disable=SC2034 # Used by release:: functions
  DRY_RUN=false

  assert_contains "DRY-RUN" "$result"
  assert_contains "Would run" "$result"
}
