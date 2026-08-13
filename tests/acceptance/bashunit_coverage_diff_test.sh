#!/usr/bin/env bash
set -euo pipefail

# --coverage-diff restricts the coverage text report to lines changed against a
# base ref (#1032).

# Builds a repo containing a source file, a test that covers part of it, and a
# `base` branch on the initial commit.
function _diff_project() {
  local repo
  repo="$(cd "$(bashunit::temp_dir diff_project)" && pwd)"
  (
    cd "$repo" || exit 1
    git init -q
    git symbolic-ref HEAD refs/heads/main
    git config user.email "test@bashunit.dev"
    git config user.name "bashunit test"
    git config commit.gpgsign false
    {
      echo '#!/usr/bin/env bash'
      echo 'function covered() { COVERED_OUT="covered"; }'
      echo 'function uncovered() { UNCOVERED_OUT="uncovered"; }'
    } >lib.sh
    {
      echo "source \"$repo/lib.sh\""
      echo 'function test_covered() { covered; assert_not_empty "$COVERED_OUT"; }'
    } >suite_test.sh
    git add .
    git commit -q -m "initial"
    git branch base
  ) >/dev/null 2>&1
  echo "$repo"
}

function _run_diff_coverage() { # $1 repo, $2.. extra args
  local repo="$1"
  shift
  (
    cd "$repo" || exit 1
    BASHUNIT_COVERAGE_PATHS="$repo" \
      BASHUNIT_COVERAGE_REPORT="" \
      "$OLDPWD/bashunit" --no-parallel --coverage "$@" ./suite_test.sh 2>&1
  ) | sed 's/\x1B\[[0-9;]*m//g'
}

function test_diff_coverage_reports_only_changed_lines() {
  local repo
  repo="$(_diff_project)"
  # Touch only the covered function's body line.
  (cd "$repo" && sed 's/COVERED_OUT="covered"/COVERED_OUT="covered now"/' lib.sh >tmp && mv tmp lib.sh)

  local output
  output="$(_run_diff_coverage "$repo" --coverage-diff base)"

  assert_contains "Diff Coverage (vs base)" "$output"
  assert_contains "Total: 1/1 (100%)" "$output"
}

function test_diff_coverage_reports_an_uncovered_changed_line() {
  local repo
  repo="$(_diff_project)"
  (cd "$repo" && sed 's/UNCOVERED_OUT="uncovered"/UNCOVERED_OUT="uncovered now"/' lib.sh >tmp && mv tmp lib.sh)

  local output
  output="$(_run_diff_coverage "$repo" --coverage-diff base)"

  assert_contains "Total: 0/1 (0%)" "$output"
}

# A docs-only or comment-only change has nothing executable to answer for, so
# the diff percentage is 100 rather than 0 — otherwise it would fail a gate.
function test_diff_coverage_is_one_hundred_when_nothing_executable_changed() {
  local repo
  repo="$(_diff_project)"
  printf '\n# just a comment\n' >>"$repo/lib.sh"

  local output
  output="$(_run_diff_coverage "$repo" --coverage-diff base)"

  assert_contains "No changed executable lines." "$output"
  assert_contains "Total: 0/0 (100%)" "$output"
}

function test_without_the_flag_the_whole_file_report_is_unchanged() {
  local repo
  repo="$(_diff_project)"

  local output
  output="$(_run_diff_coverage "$repo")"

  assert_contains "Coverage Report" "$output"
  assert_not_contains "Diff Coverage" "$output"
}

# The gate must follow the report: a PR that fully covers its own change passes
# even when the file as a whole is poorly covered.
# Echoes the exit code; the reporting helper pipes through sed, which would
# otherwise report sed's status instead of bashunit's.
function _diff_coverage_code() { # $1 repo, $2.. extra args
  local repo="$1"
  shift
  local code=0
  (
    cd "$repo" || exit 1
    BASHUNIT_COVERAGE_PATHS="$repo" \
      BASHUNIT_COVERAGE_REPORT="" \
      "$OLDPWD/bashunit" --no-parallel --coverage "$@" ./suite_test.sh
  ) >/dev/null 2>&1 || code=$?
  echo "$code"
}

function test_the_threshold_gates_on_the_diff_percentage() {
  local repo
  repo="$(_diff_project)"
  (cd "$repo" && sed 's/COVERED_OUT="covered"/COVERED_OUT="covered now"/' lib.sh >tmp && mv tmp lib.sh)

  assert_equals 0 "$(_diff_coverage_code "$repo" --coverage-diff base --coverage-min 100)"
}

function test_the_threshold_still_fails_on_an_uncovered_change() {
  local repo
  repo="$(_diff_project)"
  (cd "$repo" && sed 's/UNCOVERED_OUT="uncovered"/UNCOVERED_OUT="uncovered now"/' lib.sh >tmp && mv tmp lib.sh)

  assert_equals 1 "$(_diff_coverage_code "$repo" --coverage-diff base --coverage-min 100)"
}

