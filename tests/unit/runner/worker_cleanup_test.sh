#!/usr/bin/env bash

# Stub process termination inside subshells because the handler exits.
# shellcheck disable=SC2329
function _run_worker_cleanup() {
  local order=$1
  local owed=${2:-}
  (
    function bashunit::runner::stop_active_test() { printf 'active-test\n' >>"$order"; }
    function bashunit::runner::stop_test_processes() { printf 'stop %s %s\n' "$1" "$2" >>"$order"; }
    function tear_down_after_script() { printf 'file-teardown\n' >>"$order"; }

    _BASHUNIT_WORKER_TEST_PIDS="111 222"
    _BASHUNIT_FILE_TEARDOWN_PENDING=""

    if [ "$owed" = owed ]; then
      bashunit::runner::mark_file_teardown_pending "some_test.sh"
    fi

    bashunit::runner::cleanup_worker_on_signal
  ) >/dev/null 2>&1 || true
}

function test_the_worker_handler_stops_owned_processes_before_the_file_teardown() {
  local order
  order="$(bashunit::temp_dir worker_cleanup_owed)/order"

  _run_worker_cleanup "$order" owed

  assert_same "active-test
stop tree 111 222
file-teardown" "$(cat "$order")"
}

function test_the_worker_handler_runs_no_file_teardown_when_the_file_owes_none() {
  local order
  order="$(bashunit::temp_dir worker_cleanup_not_owed)/order"

  _run_worker_cleanup "$order"

  assert_same "active-test
stop tree 111 222" "$(cat "$order")"
}

function test_the_worker_handler_runs_the_file_teardown_only_once() {
  local order
  order="$(bashunit::temp_dir worker_cleanup_twice)/order"

  (
    function bashunit::runner::stop_active_test() { :; }
    function bashunit::runner::stop_test_processes() { :; }
    function tear_down_after_script() { printf 'file-teardown\n' >>"$order"; }
    function exit() { :; }

    bashunit::runner::mark_file_teardown_pending "some_test.sh"
    bashunit::runner::cleanup_worker_on_signal
    bashunit::runner::cleanup_worker_on_signal
  ) >/dev/null 2>&1 || true

  assert_same "file-teardown" "$(cat "$order")"
}
