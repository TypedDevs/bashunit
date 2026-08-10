#!/usr/bin/env bash
# shellcheck disable=SC2317

# Diff coverage: restrict the report to lines changed against a base ref
# (#1032). The question a PR actually asks is "are the lines I touched
# covered", which a whole-file percentage cannot answer.

function _diff_repo() {
  local repo
  repo="$(bashunit::temp_dir diff_cov_repo)"
  (
    cd "$repo" || exit 1
    git init -q
    git symbolic-ref HEAD refs/heads/main
    git config user.email "test@bashunit.dev"
    git config user.name "bashunit test"
    git config commit.gpgsign false
    printf 'echo a\necho b\necho c\n' >lib.sh
    git add .
    git commit -q -m "initial"
    git branch base
  ) >/dev/null 2>&1
  echo "$repo"
}

function test_changed_line_stats_counts_only_changed_executable_lines() {
  local repo
  repo="$(_diff_repo)"
  printf 'echo a\necho B\necho C\n' >"$repo/lib.sh"

  # Line 2 changed and was hit; line 3 changed and was not.
  _BASHUNIT_COVERAGE_HITS_BY_LINE=()
  _BASHUNIT_COVERAGE_HITS_BY_LINE[2]=1

  local result
  result=$(cd "$repo" && bashunit::coverage::changed_line_stats "base" "lib.sh")

  assert_same "2:1" "$result"
}

function test_changed_line_stats_is_zero_when_nothing_changed() {
  local repo
  repo="$(_diff_repo)"

  _BASHUNIT_COVERAGE_HITS_BY_LINE=()

  local result
  result=$(cd "$repo" && bashunit::coverage::changed_line_stats "base" "lib.sh")

  assert_same "0:0" "$result"
}

# A changed comment is not executable, so it must not drag the percentage down.
function test_changed_line_stats_ignores_non_executable_changed_lines() {
  local repo
  repo="$(_diff_repo)"
  printf 'echo a\n# a new comment\necho c\n' >"$repo/lib.sh"

  _BASHUNIT_COVERAGE_HITS_BY_LINE=()

  local result
  result=$(cd "$repo" && bashunit::coverage::changed_line_stats "base" "lib.sh")

  assert_same "0:0" "$result"
}

function test_changed_line_stats_counts_every_changed_executable_line_as_hit() {
  local repo
  repo="$(_diff_repo)"
  printf 'echo a\necho B\necho C\n' >"$repo/lib.sh"

  _BASHUNIT_COVERAGE_HITS_BY_LINE=()
  _BASHUNIT_COVERAGE_HITS_BY_LINE[2]=3
  _BASHUNIT_COVERAGE_HITS_BY_LINE[3]=1

  local result
  result=$(cd "$repo" && bashunit::coverage::changed_line_stats "base" "lib.sh")

  assert_same "2:2" "$result"
}

function test_diff_percentage_is_one_hundred_when_nothing_changed() {
  assert_same "100" "$(bashunit::coverage::diff_percentage 0 0)"
}

function test_diff_percentage_rounds_down() {
  assert_same "66" "$(bashunit::coverage::diff_percentage 3 2)"
}

function test_diff_base_defaults_to_the_changed_ref_helper() {
  local previous="${BASHUNIT_COVERAGE_DIFF:-}"
  BASHUNIT_COVERAGE_DIFF="my-base"

  local actual
  actual="$(bashunit::coverage::diff_base)"
  BASHUNIT_COVERAGE_DIFF="$previous"

  assert_same "my-base" "$actual"
}

function test_diff_is_disabled_by_default() {
  local previous="${BASHUNIT_COVERAGE_DIFF:-}"
  BASHUNIT_COVERAGE_DIFF=""

  local exit_code=0
  bashunit::coverage::is_diff_enabled || exit_code=$?
  BASHUNIT_COVERAGE_DIFF="$previous"

  assert_equals 1 "$exit_code"
}

function test_diff_is_enabled_when_a_base_is_set() {
  local previous="${BASHUNIT_COVERAGE_DIFF:-}"
  BASHUNIT_COVERAGE_DIFF="main"

  local exit_code=0
  bashunit::coverage::is_diff_enabled || exit_code=$?
  BASHUNIT_COVERAGE_DIFF="$previous"

  assert_equals 0 "$exit_code"
}
