#!/usr/bin/env bash

# release.sh requires Bash 3.1+ (uses += array syntax)
# Skip this entire test file on Bash 3.0
if [[ "${BASH_VERSINFO[0]}" -eq 3 ]] && [[ "${BASH_VERSINFO[1]}" -lt 1 ]]; then
  # shellcheck disable=SC2317
  return 0 2>/dev/null || exit 0
fi

RELEASE_SCRIPT_DIR=""

function set_up_before_script() {
  RELEASE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

  # Source release.sh to get access to functions
  # shellcheck source=/dev/null
  source "$RELEASE_SCRIPT_DIR/release.sh"
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
    echo "test" >file.txt
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
