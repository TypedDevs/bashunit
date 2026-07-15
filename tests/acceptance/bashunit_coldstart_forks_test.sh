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
