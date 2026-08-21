#!/usr/bin/env bash

# bashunit::main::cleanup is the Ctrl-C handler. It kills the run's children,
# releases what the interrupted file still owes, and exits.
#
# Every call runs inside a subshell: the function ends in `exit`, and pkill and
# the three cleanup calls have to be replaced before they run for real. Left
# alone, cleanup_run_output_dir would delete the live run's own scratch
# directory, which is the disappearing-scratch-dir shape of #1137.
#
# A signal is never sent here. Delivering SIGINT to a real run depends on job
# control and on which frame the shell is in when it lands, which under a loaded
# --parallel suite is not reproducible. What #1323 changed is the handler's body,
# and that is what these pin.
#
# Arguments: $1 - order log, $2 - "owed" to record a pending file teardown
#
# The definitions below shadow what cleanup calls, so shellcheck sees five
# functions nothing in this file invokes.
# shellcheck disable=SC2329
function _run_cleanup() {
  local order=$1
  local owed=${2:-}
  (
    function pkill() { printf 'pkill\n' >>"$order"; return 0; }
    function bashunit::cleanup_script_temp_files() { printf 'temp-files\n' >>"$order"; }
    function bashunit::parallel::cleanup() { :; }
    function bashunit::env::cleanup_run_output_dir() { :; }
    function tear_down_after_script() { printf 'file-teardown\n' >>"$order"; }

    if [ "$owed" = owed ]; then
      bashunit::runner::mark_file_teardown_pending "some_test.sh"
    fi

    bashunit::main::cleanup
  ) >/dev/null 2>&1 || true
}

function test_cleanup_runs_the_file_teardown_the_interrupted_run_still_owed() {
  local order
  order="$(bashunit::temp_dir cleanup_owed)/order"

  _run_cleanup "$order" owed

  # After pkill, so the per-test tear_down that a test subshell's EXIT trap runs
  # comes first as it does in a normal run, and before the temp-file sweep, so a
  # hook reading a bashunit::temp_file still finds it.
  assert_same "pkill
file-teardown
temp-files" "$(cat "$order")"
}

function test_cleanup_runs_no_file_teardown_when_the_run_owes_none() {
  local order
  order="$(bashunit::temp_dir cleanup_not_owed)/order"

  _run_cleanup "$order"

  assert_same "pkill
temp-files" "$(cat "$order")"
}
