#!/usr/bin/env bash

function bashunit::parallel::mark_stop_on_failure() {
  touch "$TEMP_FILE_PARALLEL_STOP_ON_FAILURE"
}

function bashunit::parallel::must_stop_on_failure() {
  [ -f "$TEMP_FILE_PARALLEL_STOP_ON_FAILURE" ]
}

function bashunit::parallel::cleanup() {
  # shellcheck disable=SC2153
  local target="$TEMP_DIR_PARALLEL_TEST_SUITE"
  case "$target" in
  */bashunit/parallel/*)
    rm -rf "$target"
    ;;
  *)
    bashunit::internal_log "parallel::cleanup" "refused unsafe path:$target"
    return 1
    ;;
  esac
}

function bashunit::parallel::init() {
  bashunit::parallel::cleanup
  mkdir -p "$TEMP_DIR_PARALLEL_TEST_SUITE"
}

# Cached result of resolve_enabled ("true"/"false"); empty until resolved.
_BASHUNIT_PARALLEL_ENABLED=""

# Pure predicate: parallel requested AND running on a supported OS. No caching
# or logging, so it is safe to call fresh (e.g. from unit tests).
function bashunit::parallel::_compute_enabled() {
  bashunit::env::is_parallel_run_enabled &&
    (bashunit::check_os::is_macos || bashunit::check_os::is_ubuntu ||
      bashunit::check_os::is_alpine || bashunit::check_os::is_windows)
}

# Resolve parallel mode once (after arg parsing) into _BASHUNIT_PARALLEL_ENABLED
# so is_enabled becomes a pure global read on the per-test hot path. The env +
# OS checks are constant for the whole run.
function bashunit::parallel::resolve_enabled() {
  if bashunit::parallel::_compute_enabled; then
    _BASHUNIT_PARALLEL_ENABLED=true
  else
    _BASHUNIT_PARALLEL_ENABLED=false
  fi
  bashunit::internal_log "bashunit::parallel::resolve_enabled" \
    "requested:$BASHUNIT_PARALLEL_RUN" "os:${_BASHUNIT_OS:-Unknown}" \
    "enabled:$_BASHUNIT_PARALLEL_ENABLED"
}

function bashunit::parallel::is_enabled() {
  case "$_BASHUNIT_PARALLEL_ENABLED" in
  true) return 0 ;;
  false) return 1 ;;
  esac
  # Not resolved yet (e.g. unit tests call is_enabled directly): compute fresh
  # without caching so per-test env/OS changes are still honoured.
  bashunit::parallel::_compute_enabled
}
