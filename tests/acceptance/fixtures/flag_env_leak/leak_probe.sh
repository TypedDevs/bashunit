#!/usr/bin/env bash

# Probe used by bashunit_flag_env_leak_test.sh: fails if any run-mode flag of
# the parent bashunit process leaked into this (nested) run's environment.
function test_run_mode_flags_are_not_in_the_environment() {
  local leaked
  leaked="$(env | grep -E '^BASHUNIT_(STOP_ON_FAILURE|LOG_JUNIT|REPORT_HTML|REPORT_TAP|REPORT_JSON)=' || true)"

  assert_empty "$leaked"
}
