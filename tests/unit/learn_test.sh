#!/usr/bin/env bash
set -euo pipefail

# Covers the non-interactive core of src/learn.sh: progress persistence and the
# environment lifecycle. LEARN_PROGRESS_FILE is a readonly resolved from $HOME at
# source time, so each test sources learn.sh in a fresh shell with HOME pointed
# at an isolated directory — the suite's own already-sourced copy (bound to the
# real $HOME) is never exercised.

# Runs a snippet against a freshly-sourced learn.sh inside an isolated HOME/CWD.
function _learn_in_sandbox() {
  local sandbox root_dir
  sandbox="$(bashunit::temp_dir)"
  # Resolve the repo root from this test file, not $BASHUNIT_ROOT_DIR: under
  # `build.sh --verify` the running binary's root dir has no src/ (#834).
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  # stdin is /dev/null so the `read -p "Press Enter to continue..."` prompts in
  # the interactive paths hit EOF and return instead of blocking the suite.
  # BASHUNIT_ROOT_DIR is set INSIDE the child (run_lesson_test shells out to the
  # entrypoint through it): it is readonly in the caller, so a `VAR=x cmd` prefix
  # assignment would abort with "readonly variable".
  (
    cd "$sandbox" &&
      HOME="$sandbox" bash -c '
        set -euo pipefail
        BASHUNIT_ROOT_DIR="'"$root_dir"'"
        export BASHUNIT_ROOT_DIR
        GREP="$(command -v grep)"
        # learn.sh renders coloured output but does not source colors.sh. Stub
        # the palette to empty rather than pulling in the real chain
        # (str -> globals -> env -> colors), which would couple this unit test to
        # source order and make the assertions match escape codes.
        _BASHUNIT_COLOR_BOLD="" _BASHUNIT_COLOR_DEFAULT="" _BASHUNIT_COLOR_FAILED=""
        _BASHUNIT_COLOR_FAINT="" _BASHUNIT_COLOR_INCOMPLETE="" _BASHUNIT_COLOR_PASSED=""
        # shellcheck source=/dev/null
        source "'"$root_dir"'/src/learn.sh"
        '"$1"'
      ' </dev/null
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

# The lesson bodies had no coverage at all, which is why a duplication cleanup in
# this module could not be attempted safely. These cover the rest of the
# non-interactive core so a refactor has a net.

function test_learn_print_menu_lists_every_lesson_and_the_controls() {
  local out
  out="$(_learn_in_sandbox 'bashunit::learn::print_menu || true')"

  assert_contains "1." "$out"
  assert_contains "10." "$out"
  assert_contains "Basics" "$out"
}

function test_learn_show_progress_without_a_progress_file() {
  local out
  out="$(_learn_in_sandbox 'bashunit::learn::show_progress || true')"

  assert_contains "No progress yet" "$out"
}

function test_learn_show_progress_reflects_completed_lessons() {
  local out
  out="$(_learn_in_sandbox '
    bashunit::learn::mark_completed "lesson_1"
    bashunit::learn::show_progress || true
  ')"

  assert_contains "Your Progress" "$out"
  assert_not_contains "No progress yet" "$out"
}

function test_learn_reset_progress_clears_completed_lessons() {
  local out
  out="$(_learn_in_sandbox '
    bashunit::learn::mark_completed "lesson_4"
    bashunit::learn::reset_progress >/dev/null || true
    if ! bashunit::learn::is_completed "lesson_4"; then echo cleared; fi
  ')"

  assert_same "cleared" "$out"
}

function test_learn_reset_progress_is_safe_without_a_progress_file() {
  local out
  out="$(_learn_in_sandbox '
    bashunit::learn::reset_progress >/dev/null || true
    echo safe
  ')"

  assert_same "safe" "$out"
}

function test_learn_create_example_file_writes_and_makes_it_executable() {
  local out
  out="$(_learn_in_sandbox '
    bashunit::learn::create_example_file "sample_test.sh" "#!/usr/bin/env bash" >/dev/null || true
    [ -f sample_test.sh ] && echo exists
    [ -x sample_test.sh ] && echo executable
    cat sample_test.sh
  ')"

  assert_same $'exists\nexecutable\n#!/usr/bin/env bash' "$out"
}

function test_learn_run_lesson_test_marks_the_lesson_completed_when_it_passes() {
  local out
  out="$(_learn_in_sandbox '
    printf "#!/usr/bin/env bash\n\nfunction test_ok() {\n  assert_same 1 1\n}\n" >pass_test.sh
    bashunit::learn::run_lesson_test "pass_test.sh" "2" >/dev/null 2>&1 || true
    if bashunit::learn::is_completed "lesson_2"; then echo completed; fi
  ')"

  assert_same "completed" "$out"
}

function test_learn_run_lesson_test_does_not_mark_the_lesson_when_it_fails() {
  local out
  out="$(_learn_in_sandbox '
    printf "#!/usr/bin/env bash\n\nfunction test_bad() {\n  assert_same 1 2\n}\n" >fail_test.sh
    bashunit::learn::run_lesson_test "fail_test.sh" "5" >/dev/null 2>&1 || true
    if ! bashunit::learn::is_completed "lesson_5"; then echo not_completed; fi
  ')"

  assert_same "not_completed" "$out"
}
