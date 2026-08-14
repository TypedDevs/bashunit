#!/usr/bin/env bash
set -euo pipefail

# Report writers collect rows via bashunit::reports::add_test, which runs inside
# the per-test worker under --parallel. The arrays died with the worker and
# nothing rebuilt them, so every report came out with zero tests while the run
# itself was green -- and a junit file reporting no tests reads as a passing
# empty run in most CI systems.
FIXTURE=tests/acceptance/fixtures/parallel_reports/mixed.sh

function report_counts() { # $1 = extra flags -> "junit_total tap_plan json_total"
  local dir junit tap json
  dir=$(bashunit::temp_dir)
  junit="$dir/r.xml"; tap="$dir/r.tap"; json="$dir/r.json"

  # shellcheck disable=SC2086
  NO_COLOR=1 ./bashunit --skip-env-file $1 \
    --report-junit "$junit" --report-tap "$tap" --report-json "$json" \
    "$FIXTURE" >/dev/null 2>&1 || true

  printf '%s %s %s' \
    "$("$GREP" -o 'tests="[0-9]*"' "$junit" | head -1)" \
    "$("$GREP" -m1 -o '^1\.\.[0-9]*' "$tap")" \
    "$("$GREP" -o '"total": *[0-9]*' "$json" | head -1)"
}

function test_parallel_reports_match_sequential() {
  assert_same "$(report_counts '--no-parallel')" "$(report_counts '--parallel')"
}

function test_parallel_reports_are_not_empty() {
  local counts
  counts=$(report_counts '--parallel')

  assert_not_contains 'tests="0"' "$counts"
  assert_not_contains '1..0' "$counts"
}

# The HTML report's failure detail reads _BASHUNIT_REPORTS_TEST_FAILURES and
# _LINES at render time (#1251), which is the other side of the boundary this
# file exists for: those arrays are filled inside the per-test worker, so a
# section built from them is exactly the shape that came back empty in #1004.
function html_failure_detail() { # $1 = extra flags -> "<h2> count, message count"
  local dir html
  dir=$(bashunit::temp_dir)
  html="$dir/r.html"

  # shellcheck disable=SC2086
  NO_COLOR=1 ./bashunit --skip-env-file $1 --report-html "$html" "$FIXTURE" >/dev/null 2>&1 || true

  printf '%s %s' \
    "$("$GREP" -c '<h2>Failures</h2>' "$html" || true)" \
    "$("$GREP" -c 'Expected' "$html" || true)"
}

function test_the_html_failure_section_survives_parallel() {
  assert_same "$(html_failure_detail '--no-parallel')" "$(html_failure_detail '--parallel')"
}

# The comparison above cannot stand alone: drop the section entirely and both
# modes report "0 0", so they still match and the test passes on a report that
# says nothing. Verified by mutation -- removing the section fails only this
# one. Same reason `test_parallel_reports_are_not_empty` sits beside the
# equality check above it.
function test_the_html_failure_section_is_not_empty_in_parallel() {
  local detail
  detail=$(html_failure_detail '--parallel')

  assert_not_same "0 0" "$detail"
}
