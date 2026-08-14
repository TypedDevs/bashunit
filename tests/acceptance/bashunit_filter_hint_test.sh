#!/usr/bin/env bash
set -euo pipefail

# The report prints a humanized title -- `✓ Passed: Alpha` for `test_alpha` --
# and `--filter` matches the function name, case-sensitively. So the most
# natural thing a user can do, copying the name they just read, finds nothing:
#
#   $ bashunit --filter Alpha t_test.sh
#    No tests found
#
# That is a dead end. The run knows the filter and knows every function it
# sourced, so it can say which rule was applied and name the test that would
# have matched.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
}

function set_up() {
  WORKDIR="$(bashunit::temp_dir)"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function test_alpha() { assert_same 1 1; }'
    printf '%s\n' 'function test_beta_case() { assert_same 1 1; }'
  } >"$WORKDIR/t_test.sh"
}

function _run() { # $@ = flags
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel "$@" t_test.sh 2>&1 | strip_ansi) || true
}

# The title as printed, fed straight back.
function test_a_filter_matching_only_by_case_names_the_test_it_meant() {
  local output
  output="$(_run --filter Alpha)"

  assert_contains "No tests found" "$output"
  assert_contains "test_alpha" "$output"
}

# The rule itself has to be stated, or the reader learns nothing from a filter
# that has no near match.
function test_a_filter_matching_nothing_states_the_rule() {
  local output
  output="$(_run --filter nothing_like_this)"

  assert_contains "No tests found" "$output"
  assert_contains "function name" "$output"
}

# A humanized multi-word title is the same mistake, and the space is why the
# project's own agent rules already warn about it. The title is the function
# name with underscores shown as spaces, so it resolves to a suggestion too.
function test_a_humanized_title_with_a_space_names_the_test_it_meant() {
  local output
  output="$(_run --filter "Beta case")"

  assert_contains "No tests found" "$output"
  assert_contains "test_beta_case" "$output"
}

# No filter, no hint: an empty run for any other reason must read exactly as it
# did before, which is also what the path snapshot pins.
function test_an_empty_run_without_a_filter_is_unchanged() {
  local output
  output="$( (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --filter '' t_test.sh 2>&1 | strip_ansi) || true)"

  assert_not_contains "function name" "$output"
}

# The hint must not appear when the filter did select something.
function test_a_matching_filter_prints_no_hint() {
  local output
  output="$(_run --filter alpha)"

  assert_contains "1 passed" "$output"
  assert_not_contains "function name" "$output"
}

# The summary renders in the parent in both modes, but that is exactly the
# boundary where this project has shipped silent divergences before (#1145,
# #1147), so assert it rather than reason about it.
function test_the_hint_reaches_a_parallel_run_too() {
  local output
  output="$( (cd "$WORKDIR" && "$BASHUNIT_BIN" --parallel --filter "Beta case" t_test.sh 2>&1 | strip_ansi) || true)"

  assert_contains "No tests found" "$output"
  assert_contains "test_beta_case" "$output"
}
