#!/usr/bin/env bash
set -euo pipefail

function provide_run_signals() {
  bashunit::data_set --no-parallel TERM
  bashunit::data_set --parallel TERM
  bashunit::data_set --no-parallel HUP
  bashunit::data_set --parallel HUP
  bashunit::data_set --no-parallel USR1
  bashunit::data_set --parallel USR1
  bashunit::data_set --no-parallel TERM teardown
  bashunit::data_set --parallel TERM teardown
  bashunit::data_set --parallel TERM slow_file
  bashunit::data_set --no-parallel TERM descendant
  bashunit::data_set --parallel TERM serial_file
  bashunit::data_set --parallel TERM timeout
  bashunit::data_set --no-parallel TERM mocked_process_tools
}

function test_sequential_body_can_read_its_controlling_terminal() {
  if bashunit::check_os::is_windows || ! command -v python3 >/dev/null 2>&1; then
    bashunit::skip 'Python 3 and Unix pseudo-terminals are required'
    return
  fi

  local dir fixture output status=0
  dir="$(bashunit::temp_dir terminal_read)"
  fixture="$dir/terminal_test.sh"
  {
    printf 'function %s() {\n' test_terminal_input
    printf '  sh -c '\''printf "%%s\\n" "$PPID"'\'' >"%s/body"\n' "$dir"
    printf '%s\n' '  local actual' '  IFS= read -r actual </dev/tty' '  assert_same entered "$actual"' '}'
  } >"$fixture"

  output=$(python3 - "$PWD/bashunit" "$fixture" "$dir/body" <<'PY'
import errno
import os
import pty
import select
import signal
import sys
import time

pid, terminal = pty.fork()
if pid == 0:
    os.execv(sys.argv[1], [sys.argv[1], "--no-parallel", "--no-color", "--skip-env-file", sys.argv[2]])

status = None
captured = bytearray()
deadline = time.monotonic() + 5
try:
    os.write(terminal, b"entered\n")
    while time.monotonic() < deadline:
        readable, _, _ = select.select([terminal], [], [], 0.05)
        if readable:
            try:
                data = os.read(terminal, 65536)
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
                data = b""
            captured.extend(data)
        found, child_status = os.waitpid(pid, os.WNOHANG)
        if found:
            status = child_status
            while select.select([terminal], [], [], 0)[0]:
                try:
                    data = os.read(terminal, 65536)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    break
                if not data:
                    break
                captured.extend(data)
            break
finally:
    try:
        with open(sys.argv[3], encoding="ascii") as body_file:
            body_pid = int(body_file.read())
        if os.getsid(body_pid) == pid:
            os.kill(body_pid, signal.SIGKILL)
    except (OSError, ValueError):
        pass
    if status is None:
        try:
            os.killpg(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        os.waitpid(pid, 0)
    os.close(terminal)

print(captured.decode("utf-8", errors="replace"))
if status is None:
    sys.exit(124)
if os.WIFEXITED(status):
    sys.exit(os.WEXITSTATUS(status))
sys.exit(128 + os.WTERMSIG(status))
PY
  ) || status=$?

  assert_successful_code "" "" "$status"
  assert_contains '1 passed' "$output"
}

function test_sequential_body_inherits_piped_standard_input() {
  local dir fixture output status=0
  dir="$(bashunit::temp_dir standard_input)"
  fixture="$dir/input_test.sh"
  printf 'function %s() { local actual; IFS= read -r actual; assert_same entered "$actual"; }\n' \
    test_piped_input >"$fixture"

  output=$(printf 'entered\n' | ./bashunit --no-parallel --no-color --skip-env-file "$fixture" 2>&1) || status=$?

  assert_successful_code "" "" "$status"
  assert_contains '1 passed' "$output"
}

function test_parallel_files_without_test_workers_keep_their_results_separate() {
  local dir output status=0 name
  dir="$(bashunit::temp_dir parallel_serial_files)"
  for name in one two; do
    {
      printf '%s\n' '# bashunit: no-parallel-tests'
      printf '%s\n' 'function wait() {' '  local status=0 ticks=0' '  builtin wait "$@" || status=$?'
      printf '  if [ "$#" -gt 0 ]; then\n    : >"%s/%s.waited"\n' "$dir" "$name"
      printf '    while [ ! -f "%s/one.waited" ] || [ ! -f "%s/two.waited" ]; do\n' "$dir" "$dir"
      printf '%s\n' '      sleep 0.01' '      ticks=$((ticks + 1))' '      if [ "$ticks" -ge 200 ]; then return 1; fi'
      printf '%s\n' '    done' '  fi' '  return "$status"' '}'
      printf 'function test_%s() {\n' "$name"
      printf '  : >"%s/%s.started"\n' "$dir" "$name"
      printf '  local ticks=0\n  while [ ! -f "%s/one.started" ] || [ ! -f "%s/two.started" ]; do\n' "$dir" "$dir"
      printf '%s\n' '    sleep 0.01' '    ticks=$((ticks + 1))' \
        '    if [ "$ticks" -ge 200 ]; then return 1; fi' '  done'
      if [ "$name" = one ]; then
        printf '%s\n' '  assert_same expected actual'
      else
        printf '%s\n' '  assert_true true'
      fi
      printf '%s\n' '}'
    } >"$dir/${name}_test.sh"
  done

  output=$(./bashunit --parallel --jobs 2 --no-color --env tests/acceptance/fixtures/.env.default \
    "$dir" 2>&1) || status=$?

  assert_same 1 "$status"
  assert_contains '1 passed, 1 failed, 2 total' "$output"
}

function test_failed_capture_open_does_not_reuse_a_previous_result() {
  local dir fixture output status=0
  dir="$(bashunit::temp_dir capture_permissions)"
  printf 'permission probe\n' >"$dir/probe"
  chmod 444 "$dir/probe"
  if [ -w "$dir/probe" ]; then
    bashunit::skip 'The current user can write to a read-only file'
    return
  fi
  fixture="$dir/capture_test.sh"
  {
    printf 'function %s() {\n' test_a_restrict_capture
    printf '%s\n' '  chmod 444 "$_BASHUNIT_RUN_OUTPUT_DIR/sequential-test-output_${_BASHUNIT_REPORTS_FILE_ORDINAL:-0}"'
    printf '%s\n' '  assert_true true' '}'
    printf 'function %s() {\n  : >"%s/body"\n  assert_same expected actual\n}\n' test_b_capture_body "$dir"
  } >"$fixture"

  output=$(./bashunit --no-parallel --no-color --env tests/acceptance/fixtures/.env.default \
    "$fixture" 2>&1) || status=$?

  assert_same 1 "$status"
  assert_contains '1 passed, 1 failed, 2 total' "$output"
  assert_contains 'Failed to capture test output' "$output"
  assert_file_not_exists "$dir/body"
}

function test_failed_capture_open_reports_an_error_without_running_the_body() {
  local dir fixture output status=0
  dir="$(bashunit::temp_dir capture_directory)"
  fixture="$dir/capture_test.sh"
  {
    printf 'function %s() {\n' set_up_before_script
    printf '%s\n' '  mkdir "$_BASHUNIT_RUN_OUTPUT_DIR/sequential-test-output_${_BASHUNIT_REPORTS_FILE_ORDINAL:-0}"' '}'
    printf 'function %s() {\n  : >"%s/body"\n  assert_true true\n}\n' test_blocked_capture_body "$dir"
  } >"$fixture"

  output=$(./bashunit --no-parallel --no-color --env tests/acceptance/fixtures/.env.default \
    "$fixture" 2>&1) || status=$?

  assert_same 1 "$status"
  assert_contains '1 failed' "$output"
  assert_contains 'Failed to capture test output' "$output"
  assert_file_not_exists "$dir/body"
}

function signal_fixture_process_is_running() {
  local pid="$1" state
  kill -0 "$pid" 2>/dev/null || return 1
  state=$(ps -p "$pid" -o stat= 2>/dev/null) || return 1
  case "$state" in
  *Z* | "") return 1 ;;
  esac
}

