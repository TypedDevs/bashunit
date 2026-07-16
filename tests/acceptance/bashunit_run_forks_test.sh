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

# Regression guard: rendering the "Source:" assert-line context of a failing
# test must not fork `sed` once per line of the test function's body. The body
# is read in a single pass now, so the `sed` fork count does not grow with the
# function length (a 20-line body used to cost ~20 `sed` forks here).
function test_failure_source_context_does_not_fork_sed_per_line() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "process tracing is unreliable under Git Bash" && return
  fi

  local dir
  dir="$(bashunit::temp_dir)"
  local fixture="$dir/long_fail_test.sh"
  {
    echo 'function test_long_fail() {'
    local i
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
      echo "  assert_same \"$i\" \"$i\""
    done
    echo '  assert_same "expected" "actual"'
    echo '}'
  } >"$fixture"

  local trace
  trace="$(PS4='+ ' bash -x ./bashunit --no-parallel "$fixture" 2>&1 >/dev/null)"

  local sed_forks
  sed_forks="$(printf '%s\n' "$trace" | grep -cE '^\++ +/?[a-z/]*sed ' || true)"

  assert_less_than 10 "$sed_forks"
}

# Regression guard: ordering a file's test functions by definition line used to
# pipe `declare -F` through `awk | sort | awk` — and the pipeline ran twice per
# file. The ordering is pure bash now, so a plain run forks `sort` zero times.
# Counted with a PATH shim (a `bash -x` trace would also count re-echoed test
# output, inflating the numbers).
function test_running_a_test_file_does_not_fork_sort() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "PATH shims are unreliable under Git Bash" && return
  fi

  local real_sort
  real_sort="$(command -v sort)"
  local dir
  dir="$(bashunit::temp_dir)"
  local count_file="$dir/count"
  {
    echo '#!/usr/bin/env bash'
    echo "echo x >> \"$count_file\""
    echo "exec \"$real_sort\" \"\$@\""
  } >"$dir/sort"
  chmod +x "$dir/sort"

  local fixture="$dir/sort_forks_test.sh"
  {
    echo 'function test_zz_first() { assert_true true; }'
    echo 'function test_aa_second() { assert_true true; }'
  } >"$fixture"

  PATH="$dir:$PATH" ./bashunit --no-parallel "$fixture" >/dev/null 2>&1

  local sort_forks=0
  if [ -f "$count_file" ]; then
    sort_forks="$(grep -c . "$count_file" || true)"
  fi

  assert_equals 0 "$sort_forks"
}

# Regression guard: listing all defined functions must use the `compgen -A
# function` builtin, not a `declare -F | awk` fork. The remaining awk budget of
# a plain run is the per-file file scans (data-provider map, which runs in both
# the counting subshell and the runner, plus the duplicate-name check).
function test_running_a_test_file_stays_within_the_awk_fork_budget() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "PATH shims are unreliable under Git Bash" && return
  fi

  local real_awk
  real_awk="$(command -v awk)"
  local dir
  dir="$(bashunit::temp_dir)"
  local count_file="$dir/count"
  {
    echo '#!/usr/bin/env bash'
    echo "echo x >> \"$count_file\""
    echo "exec \"$real_awk\" \"\$@\""
  } >"$dir/awk"
  chmod +x "$dir/awk"

  local fixture="$dir/awk_budget_test.sh"
  printf 'function test_ok() { assert_true true; }\n' >"$fixture"

  PATH="$dir:$PATH" ./bashunit --no-parallel "$fixture" >/dev/null 2>&1

  local awk_forks=0
  if [ -f "$count_file" ]; then
    awk_forks="$(grep -c . "$count_file" || true)"
  fi

  assert_less_or_equal_than 3 "$awk_forks"
}

# Regression guard: a run must remove its run-output scratch directory on exit.
# The directory (introduced in #801 under $TMPDIR/bashunit/run/) had no cleanup,
# leaking one empty directory per bashunit invocation. Point the nested run at a
# private TMPDIR so the check is deterministic and parallel-safe.
function test_run_removes_its_run_output_dir() {
  local dir
  dir="$(bashunit::temp_dir)"
  local fixture="$dir/leak_probe_test.sh"
  printf 'function test_ok() { assert_true true; }\n' >"$fixture"

  TMPDIR="$dir" ./bashunit --no-parallel "$fixture" >/dev/null 2>&1
  # Early-exit paths (no test run) must clean up via the EXIT trap.
  TMPDIR="$dir" ./bashunit --version >/dev/null 2>&1

  local leftover=0
  if [ -d "$dir/bashunit/run" ]; then
    local entry
    for entry in "$dir/bashunit/run"/*/*; do
      [ -e "$entry" ] && leftover=$((leftover + 1))
    done
  fi

  assert_equals 0 "$leftover"
}

# Regression guard for the parallel per-test result path. Publishing each
# test's result file used to fork `basename` (suite dir name), `mkdir -p`
# (suite dir, per test) and an `echo | tr | sed` pipeline (arg sanitizing, even
# with no args) — ~4 forks per test in the mode CI runs everything in. The dir
# name is parameter expansion now, mkdir is guarded by a `[ -d ]` builtin check,
# and arg sanitizing is skipped when there are no provider args.
function test_parallel_result_publishing_does_not_fork_per_test() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "PATH shims are unreliable under Git Bash" && return
  fi

  local dir
  dir="$(bashunit::temp_dir)"
  local count_file="$dir/count"
  local bin
  for bin in basename tr sed; do
    local real_bin
    real_bin="$(command -v "$bin")"
    {
      echo '#!/usr/bin/env bash'
      echo "echo $bin >> \"$count_file\""
      echo "exec \"$real_bin\" \"\$@\""
    } >"$dir/$bin"
    chmod +x "$dir/$bin"
  done

  local fixture="$dir/parallel_forks_test.sh"
  {
    echo 'function test_a() { assert_true true; }'
    echo 'function test_b() { assert_true true; }'
    echo 'function test_c() { assert_true true; }'
    echo 'function test_d() { assert_true true; }'
  } >"$fixture"

  PATH="$dir:$PATH" ./bashunit --parallel "$fixture" >/dev/null 2>&1

  local forks=0
  if [ -f "$count_file" ]; then
    forks="$(grep -c . "$count_file" || true)"
  fi

  assert_equals 0 "$forks"
}
