#!/usr/bin/env bash
# shellcheck disable=SC2317

# Engine selection for the hybrid coverage tracer (ADR-009).
# The support probe is overridden per test so the selection matrix is pinned
# on every host, independent of the Bash the suite happens to run under.

_ORIG_COVERAGE_ENGINE=""

function set_up() {
  _ORIG_COVERAGE_ENGINE="${BASHUNIT_COVERAGE_ENGINE:-}"
}

function tear_down() {
  BASHUNIT_COVERAGE_ENGINE="$_ORIG_COVERAGE_ENGINE"
}

function _pretend_xtrace_supported() {
  eval 'function bashunit::coverage::xtrace_is_supported() { return 0; }'
}

function _pretend_xtrace_unsupported() {
  eval 'function bashunit::coverage::xtrace_is_supported() { return 1; }'
}

function test_forced_trap_selects_the_trap_engine() {
  _pretend_xtrace_supported
  BASHUNIT_COVERAGE_ENGINE="trap"

  assert_equals "trap" "$(bashunit::coverage::resolve_engine)"
}

function test_forced_xtrace_selects_the_xtrace_engine_when_supported() {
  _pretend_xtrace_supported
  BASHUNIT_COVERAGE_ENGINE="xtrace"

  assert_equals "xtrace" "$(bashunit::coverage::resolve_engine)"
}

function test_forced_xtrace_falls_back_to_trap_when_unsupported() {
  _pretend_xtrace_unsupported
  BASHUNIT_COVERAGE_ENGINE="xtrace"

  assert_equals "trap" "$(bashunit::coverage::resolve_engine)"
}

function test_auto_selects_xtrace_when_supported() {
  _pretend_xtrace_supported
  BASHUNIT_COVERAGE_ENGINE="auto"

  assert_equals "xtrace" "$(bashunit::coverage::resolve_engine)"
}

function test_auto_selects_trap_when_unsupported() {
  _pretend_xtrace_unsupported
  BASHUNIT_COVERAGE_ENGINE="auto"

  assert_equals "trap" "$(bashunit::coverage::resolve_engine)"
}

function test_unset_engine_behaves_like_auto() {
  _pretend_xtrace_supported
  unset BASHUNIT_COVERAGE_ENGINE

  assert_equals "xtrace" "$(bashunit::coverage::resolve_engine)"
}

function test_unknown_engine_falls_back_to_trap() {
  _pretend_xtrace_supported
  BASHUNIT_COVERAGE_ENGINE="banana"

  assert_equals "trap" "$(bashunit::coverage::resolve_engine)"
}

function test_xtrace_support_probe_matches_the_running_bash() {
  local expected="unsupported"
  if [ "${BASH_VERSINFO[0]}" -gt 4 ]; then
    expected="supported"
  elif [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -ge 1 ]; then
    expected="supported"
  fi

  local actual="unsupported"
  if bashunit::coverage::xtrace_is_supported; then
    actual="supported"
  fi

  assert_equals "$expected" "$actual"
}
