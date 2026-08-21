#!/usr/bin/env bash

# bashunit::runner::cleanup_worker_on_signal is the per-file worker's SIGTERM
# handler. Since #1320 the worker owns the file's tear_down_after_script, and the
# parent cannot run it: several files are in flight under --parallel and the hook
# is unset and redefined as the loop advances, so by interrupt time the parent no
# longer holds the right function body (#1331).
#
# Every call runs inside a subshell: the function ends in `exit`, and kill and
# pkill have to be replaced before they run for real.
#
# No signal is sent here. Delivering one to a real run depends on job control and
# on which frame the shell is in when it lands, which under a loaded --parallel
# suite is not reproducible: an acceptance test doing that failed 2 runs in 3
# while #1323 was being written. These pin the handler's body instead.
#
# Arguments: $1 - order log, $2 - "owed" to record a pending file teardown
#
# The definitions below shadow what the handler calls, so shellcheck sees two
# functions nothing in this file invokes.
# shellcheck disable=SC2329
function _run_worker_cleanup() {
  local order=$1
  local owed=${2:-}
  (
    function kill() { printf 'kill %s\n' "$*" >>"$order"; return 0; }
    function tear_down_after_script() { printf 'file-teardown\n' >>"$order"; }

    _BASHUNIT_WORKER_TEST_PIDS="111 222"

    if [ "$owed" = owed ]; then
      bashunit::runner::mark_file_teardown_pending "some_test.sh"
    fi

    bashunit::runner::cleanup_worker_on_signal
  ) >/dev/null 2>&1 || true
}

function test_the_worker_handler_kills_each_test_group_before_the_file_teardown() {
  local order
  order="$(bashunit::temp_dir worker_cleanup_owed)/order"

  _run_worker_cleanup "$order" owed

  # A negative pid signals the whole group, which is what reaches the test body
  # subshell and the command it blocks on. A plain per-pid TERM leaves the body a
  # live orphan, and a TERM the body defers behind its own foreground command
  # never runs its EXIT trap, which is where tear_down lives.
  #
  # Kills first, so the per-test tear_down each body's EXIT trap runs comes
  # before the file hook, as it does in a normal run.
  assert_same "kill -TERM -111
kill -TERM -222
file-teardown" "$(cat "$order")"
}

function test_the_worker_handler_runs_no_file_teardown_when_the_file_owes_none() {
  local order
  order="$(bashunit::temp_dir worker_cleanup_not_owed)/order"

  _run_worker_cleanup "$order"

  assert_same "kill -TERM -111
kill -TERM -222" "$(cat "$order")"
}

function test_the_worker_handler_runs_the_file_teardown_only_once() {
  local order
  order="$(bashunit::temp_dir worker_cleanup_twice)/order"

  # Settling the debt before the hook runs is what keeps a second delivery, or a
  # hook that re-enters this path, from releasing the same resource twice.
  (
    function kill() { return 0; }
    function tear_down_after_script() { printf 'file-teardown\n' >>"$order"; }
    function exit() { :; }

    bashunit::runner::mark_file_teardown_pending "some_test.sh"
    bashunit::runner::cleanup_worker_on_signal
    bashunit::runner::cleanup_worker_on_signal
  ) >/dev/null 2>&1 || true

  assert_same "file-teardown" "$(cat "$order")"
}
