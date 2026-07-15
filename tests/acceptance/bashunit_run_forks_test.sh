#!/usr/bin/env bash
set -euo pipefail

# Regression guard for the per-file run path. Running a test file used to fork
# `grep` twice: once in the runner to scan sourcing stderr for "syntax error"/
# "unexpected EOF", and once in discovery to decide whether to also match the
# `.bash` variant of the test pattern. Both are shell `case` matches now, so a
# plain run forks `grep` zero times — this matters across the acceptance suite's
# ~258 nested runs, each of which sources at least one test file.
function test_running_a_test_file_does_not_fork_grep() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "process tracing is unreliable under Git Bash" && return
  fi

  local dir
  dir="$(bashunit::temp_dir)"
  local fixture="$dir/grep_forks_test.sh"
  printf 'function test_ok() { assert_true true; }\n' >"$fixture"

  local trace
  trace="$(PS4='+ ' bash -x ./bashunit --no-parallel "$fixture" 2>&1 >/dev/null)"

  # Count real `grep` process executions (resolved absolute path with args).
  local grep_forks
  grep_forks="$(printf '%s\n' "$trace" | grep -cE '^\++ +/[^ ]*grep ' || true)"

  assert_equals 0 "$grep_forks"
}

# Regression guard: exporting a test's subshell result must not fork `cat`. It
# used to emit the encoded result payload with a `cat <<EOF` heredoc — one fork
# per test — which `printf` (a builtin) does without forking. Four independent
# tests must therefore fork `cat` far fewer than four times.
function test_running_tests_does_not_fork_cat_per_test() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "process tracing is unreliable under Git Bash" && return
  fi

  local dir
  dir="$(bashunit::temp_dir)"
  local fixture="$dir/cat_forks_test.sh"
  {
    echo 'function test_a() { assert_true true; }'
    echo 'function test_b() { assert_true true; }'
    echo 'function test_c() { assert_true true; }'
    echo 'function test_d() { assert_true true; }'
  } >"$fixture"

  local trace
  trace="$(PS4='+ ' bash -x ./bashunit --no-parallel "$fixture" 2>&1 >/dev/null)"

  local cat_forks
  cat_forks="$(printf '%s\n' "$trace" | grep -cE '^\++ +/?[a-z/]*cat( |$)' || true)"

  assert_less_or_equal_than 1 "$cat_forks"
}
