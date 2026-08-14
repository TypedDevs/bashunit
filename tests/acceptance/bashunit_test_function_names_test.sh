#!/usr/bin/env bash
set -euo pipefail

# Which functions count as tests is the first thing a user has to get right, and
# getting it wrong is silent: an uncollected function leaves the run green with
# fewer tests than the file defines. docs/test-files.md promised two styles the
# matcher never accepted -- a name with no underscore after `test`, and any
# capitalisation of the prefix (#1215).
#
# The rule `bashunit::helper::get_functions_to_run` implements is a literal,
# lowercase `test_` prefix. Pin it here so the guide and the matcher cannot
# drift apart again in either direction.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
}

function set_up() {
  WORKDIR="$(bashunit::temp_dir)"
}

function _list() { # $1 = file contents
  printf '%s\n' "$1" >"$WORKDIR/n_test.sh"
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --list n_test.sh 2>&1) || true
}

# The three definition *styles* are all fine -- `function name()`, `name()` and
# `function name` without parentheses. What decides collection is the name.
function test_every_definition_style_is_collected_when_the_name_starts_with_test_() {
  local output
  output=$(_list '#!/usr/bin/env bash
function test_with_function_keyword_and_parens() { assert_same 1 1; }
test_with_parens_only() { assert_same 1 1; }
function test_without_parens { assert_same 1 1; }')

  assert_contains "test_with_function_keyword_and_parens" "$output"
  assert_contains "test_with_parens_only" "$output"
  assert_contains "test_without_parens" "$output"
}

# The underscore is part of the prefix, so a camelCase name is a helper.
function test_a_name_without_the_underscore_is_not_collected() {
  local output
  output=$(_list '#!/usr/bin/env bash
function testRenderAllTestsPassed { assert_same 1 1; }
function test_real_1() { assert_same 1 1; }')

  assert_contains "test_real_1" "$output"
  assert_not_contains "testRenderAllTestsPassed" "$output"
}

# The prefix is matched case-sensitively.
function test_the_prefix_is_case_sensitive() {
  local output
  output=$(_list '#!/usr/bin/env bash
function TEST_upper() { assert_same 1 1; }
function Test_mixed() { assert_same 1 1; }
function test_real_2() { assert_same 1 1; }')

  assert_contains "test_real_2" "$output"
  assert_not_contains "TEST_upper" "$output"
  assert_not_contains "Test_mixed" "$output"
}

# A helper whose name merely begins with the letters `test` must stay a helper:
# this is what a bare `test` prefix would break, and why the matcher was left
# alone in favour of correcting the guide.
function test_a_helper_named_like_a_test_is_left_alone() {
  local output
  output=$(_list '#!/usr/bin/env bash
function testdata_path() { echo /tmp; }
function test_real_3() { assert_same 1 1; }')

  assert_contains "test_real_3" "$output"
  assert_not_contains "testdata_path" "$output"
}
