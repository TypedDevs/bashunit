#!/usr/bin/env bash

# Probe used by bashunit_flag_env_leak_test.sh: fails if any run-mode flag of
# the parent bashunit process leaked into this (nested) run's environment.
# Every name listed here must be paired with the matching flag in the parent
# invocation: the flag branch's `export -n` is also what clears an export
# attribute stamped by an allexport .env load further up the process tree.
function test_run_mode_flags_are_not_in_the_environment() {
  local flags='STOP_ON_FAILURE|LOG_JUNIT|REPORT_HTML|REPORT_TAP|REPORT_JSON'
  flags="$flags|PARALLEL_RUN|SIMPLE_OUTPUT|STRICT_MODE|RETRY|TEST_TIMEOUT"
  flags="$flags|RANDOM_ORDER|SEED|NO_PROGRESS|FAIL_ON_RISKY|SKIP_ENV_FILE"

  local leaked
  leaked="$(env | grep -E "^BASHUNIT_($flags)=" || true)"

  assert_empty "$leaked"
}