function test_an_unresolvable_base_ref_fails_loudly() {
  local repo
  repo="$(_diff_project)"

  local output
  output="$(_run_diff_coverage "$repo" --coverage-diff no-such-ref || true)"

  assert_contains "does not resolve to a commit" "$output"
}

function test_an_unresolvable_base_ref_exits_non_zero() {
  local repo
  repo="$(_diff_project)"

  assert_equals 1 "$(_diff_coverage_code "$repo" --coverage-diff no-such-ref)"
}

function test_running_outside_a_repository_fails_loudly() {
  local dir
  dir="$(cd "$(bashunit::temp_dir not_a_repo)" && pwd)"
  {
    echo '#!/usr/bin/env bash'
    echo 'function covered() { echo "covered"; }'
  } >"$dir/lib.sh"
  {
    echo "source \"$dir/lib.sh\""
    echo 'function test_covered() { assert_not_empty "$(covered)"; }'
  } >"$dir/suite_test.sh"

  # Captured before the cd: inside the subshell $PWD is already the temp dir.
  local root="$PWD"
  local output
  output="$( (cd "$dir" && "$root/bashunit" --no-parallel --coverage \
    --coverage-diff base ./suite_test.sh 2>&1) | sed 's/\x1B\[[0-9;]*m//g' || true)"

  assert_contains "needs a git repository" "$output"
}

# --- a changed file that no test executed (#1054) ---------------------------

# The gate exists to catch exactly this: a PR adding a fully untested file used
# to pass, because the report iterated the files that RAN, so the new file was
# skipped, the changed-line total stayed 0, and the empty-set-is-100% rule
# (right for a docs-only commit) applied.
function test_a_new_file_no_test_executed_is_reported_at_zero() {
  local repo
  repo="$(_diff_project)"
  {
    echo '#!/usr/bin/env bash'
    echo 'function never_called() {'
    echo '  echo "one"'
    echo '  echo "two"'
    echo '}'
  } >"$repo/brand_new.sh"

  local output
  output="$(_run_diff_coverage "$repo" --coverage-diff base)"

  assert_contains "brand_new.sh" "$output"
  assert_matches "brand_new.sh[[:space:]]+0/" "$output"
}

function test_the_gate_fails_for_a_new_untested_file() {
  local repo
  repo="$(_diff_project)"
  {
    echo '#!/usr/bin/env bash'
    echo 'function never_called() {'
    echo '  echo "one"'
    echo '}'
  } >"$repo/brand_new.sh"

  local ec=0
  (
    cd "$repo" || exit 1
    BASHUNIT_COVERAGE_PATHS="$repo" BASHUNIT_COVERAGE_REPORT="" \
      "$OLDPWD/bashunit" --no-parallel --coverage --coverage-diff base \
      --coverage-min 90 ./suite_test.sh >/dev/null 2>&1
  ) || ec=$?

  assert_equals "1" "$ec"
}

# #1032's behaviour, preserved: nothing changed anywhere is still 100% and
# still passes, which is what keeps a docs-only commit green.
function test_no_changed_executable_lines_still_passes_the_gate() {
  local repo
  repo="$(_diff_project)"
  printf 'docs only\n' >"$repo/README.md"

  local ec=0
  (
    cd "$repo" || exit 1
    BASHUNIT_COVERAGE_PATHS="$repo" BASHUNIT_COVERAGE_REPORT="" \
      "$OLDPWD/bashunit" --no-parallel --coverage --coverage-diff base \
      --coverage-min 90 ./suite_test.sh >/dev/null 2>&1
  ) || ec=$?

  assert_equals "0" "$ec"
}

# A changed file the coverage paths do not cover must not be counted, however
# untested it is.
function test_a_changed_file_outside_the_coverage_paths_is_not_counted() {
  local repo
  repo="$(_diff_project)"
  mkdir -p "$repo/outside"
  {
    echo '#!/usr/bin/env bash'
    echo 'function elsewhere() { echo "x"; }'
  } >"$repo/outside/other.sh"

  local output
  output="$(
    cd "$repo" || exit 1
    BASHUNIT_COVERAGE_PATHS="$repo/lib.sh" BASHUNIT_COVERAGE_REPORT="" \
      "$OLDPWD/bashunit" --no-parallel --coverage --coverage-diff base \
      ./suite_test.sh 2>&1 | sed 's/\x1B\[[0-9;]*m//g'
  )"

  assert_not_contains "other.sh" "$output"
}

function test_a_deleted_file_does_not_break_the_report() {
  local repo
  repo="$(_diff_project)"
  # `|| true`: under --strict a non-zero from this setup would end the test
  # before it asserts anything.
  (cd "$repo" && git rm -q lib.sh) >/dev/null 2>&1 || true

  # `|| true`: the suite sources the file this test just deleted, so the child
  # run exits non-zero, and under --strict (pipefail) that would end this test
  # at the assignment instead of at the assertion.
  local output
  output="$(_run_diff_coverage "$repo" --coverage-diff base || true)"

  assert_contains "Diff Coverage" "$output"
}