# @data_provider provide_run_signals
function test_interrupted_runs_release_hooks_processes_and_parallel_files() {
  if bashunit::check_os::is_windows; then
    bashunit::skip 'Unix process signals'
    return
  fi

  local mode="$1" signal="$2" dir fixture pid guardian_pid status=0 ticks=0
  local phase="${3:-body}"
  local body_pid child_pid worker_pid file_worker_pid parallel_dir grandchild_pid=""
  local -a run_options=()
  if [ "$phase" = timeout ]; then
    run_options=(--test-timeout 60)
  fi
  dir="$(bashunit::temp_dir signal_cleanup)"
  fixture="$dir/interrupted_test.sh"
  if [ "$phase" = mocked_process_tools ]; then
    mkdir "$dir/shims"
    printf '#!/usr/bin/env bash\nprintf "ps\\n" >>"$SIGNAL_FIXTURE_DIR/intercepted"\nprintf "99999999 99999998\\n"\n' \
      >"$dir/shims/ps"
    chmod +x "$dir/shims/ps"
  fi
  {
    if [ "$phase" = serial_file ]; then
      printf '%s\n' '# bashunit: no-parallel-tests'
    fi
    if [ "$phase" = mocked_process_tools ]; then
      printf '%s\n' 'export PATH="$SIGNAL_FIXTURE_DIR/shims:$PATH"'
      printf 'function %s() { printf "ps function\\n" >>"$SIGNAL_FIXTURE_DIR/intercepted"; }\n' ps
      printf 'function %s() { printf "kill\\n" >>"$SIGNAL_FIXTURE_DIR/intercepted"; }\n' kill
      printf 'function %s() { printf "sleep\\n" >>"$SIGNAL_FIXTURE_DIR/intercepted"; }\n' sleep
    fi
    # Background jobs may inherit ignored SIGINT, so exercise its handler through USR1.
    printf '%s\n' "trap 'bashunit::main::cleanup' USR1"
    printf 'function %s() {\n' tear_down
    printf '%s\n' '  printf "TEST\n" >>"$SIGNAL_FIXTURE_DIR/hooks"'
    printf '%s\n' '  if [ "$SIGNAL_FIXTURE_PHASE" = teardown ]; then'
    printf '%s\n' '    sh -c '\''trap "" TERM; printf "%s\n" "$$" >"$SIGNAL_FIXTURE_DIR/child"; exec sleep 30'\'''
    printf '%s\n' '  fi' '}'
    printf 'function %s() {\n' tear_down_after_script
    printf '%s\n' '  if [ "$SIGNAL_FIXTURE_PHASE" = slow_file ]; then sleep 1; fi'
    printf '%s\n' '  printf "FILE\n" >>"$SIGNAL_FIXTURE_DIR/hooks"' '  : >"$SIGNAL_FIXTURE_DIR/file_done"' '}'
    printf 'function %s() {\n' test_signal_body
    printf '%s\n' '  sh -c '\''printf "%s\n" "$PPID"'\'' >"$SIGNAL_FIXTURE_DIR/body"'
    printf '%s\n' '  printf "%s\n" "$TEMP_DIR_PARALLEL_TEST_SUITE" >"$SIGNAL_FIXTURE_DIR/parallel"'
    printf '%s\n' '  if [ "$SIGNAL_FIXTURE_PHASE" != teardown ]; then'
    printf '%s\n' '    if [ "$SIGNAL_FIXTURE_PHASE" = descendant ]; then'
    printf '%s\n' '      sh -c '\''sleep 30 &'
    printf '%s\n' '        printf "%s\n" "$!" >"$SIGNAL_FIXTURE_DIR/grandchild"'
    printf '%s\n' '        printf "%s\n" "$$" >"$SIGNAL_FIXTURE_DIR/child"; wait'\'''
    printf '%s\n' '    else'
    printf '%s\n' '      sh -c '\''printf "%s\n" "$$" >"$SIGNAL_FIXTURE_DIR/child"; exec sleep 30'\'''
    printf '%s\n' '    fi'
    printf '%s\n' '  fi'
    printf '%s\n' '  assert_true true' '}'
  } >"$fixture"

  set -m
  SIGNAL_FIXTURE_DIR="$dir" SIGNAL_FIXTURE_PHASE="$phase" ./bashunit "$mode" --no-color \
    --env tests/acceptance/fixtures/.env.default \
    ${run_options[@]+"${run_options[@]}"} "$fixture" >"$dir/output" 2>&1 &
  pid=$!
  set +m
  while [ ! -s "$dir/child" ] && [ "$ticks" -lt 100 ]; do
    sleep 0.05
    ticks=$((ticks + 1))
  done
  if [ ! -s "$dir/child" ]; then
    kill -KILL -"$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    assert_file_exists "$dir/child"
    return
  fi

  IFS= read -r body_pid <"$dir/body"
  IFS= read -r child_pid <"$dir/child"
  if [ -s "$dir/grandchild" ]; then
    IFS= read -r grandchild_pid <"$dir/grandchild"
  fi
  IFS= read -r parallel_dir <"$dir/parallel"
  worker_pid=$(ps -p "$body_pid" -o ppid= | tr -d '[:space:]')
  file_worker_pid="$pid"
  if [ "$mode" = --parallel ] && [ "$worker_pid" != "$pid" ]; then
    file_worker_pid=$(ps -p "$worker_pid" -o ppid= | tr -d '[:space:]')
    if [ "$file_worker_pid" = "$pid" ]; then
      file_worker_pid="$worker_pid"
    fi
  fi
  set -m
  (
    ticks=0
    while signal_fixture_process_is_running "$pid" && [ "$ticks" -lt 100 ]; do
      sleep 0.05
      ticks=$((ticks + 1))
    done
    if signal_fixture_process_is_running "$pid"; then
      : >"$dir/forced"
      for current in "$grandchild_pid" "$child_pid" "$body_pid" "$worker_pid" "$file_worker_pid" "$pid"; do
        if [ -n "$current" ]; then kill -KILL "$current" 2>/dev/null || true; fi
      done
    fi
  ) >/dev/null 2>&1 &
  guardian_pid=$!
  set +m
  kill -"$signal" "$pid"
  wait "$pid" 2>/dev/null || status=$?
  local file_finished=false
  if [ -f "$dir/file_done" ]; then
    file_finished=true
  fi
  kill -TERM -"$guardian_pid" 2>/dev/null || true
  wait "$guardian_pid" 2>/dev/null || true

  ticks=0
  while { [ ! -f "$dir/file_done" ] || signal_fixture_process_is_running "$body_pid" ||
    signal_fixture_process_is_running "$child_pid" ||
    signal_fixture_process_is_running "$grandchild_pid" ||
    signal_fixture_process_is_running "$worker_pid" || signal_fixture_process_is_running "$file_worker_pid"; } &&
    [ "$ticks" -lt 100 ]; do
    sleep 0.05
    ticks=$((ticks + 1))
  done
  local lingering=false current
  for current in "$body_pid" "$child_pid" "$grandchild_pid" "$worker_pid" "$file_worker_pid"; do
    if signal_fixture_process_is_running "$current"; then
      lingering=true
      kill -KILL "$current" 2>/dev/null || true
    fi
  done

  assert_same 1 "$status"
  assert_file_not_exists "$dir/forced"
  assert_file_not_exists "$dir/intercepted"
  assert_same false "$lingering"
  assert_same true "$file_finished"
  assert_file_exists "$dir/file_done"
  assert_file_exists "$dir/hooks"
  if [ "$mode" = --parallel ]; then
    assert_same "$(printf 'FILE\nTEST')" "$(LC_ALL=C sort "$dir/hooks")"
  else
    assert_same "$(printf 'TEST\nFILE')" "$(cat "$dir/hooks")"
  fi
  if [ "$mode" = --parallel ]; then
    assert_directory_not_exists "$parallel_dir"
  fi
  if [ "$signal" = USR1 ]; then
    assert_contains 'Caught Ctrl-C, killing all child processes' "$(cat "$dir/output")"
  else
    assert_contains "Caught SIG$signal, killing all child processes" "$(cat "$dir/output")"
  fi
}
