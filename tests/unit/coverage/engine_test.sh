#!/usr/bin/env bash
# shellcheck disable=SC2317

# Engine selection for the hybrid coverage tracer (ADR-009).
# The support probe is overridden per test so the selection matrix is pinned
# on every host, independent of the Bash the suite happens to run under.

_ORIG_COVERAGE_ENGINE=""
_ORIG_VERBOSE=""

function set_up() {
  _ORIG_COVERAGE_ENGINE="${BASHUNIT_COVERAGE_ENGINE:-}"
  _ORIG_VERBOSE="${BASHUNIT_VERBOSE:-}"
}

function tear_down() {
  BASHUNIT_COVERAGE_ENGINE="$_ORIG_COVERAGE_ENGINE"
  BASHUNIT_VERBOSE="$_ORIG_VERBOSE"
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

# On macOS's system Bash 3.2 an explicit BASHUNIT_COVERAGE_ENGINE=xtrace used to
# be accepted and ignored, with nothing said about it (#1005).
function test_an_explicit_xtrace_request_is_a_downgrade_when_unsupported() {
  _pretend_xtrace_unsupported
  BASHUNIT_COVERAGE_ENGINE="xtrace"

  local exit_code=0
  bashunit::coverage::engine_was_downgraded || exit_code=$?

  assert_equals 0 "$exit_code"
}

function test_an_honoured_xtrace_request_is_not_a_downgrade() {
  _pretend_xtrace_supported
  BASHUNIT_COVERAGE_ENGINE="xtrace"

  local exit_code=0
  bashunit::coverage::engine_was_downgraded || exit_code=$?

  assert_equals 1 "$exit_code"
}

# `auto` picking trap is the documented fallback, not an ignored request.
function test_auto_falling_back_to_trap_is_not_a_downgrade() {
  _pretend_xtrace_unsupported
  BASHUNIT_COVERAGE_ENGINE="auto"

  local exit_code=0
  bashunit::coverage::engine_was_downgraded || exit_code=$?

  assert_equals 1 "$exit_code"
}

function test_an_explicit_trap_request_is_not_a_downgrade() {
  _pretend_xtrace_unsupported
  BASHUNIT_COVERAGE_ENGINE="trap"

  local exit_code=0
  bashunit::coverage::engine_was_downgraded || exit_code=$?

  assert_equals 1 "$exit_code"
}

function test_engine_in_use_reports_the_resolved_engine() {
  _pretend_xtrace_supported
  BASHUNIT_COVERAGE_ENGINE="auto"
  local previous="${_BASHUNIT_COVERAGE_ENGINE_RESOLVED:-}"
  _BASHUNIT_COVERAGE_ENGINE_RESOLVED=""

  local actual
  actual="$(bashunit::coverage::engine_in_use)"
  _BASHUNIT_COVERAGE_ENGINE_RESOLVED="$previous"

  assert_equals "xtrace" "$actual"
}

# The resolved engine is picked once in init and inherited by every worker, so
# it wins over re-resolving: a worker must report what it actually ran.
function test_engine_in_use_prefers_the_engine_resolved_at_init() {
  _pretend_xtrace_supported
  BASHUNIT_COVERAGE_ENGINE="auto"
  local previous="${_BASHUNIT_COVERAGE_ENGINE_RESOLVED:-}"
  _BASHUNIT_COVERAGE_ENGINE_RESOLVED="trap"

  local actual
  actual="$(bashunit::coverage::engine_in_use)"
  _BASHUNIT_COVERAGE_ENGINE_RESOLVED="$previous"

  assert_equals "trap" "$actual"
}

function test_engine_notice_warns_when_an_explicit_request_was_downgraded() {
  _pretend_xtrace_unsupported
  BASHUNIT_COVERAGE_ENGINE="xtrace"
  BASHUNIT_VERBOSE="false"

  local output
  output="$(bashunit::coverage::print_engine_notice)"

  assert_contains "xtrace" "$output"
  assert_contains "trap" "$output"
}

function test_engine_notice_is_silent_when_auto_falls_back() {
  _pretend_xtrace_unsupported
  BASHUNIT_COVERAGE_ENGINE="auto"
  BASHUNIT_VERBOSE="false"

  assert_empty "$(bashunit::coverage::print_engine_notice)"
}

function test_engine_notice_is_silent_when_the_request_was_honoured() {
  _pretend_xtrace_supported
  BASHUNIT_COVERAGE_ENGINE="xtrace"
  BASHUNIT_VERBOSE="false"

  assert_empty "$(bashunit::coverage::print_engine_notice)"
}

function test_engine_notice_reports_the_engine_when_verbose() {
  _pretend_xtrace_supported
  BASHUNIT_COVERAGE_ENGINE="auto"
  BASHUNIT_VERBOSE="true"
  local previous="${_BASHUNIT_COVERAGE_ENGINE_RESOLVED:-}"
  _BASHUNIT_COVERAGE_ENGINE_RESOLVED="xtrace"

  local output
  output="$(bashunit::coverage::print_engine_notice)"
  _BASHUNIT_COVERAGE_ENGINE_RESOLVED="$previous"

  assert_contains "xtrace" "$output"
}
