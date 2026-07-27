#!/usr/bin/env bash

# Engine-equivalence oracle for ADR-009. The xtrace engine is only allowed to
# ship while it produces the same report as the DEBUG-trap engine, so this
# compares real end-to-end LCOV output from both engines over one fixture.

TRAP_LCOV=""
XTRACE_LCOV=""
PARALLEL_LCOV=""
FIXTURE_DIR=""

function set_up_before_script() {
  TRAP_LCOV="$(bashunit::temp_file "lcov-engine-trap")"
  XTRACE_LCOV="$(bashunit::temp_file "lcov-engine-xtrace")"
  PARALLEL_LCOV="$(bashunit::temp_file "lcov-engine-parallel")"
  FIXTURE_DIR="tests/acceptance/fixtures"
}

function _skip_without_xtrace_support() {
  if [ "${BASH_VERSINFO[0]}" -gt 4 ]; then
    return 1
  fi
  if [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -ge 1 ]; then
    return 1
  fi
  bashunit::skip "BASH_XTRACEFD requires Bash 4.1+"
  return 0
}

function _run_fixture_with_engine() {
  local engine="$1"
  local lcov_file="$2"
  local parallel_flag="${3:---no-parallel}"

  BASHUNIT_COVERAGE_ENGINE="$engine" ./bashunit \
    --coverage \
    --coverage-min 0 \
    --coverage-paths "$FIXTURE_DIR/coverage_engine_source.sh" \
    --coverage-exclude "vendor/*" \
    --coverage-report "$lcov_file" \
    "$parallel_flag" \
    "$FIXTURE_DIR/test_coverage_engine.sh" >/dev/null 2>&1
}

function test_xtrace_engine_produces_the_same_lcov_as_the_trap_engine() {
  _skip_without_xtrace_support && return 0

  _run_fixture_with_engine "trap" "$TRAP_LCOV"
  _run_fixture_with_engine "xtrace" "$XTRACE_LCOV"

  assert_not_empty "$(cat "$TRAP_LCOV" 2>/dev/null)"
  assert_files_equals "$TRAP_LCOV" "$XTRACE_LCOV"
}

function test_xtrace_engine_reports_the_same_under_parallel() {
  _skip_without_xtrace_support && return 0

  _run_fixture_with_engine "xtrace" "$XTRACE_LCOV" "--no-parallel"
  _run_fixture_with_engine "xtrace" "$PARALLEL_LCOV" "--parallel"

  assert_not_empty "$(cat "$PARALLEL_LCOV" 2>/dev/null)"
  assert_files_equals "$XTRACE_LCOV" "$PARALLEL_LCOV"
}

function test_trap_engine_still_reports_when_xtrace_is_unavailable() {
  _run_fixture_with_engine "trap" "$TRAP_LCOV"

  local lcov
  lcov="$(cat "$TRAP_LCOV" 2>/dev/null)"
  assert_contains "SF:" "$lcov"
  assert_contains "DA:" "$lcov"
}
