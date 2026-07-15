#!/usr/bin/env bash
set -euo pipefail

# Regression guard for #798. bashunit's cold start historically forked `mktemp`
# once per deferred-output scratch file (failures, skipped, incomplete, risky,
# profile, rerun). Across the acceptance suite's ~258 nested runs that is ~1.5k
# forks and dominates wall-clock. Those scratch files must now be derived from a
# single run directory (no per-file fork), so a cold start forks `mktemp` zero
# times for them.
function test_coldstart_does_not_fork_mktemp_per_scratch_file() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "process tracing is unreliable under Git Bash" && return
  fi

  local trace
  trace="$(PS4='+ ' bash -x ./bashunit --version 2>&1 >/dev/null)"

  # Count real `mktemp` process executions: a traced line whose command token is
  # an absolute path ending in `mktemp` with no arguments. This excludes the
  # `command -v mktemp` probe and the `MKTEMP=` variable assignment.
  local mktemp_forks
  mktemp_forks="$(printf '%s\n' "$trace" | grep -cE '^\++ +/[^ ]*mktemp$' || true)"

  assert_less_than 1 "$mktemp_forks"
}

# Regression guard for the clock cold start. Selecting the `perl` clock impl used
# to fork perl twice: once for an empty `Time::HiRes` probe and once for the
# first real time read. Choosing an interpreter impl must cost at most one fork
# now (the probe reads the actual time and seeds it for the first read). On
# platforms that pick a fork-free/`date` clock (e.g. Linux) this is zero.
function test_coldstart_selects_clock_impl_without_a_probe_fork() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "process tracing is unreliable under Git Bash" && return
  fi

  local trace
  trace="$(PS4='+ ' bash -x ./bashunit --version 2>&1 >/dev/null)"

  # Count real interpreter executions used by the clock (perl/python/node) at
  # cold start. `command -v <interp>` is a shell builtin and never appears as an
  # executed command line, so it is not counted.
  local interp_forks
  interp_forks="$(printf '%s\n' "$trace" | grep -cE '^\++ +(perl|python|node) ' || true)"

  assert_less_or_equal_than 1 "$interp_forks"
}

# Regression guard for the base64 `-w` capability probe. It used to pipe
# `base64 --help` into a `grep -c -- -w` fork at load; a shell `case` match on
# the captured help text needs no fork. A cold start must not fork `grep` to
# detect base64 wrapping (nothing else forks grep at cold start).
function test_coldstart_does_not_fork_grep_to_detect_base64_wrap() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "process tracing is unreliable under Git Bash" && return
  fi

  local trace
  trace="$(PS4='+ ' bash -x ./bashunit --version 2>&1 >/dev/null)"

  # Count real `grep` process executions (resolved absolute path with args).
  # `command -v grep` is a builtin and never shows as an executed command line.
  local grep_forks
  grep_forks="$(printf '%s\n' "$trace" | grep -cE '^\++ +/[^ ]*grep ' || true)"

  assert_equals 0 "$grep_forks"
}

# Regression guard: cold start creates its two scratch directories (the run
# output dir and the shared temp dir) with a single `mkdir -p` call instead of
# one fork each.
function test_coldstart_creates_scratch_dirs_with_one_mkdir() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "process tracing is unreliable under Git Bash" && return
  fi

  local trace
  trace="$(PS4='+ ' bash -x ./bashunit --version 2>&1 >/dev/null)"

  local mkdir_forks
  mkdir_forks="$(printf '%s\n' "$trace" | grep -cE '^\++ +/?[a-z/]*mkdir ' || true)"

  assert_less_or_equal_than 1 "$mkdir_forks"
}
