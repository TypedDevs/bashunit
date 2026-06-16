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
# Backup and rollback tests
##########################

function test_backup_init_creates_directory() {
  local temp_dir
  temp_dir=$(mktemp -d)

  (
    cd "$temp_dir" || return
    release::backup::init
    [[ -d "$BACKUP_DIR" ]] && echo "exists"
  ) >/tmp/backup_test_result 2>&1

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
    echo "test content" >testfile.txt
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
    echo "original content" >testfile.txt
    release::backup::init
    release::backup::save_file "testfile.txt"
    echo "modified content" >testfile.txt
    release::rollback::restore_files 2>/dev/null
    cat testfile.txt
  )

  assert_same "original content" "$result"
  rm -rf "$temp_dir"
}

function test_backup_save_file_preserves_subdirectory_path() {
  local temp_dir
  temp_dir=$(mktemp -d)

  local result
  result=$(
    cd "$temp_dir" || return
    mkdir -p docs
    echo "docs content" >docs/package.json
    release::backup::init
    release::backup::save_file "docs/package.json"
    cat "$BACKUP_DIR/docs/package.json"
  )

  assert_same "docs content" "$result"
  rm -rf "$temp_dir"
}

function test_rollback_restore_files_restores_nested_paths() {
  local temp_dir
  temp_dir=$(mktemp -d)

  local result
  result=$(
    cd "$temp_dir" || return
    mkdir -p docs
    echo "original docs" >docs/package.json
    echo "original root" >root.txt
    release::backup::init
    release::backup::save_file "docs/package.json"
    release::backup::save_file "root.txt"
    echo "modified docs" >docs/package.json
    echo "modified root" >root.txt
    release::rollback::restore_files 2>/dev/null
    printf '%s|%s' "$(cat docs/package.json)" "$(cat root.txt)"
  )

  assert_same "original docs|original root" "$result"
  rm -rf "$temp_dir"
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
  echo "# Changelog" >"$temp_dir/CHANGELOG.md"

  local result
  result=$(cd "$temp_dir" && release::preflight::check_changelog_unreleased 2>&1) || true

  assert_contains "missing '## Unreleased' section" "$result"
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

##########################
# Major tag test
##########################

function test_major_tag_returns_v_prefixed_major_for_zero() {
  assert_same "v0" "$(release::major_tag "0.38.0")"
}

function test_major_tag_returns_v_prefixed_major_for_one() {
  assert_same "v1" "$(release::major_tag "1.2.3")"
}

##########################
# create_tags tests
##########################

# Builds a throwaway git repo with one commit and returns its path.
# tag.gpgsign is left false so the test needs no GPG key, while still
# exercising the annotated/-m behavior that keeps tagging gpgsign-safe.
function _create_tags_setup_repo() {
  local repo
  repo="$(mktemp -d)"
  (
    cd "$repo" || exit 1
    git init -q
    git config user.email "test@bashunit.dev"
    git config user.name "bashunit test"
    git config commit.gpgsign false
    git config tag.gpgsign false
    git commit -q --allow-empty -m "initial"
  )
  echo "$repo"
}

function test_create_tags_creates_an_annotated_version_tag() {
  local repo origin
  repo="$(_create_tags_setup_repo)"
  origin="$(pwd)"

  cd "$repo" || return 1
  release::create_tags "0.40.0" >/dev/null
  # An annotated tag is a tag object; a lightweight tag resolves to a commit.
  assert_same "tag" "$(git cat-file -t 0.40.0)"
  assert_contains "0.40.0" "$(git tag -l --format='%(contents)' 0.40.0)"

  cd "$origin" || return 1
  rm -rf "$repo"
}

function test_create_tags_moves_major_tag_to_release_commit() {
  local repo origin
  repo="$(_create_tags_setup_repo)"
  origin="$(pwd)"

  cd "$repo" || return 1
  release::create_tags "0.40.0" >/dev/null
  assert_same "tag" "$(git cat-file -t v0)"
  # v0 must point at the release commit, not the version tag object.
  assert_same "$(git rev-parse HEAD)" "$(git rev-parse 'v0^{commit}')"

  cd "$origin" || return 1
  rm -rf "$repo"
}

function test_create_tags_returns_major_tag_name() {
  local repo origin result
  repo="$(_create_tags_setup_repo)"
  origin="$(pwd)"

  cd "$repo" || return 1
  result="$(release::create_tags '0.40.0')"
  assert_same "v0" "$result"

  cd "$origin" || return 1
  rm -rf "$repo"
}
