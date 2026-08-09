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
