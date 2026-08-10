#!/usr/bin/env bash
set -euo pipefail

# --changed selects test files from git, so every case runs against a throwaway
# repo in a temp dir rather than the bashunit checkout: the checkout's own diff
# would make these results depend on whatever the contributor is editing.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
}

# Two committed test files and a `base` branch on that first commit. A branch
# rather than a tag: a global tag.forceSignAnnotated or tag.annotate makes a
# bare `git tag` abort with "no tag message?". The default branch is set
# explicitly because init.defaultBranch varies across the git versions CI runs.
function _changed_repo() {
  local repo
  repo="$(bashunit::temp_dir changed_cli)"
  (
    cd "$repo" || exit 1
    git init -q
    git symbolic-ref HEAD refs/heads/main
    git config user.email "test@bashunit.dev"
    git config user.name "bashunit test"
    git config commit.gpgsign false
    printf '#!/usr/bin/env bash\nfunction test_alpha() { assert_same 1 1; }\n' >alpha_test.sh
    printf '#!/usr/bin/env bash\nfunction test_beta() { assert_same 2 2; }\n' >beta_test.sh
    git add .
    git commit -q -m "initial"
    git branch base
  ) >/dev/null 2>&1
  echo "$repo"
}

# Rewrites alpha_test.sh with a second test, so a change is visible both as a
# file path and as an extra selected test.
function _touch_alpha() {
  {
    printf '#!/usr/bin/env bash\n'
    printf 'function test_alpha() { assert_same 1 1; }\n'
    printf 'function test_gamma() { assert_same 3 3; }\n'
  } >"$1/alpha_test.sh"
}

function test_changed_lists_only_the_files_committed_since_the_ref() {
  local repo
  repo="$(_changed_repo)"
  _touch_alpha "$repo"
  (cd "$repo" && git commit -q -am "touch alpha") >/dev/null 2>&1

  local output
  output=$(cd "$repo" && "$BASHUNIT_BIN" --skip-env-file --list --changed base . 2>/dev/null)

  assert_same "./alpha_test.sh::test_alpha
./alpha_test.sh::test_gamma" "$output"
}

function test_changed_includes_an_uncommitted_modification() {
  local repo
  repo="$(_changed_repo)"
  _touch_alpha "$repo"

  local output
  output=$(cd "$repo" && "$BASHUNIT_BIN" --skip-env-file --list --changed base . 2>/dev/null)

  assert_contains "alpha_test.sh" "$output"
  assert_not_contains "beta_test.sh" "$output"
}

function test_changed_without_a_ref_still_sees_working_tree_edits() {
  local repo
  repo="$(_changed_repo)"
  _touch_alpha "$repo"

  local output
  output=$(cd "$repo" && "$BASHUNIT_BIN" --skip-env-file --list --changed . 2>/dev/null)

  assert_contains "alpha_test.sh" "$output"
  assert_not_contains "beta_test.sh" "$output"
}

function test_changed_excludes_a_deleted_test_file() {
  local repo
  repo="$(_changed_repo)"
  _touch_alpha "$repo"
  (
    cd "$repo" || exit 1
    git rm -q beta_test.sh
    git commit -q -am "drop beta, touch alpha"
  ) >/dev/null 2>&1

  local output
  output=$(cd "$repo" && "$BASHUNIT_BIN" --skip-env-file --list --changed base . 2>/dev/null)

  assert_contains "alpha_test.sh" "$output"
  assert_not_contains "beta_test.sh" "$output"
}

function test_changed_selects_only_the_new_path_of_a_rename() {
  local repo
  repo="$(_changed_repo)"
  (
    cd "$repo" || exit 1
    git mv beta_test.sh renamed_test.sh
    git commit -q -m "rename beta"
  ) >/dev/null 2>&1

  local output
  output=$(cd "$repo" && "$BASHUNIT_BIN" --skip-env-file --list --changed base . 2>/dev/null)

  assert_same "./renamed_test.sh::test_beta" "$output"
}

function test_changed_intersects_with_the_filter() {
  local repo
  repo="$(_changed_repo)"
  _touch_alpha "$repo"

  local output
  output=$(cd "$repo" && "$BASHUNIT_BIN" --skip-env-file --list --changed base --filter gamma . 2>/dev/null)

  assert_same "./alpha_test.sh::test_gamma" "$output"
}

function test_changed_runs_only_the_changed_file() {
  local repo
  repo="$(_changed_repo)"
  _touch_alpha "$repo"

  local output
  output=$(cd "$repo" && "$BASHUNIT_BIN" --skip-env-file --no-color --no-parallel --changed base . 2>&1)

  # The summary pads with spaces, hence the squeeze.
  assert_contains "Tests: 2 passed, 2 total" "$(printf '%s' "$output" | tr -s ' ')"
  assert_not_contains "Beta" "$output"
}

function test_changed_reports_no_tests_found_when_nothing_changed() {
  local repo
  repo="$(_changed_repo)"

  local ec=0
  local output
  output=$(cd "$repo" && "$BASHUNIT_BIN" --skip-env-file --no-parallel --changed base . 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "No tests found" "$output"
}

function test_changed_fails_outside_a_git_work_tree() {
  local outside
  outside="$(bashunit::temp_dir changed_outside)"
  printf '#!/usr/bin/env bash\nfunction test_alpha() { assert_same 1 1; }\n' >"$outside/alpha_test.sh"

  local ec=0
  local output
  output=$(cd "$outside" && "$BASHUNIT_BIN" --skip-env-file --list --changed . 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "git work tree" "$output"
}

function test_changed_fails_when_the_ref_does_not_resolve() {
  local repo
  repo="$(_changed_repo)"

  local ec=0
  local output
  output=$(cd "$repo" && "$BASHUNIT_BIN" --skip-env-file --list --changed no_such_ref . 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "no_such_ref" "$output"
}
