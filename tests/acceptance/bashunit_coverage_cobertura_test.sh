#!/usr/bin/env bash
set -euo pipefail

# --coverage-report-cobertura writes Cobertura XML, the format GitLab, Azure
# and Jenkins render coverage from (#1017).

# Builds a project with a source file and a test covering part of it.
function _cobertura_project() {
  local dir
  dir="$(cd "$(bashunit::temp_dir cobertura_project)" && pwd)"
  (
    cd "$dir" || exit 1
    {
      echo '#!/usr/bin/env bash'
      echo 'function covered() { COVERED_OUT="covered"; }'
      echo 'function uncovered() { UNCOVERED_OUT="uncovered"; }'
    } >lib.sh
    {
      echo "source \"$dir/lib.sh\""
      echo 'function test_covered() { covered; assert_not_empty "$COVERED_OUT"; }'
    } >suite_test.sh
  ) >/dev/null 2>&1
  echo "$dir"
}

function _run_cobertura() { # $1 project dir, $2.. extra args
  local dir="$1"
  shift
  (
    cd "$dir" || exit 1
    BASHUNIT_COVERAGE_PATHS="$dir" \
      BASHUNIT_COVERAGE_REPORT="" \
      "$OLDPWD/bashunit" --no-parallel --coverage "$@" ./suite_test.sh 2>&1
  ) | sed 's/\x1B\[[0-9;]*m//g'
}

function test_cobertura_flag_writes_the_report() {
  local dir
  dir="$(_cobertura_project)"

  _run_cobertura "$dir" --coverage-report-cobertura report.xml >/dev/null

  assert_file_exists "$dir/report.xml"
  local content
  content="$(cat "$dir/report.xml")"
  assert_contains '<coverage line-rate=' "$content"
  assert_contains 'filename="lib.sh"' "$content"
}

function test_cobertura_flag_defaults_its_path() {
  local dir
  dir="$(_cobertura_project)"

  # A following flag (not a path) makes the optional value fall back to its
  # default, the same contract --coverage-report-html has.
  _run_cobertura "$dir" --coverage-report-cobertura --no-color >/dev/null

  assert_file_exists "$dir/coverage/cobertura.xml"
}

function test_cobertura_coexists_with_lcov_in_one_run() {
  local dir
  dir="$(_cobertura_project)"

  (
    cd "$dir" || exit 1
    BASHUNIT_COVERAGE_PATHS="$dir" \
      "$OLDPWD/bashunit" --no-parallel --coverage \
      --coverage-report lcov.info \
      --coverage-report-cobertura cobertura.xml ./suite_test.sh
  ) >/dev/null 2>&1 || true

  assert_file_exists "$dir/lcov.info"
  assert_file_exists "$dir/cobertura.xml"
  assert_contains 'SF:' "$(cat "$dir/lcov.info")"
  assert_contains '<coverage' "$(cat "$dir/cobertura.xml")"
}

function test_cobertura_unwritable_path_fails_fast() {
  local dir ec=0 output
  dir="$(_cobertura_project)"

  # No sed pipe here: the assertion is on bashunit's own exit code.
  output="$(
    cd "$dir" || exit 1
    BASHUNIT_COVERAGE_PATHS="$dir" BASHUNIT_COVERAGE_REPORT="" \
      "$OLDPWD/bashunit" --no-parallel --coverage \
      --coverage-report-cobertura /nonexistent-root-dir/report.xml ./suite_test.sh 2>&1
  )" || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "BASHUNIT_COVERAGE_REPORT_COBERTURA" "$output"
  assert_contains "cannot be written" "$output"
}

function test_cobertura_appears_in_the_help() {
  assert_contains "--coverage-report-cobertura" "$(./bashunit test --help)"
}
