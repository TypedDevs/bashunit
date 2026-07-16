#!/usr/bin/env bash
set -euo pipefail

# src/learn.sh had no tests at all. These cover its non-interactive core: the
# progress persistence and the environment lifecycle. LEARN_PROGRESS_FILE is a
# readonly resolved from $HOME at source time, so each test sources learn.sh in
# a fresh shell with HOME pointed at an isolated directory — the suite's own
# already-sourced copy (bound to the real $HOME) is never exercised.

# Runs a snippet against a freshly-sourced learn.sh inside an isolated HOME/CWD.
function _learn_in_sandbox() {
  local sandbox root_dir
  sandbox="$(bashunit::temp_dir)"
  # BASHUNIT_ROOT_DIR may be relative (e.g. "."); resolve it before cd-ing away.
  root_dir="$(cd "$BASHUNIT_ROOT_DIR" && pwd)"
  (
    cd "$sandbox" &&
      HOME="$sandbox" bash -c '
        set -euo pipefail
        GREP="$(command -v grep)"
        # shellcheck source=/dev/null
        source "'"$root_dir"'/src/learn.sh"
        '"$1"'
      '
  )
}

function test_learn_mark_completed_then_is_completed() {
  local out
  out="$(_learn_in_sandbox '
    bashunit::learn::mark_completed "lesson_3"
    if bashunit::learn::is_completed "lesson_3"; then echo tracked; fi
  ')"

  assert_same "tracked" "$out"
}

function test_learn_is_completed_is_exact_lesson_match() {
  local out
  out="$(_learn_in_sandbox '
    bashunit::learn::mark_completed "lesson_1"
    if ! bashunit::learn::is_completed "lesson_10"; then echo distinct; fi
  ')"

  assert_same "distinct" "$out"
}

function test_learn_is_completed_without_progress_file() {
  local out
  out="$(_learn_in_sandbox '
    if ! bashunit::learn::is_completed "lesson_1"; then echo untracked; fi
  ')"

  assert_same "untracked" "$out"
}

function test_learn_mark_completed_accumulates_lessons() {
  local out
  out="$(_learn_in_sandbox '
    bashunit::learn::mark_completed "lesson_1"
    bashunit::learn::mark_completed "lesson_2"
    if bashunit::learn::is_completed "lesson_1" &&
      bashunit::learn::is_completed "lesson_2"; then echo both; fi
  ')"

  assert_same "both" "$out"
}

function test_learn_init_creates_workspace_and_cleanup_removes_it() {
  local out
  out="$(_learn_in_sandbox '
    bashunit::learn::init
    [ -d "$LEARN_TEMP_DIR" ] && echo "workspace"
    [ -d tests ] && echo "tests-dir"
    dir="$LEARN_TEMP_DIR"
    bashunit::learn::cleanup
    [ ! -d "$dir" ] && echo "cleaned"
  ')"

  assert_same $'workspace\ntests-dir\ncleaned' "$out"
}

function test_learn_cleanup_is_safe_without_init() {
  local out
  out="$(_learn_in_sandbox '
    bashunit::learn::cleanup
    echo "safe"
  ')"

  assert_same "safe" "$out"
}
