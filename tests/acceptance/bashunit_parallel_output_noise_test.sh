#!/usr/bin/env bash
set -euo pipefail

# Two artifacts that only a `--parallel` run produced, and only where nobody
# looks closely -- a piped run, which is every CI log:
#
#   * the per-script "no result files" notice was not newline-terminated, so an
#     empty run rendered as "No tests found  Tests:      0 total" where the
#     sequential run rendered just the totals line;
#   * the spinner was erased unconditionally, but it only *draws* on a terminal,
#     so a piped run carried a literal "\r  \r" for something never drawn.
#
# The erase conditions must keep matching the ones bashunit::runner::spinner
# checks before drawing; these tests are what notices when they drift.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
}

function set_up() {
  WORKDIR="$(bashunit::temp_dir)"
  printf '%s\n' '#!/usr/bin/env bash' 'function test_alpha() { assert_same 1 1; }' \
    >"$WORKDIR/t_test.sh"
}

function _run() { # $@ = flags
  (cd "$WORKDIR" && "$BASHUNIT_BIN" "$@" t_test.sh 2>&1) || true
}

# A command substitution is a pipe, so this is the CI shape: the spinner never
# drew and nothing should have been erased.
function test_a_piped_parallel_run_carries_no_carriage_return() {
  local output
  output="$(_run --parallel)"

  assert_not_contains "$(printf '\r')" "$output"
}

function test_a_piped_parallel_run_that_finds_nothing_carries_no_carriage_return() {
  local output
  output="$(_run --parallel --filter nomatch)"

  assert_not_contains "$(printf '\r')" "$output"
}

# The notice must occupy its own line rather than running into the totals.
function test_the_no_results_notice_does_not_run_into_the_totals_line() {
  local output
  output="$(_run --parallel --filter nomatch | strip_ansi)"

  assert_contains "No tests found" "$output"
  assert_not_contains "No tests found  Tests:" "$output"
}

# The totals line itself must read the same in both modes.
function test_the_totals_line_is_identical_in_both_modes() {
  local sequential parallel
  sequential="$(_run --no-parallel --filter nomatch | strip_ansi | "$GREP" '^Tests:')"
  parallel="$(_run --parallel --filter nomatch | strip_ansi | "$GREP" '^Tests:')"

  assert_same "$sequential" "$parallel"
}

# A normal parallel run must not have gained noise either.
function test_a_passing_parallel_run_reports_the_totals_cleanly() {
  local output
  output="$(_run --parallel | strip_ansi)"

  assert_contains "1 passed, 1 total" "$output"
  assert_not_contains "No tests found" "$output"
}

function _stop_on_failure_project() {
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function test_fails() { assert_same 1 2; }'
    printf '%s\n' 'function test_passes() { assert_same 1 1; }'
  } >"$WORKDIR/t_test.sh"
}

# "Stop on failure enabled..." is human output and was printed with no regard
# for the stream it landed in: under a machine --output format it preceded the
# document, so the JSON did not parse and the XML declaration was not first.
function test_stop_on_failure_keeps_json_output_parseable() {
  _stop_on_failure_project

  local output
  output="$(_run --parallel --stop-on-failure --output json)"

  assert_not_contains "Stop on failure" "$output"
  assert_same "{" "${output%%$'\n'*}"
}

function test_stop_on_failure_keeps_the_xml_declaration_first() {
  _stop_on_failure_project

  local output
  output="$(_run --parallel --stop-on-failure --output junit)"

  assert_not_contains "Stop on failure" "$output"
  assert_same '<?xml version="1.0" encoding="UTF-8"?>' "${output%%$'\n'*}"
}

# The human run must keep the notice -- and without the carriage return it used
# to carry, which snapshots strip and therefore never caught.
function test_stop_on_failure_still_tells_a_human_and_carries_no_carriage_return() {
  _stop_on_failure_project

  local output
  output="$(_run --parallel --stop-on-failure | strip_ansi)"

  assert_contains "Stop on failure enabled" "$output"
  assert_not_contains "$(printf '\r')" "$output"
}
