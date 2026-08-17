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

# The blocker is a regular file rather than a chmod'ed directory: CI runs the
# Bash 3.0 jobs as root inside a container, where every permission bit is
# writable, but no user can mkdir through a file.
function test_cobertura_uncreatable_path_fails_fast() {
  local dir ec=0 output
  dir="$(_cobertura_project)"
  echo "not a directory" >"$dir/blocker"

  # No sed pipe here: the assertion is on bashunit's own exit code.
  output="$(
    cd "$dir" || exit 1
    BASHUNIT_COVERAGE_PATHS="$dir" BASHUNIT_COVERAGE_REPORT="" \
      "$OLDPWD/bashunit" --no-parallel --coverage \
      --coverage-report-cobertura blocker/report.xml ./suite_test.sh 2>&1
  )" || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "BASHUNIT_COVERAGE_REPORT_COBERTURA" "$output"
  assert_contains "cannot be written" "$output"
}

function test_cobertura_appears_in_the_help() {
  assert_contains "--coverage-report-cobertura" "$(./bashunit test --help)"
}

# The report is XML, and every attribute it writes carries a path: filename=,
# class name=, package name= and the <source> body. A path holding `&`, `<` or
# `>` went in raw, so the document did not parse -- and GitLab, Azure and
# Jenkins are exactly the consumers that then show nothing. The HTML report was
# given this treatment in #1254; this writer was missed.
function test_cobertura_escapes_xml_metacharacters_in_a_path() {
  local dir
  dir="$(cd "$(bashunit::temp_dir cobertura_amp)" && pwd)"
  (
    cd "$dir" || exit 1
    {
      echo '#!/usr/bin/env bash'
      echo 'function covered() { COVERED_OUT="covered"; }'
    } >'a&b.sh'
    {
      echo "source \"$dir/a&b.sh\""
      echo 'function test_covered() { covered; assert_not_empty "$COVERED_OUT"; }'
    } >suite_test.sh
  ) >/dev/null 2>&1

  (
    cd "$dir" || exit 1
    BASHUNIT_COVERAGE_PATHS="$dir" BASHUNIT_COVERAGE_REPORT="" \
      "$OLDPWD/bashunit" --no-parallel --coverage \
      --coverage-report-cobertura "$dir/cob.xml" ./suite_test.sh
  ) >/dev/null 2>&1 || true

  assert_file_exists "$dir/cob.xml"
  # The raw ampersand must be an entity, and the document must parse.
  assert_not_contains 'a&b.sh"' "$(cat "$dir/cob.xml")"
  assert_contains 'a&amp;b.sh' "$(cat "$dir/cob.xml")"
}
