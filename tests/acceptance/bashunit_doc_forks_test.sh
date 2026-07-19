#!/usr/bin/env bash
set -euo pipefail

# Regression guard for #832. `bashunit doc` used to fork an `echo | sed` pipe
# for every line of the ~1.6k-line assertions.md (plus another `sed` per
# printed docstring line): ~3200 forks and ~5s wall to print a text file. The
# doc path must parse the embedded docs in a single awk pass instead.
function test_doc_command_does_not_fork_sed_per_line() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "process tracing is unreliable under Git Bash" && return
  fi

  local trace
  trace="$(PS4='+ ' bash -x ./bashunit doc equals 2>&1 >/dev/null)"

  # Count real `sed` process executions. The doc path invokes `sed` via PATH
  # (not a pinned absolute binary), so the traced command token is a bare
  # `sed` — match both forms; `command -v sed` is a builtin and never shows.
  local sed_forks
  sed_forks="$(printf '%s\n' "$trace" | grep -cE '^\++ +(/[^ ]*/)?sed ' || true)"

  assert_equals 0 "$sed_forks"
}
