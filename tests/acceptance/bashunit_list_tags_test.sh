#!/usr/bin/env bash
set -euo pipefail

# `--list-tags` answers "which tags exist here?". Tags live only inside `# @tag`
# comments and nothing listed them: `--list --list-format json` reports the tags
# of the tests it *selected*, which is empty exactly when a mistyped --tag left
# you looking for the right name (#1265).
#
# The fixtures deliberately do not end in *test.sh — anything that does under
# tests/ is picked up by the real suite — so every run below passes explicit
# file paths rather than the fixture directory.

FIXTURES_PATH="./tests/acceptance/fixtures/list"
ALPHA="$FIXTURES_PATH/alpha.sh"
TAGGED="$FIXTURES_PATH/tagged.sh"
MULTITAG="$FIXTURES_PATH/multitag.sh"

function test_list_tags_prints_each_tag_once_sorted() {
  local output
  output="$(./bashunit --list-tags "$TAGGED" "$MULTITAG" 2>/dev/null)"

  assert_same "\
fast
fileTag
needs a db
slow" "$output"
}

# A tag may contain spaces (`# @tag needs a db`), so tags are one per line and
# split on commas only — never re-split on whitespace.
function test_list_tags_keeps_a_tag_containing_spaces_on_one_line() {
  local output
  output="$(./bashunit --list-tags "$MULTITAG" 2>/dev/null)"

  assert_contains "needs a db" "$output"
}

# Only the tags of the selected files, so it can answer "what is in here?".
function test_list_tags_covers_only_the_selected_files() {
  local output
  output="$(./bashunit --list-tags "$TAGGED" 2>/dev/null)"

  assert_same "\
fast
slow" "$output"
}

# Nothing but the tags: no banner, no test ids, and not even the `N tests` the
# plain --list writes to stderr, which would be noise in `--list-tags | while read`.
function test_list_tags_prints_nothing_else_on_either_stream() {
  local output
  output="$(./bashunit --list-tags "$TAGGED" 2>&1)"

  assert_same "\
fast
slow" "$output"
}

# A query, not a run: like --list, neither a test body nor a script hook runs.
function test_list_tags_runs_no_test_body_and_no_script_hook() {
  local marker="$FIXTURES_PATH/.marker"
  rm -f "$marker"

  local output
  output="$(./bashunit --list-tags "$FIXTURES_PATH/side_effect.sh" "$TAGGED" 2>/dev/null)"

  # The untagged fixture contributes nothing, so the tags of the second file are
  # what proves the scan happened at all -- otherwise "no marker" would only
  # mean the command failed before reaching the fixture.
  assert_same "\
fast
slow" "$output"
  assert_file_not_exists "$marker"
}

# An empty answer is a valid answer and exits 0, like the other query flags --
# unlike a real run, where selecting nothing is an error.
function test_an_untagged_selection_prints_nothing_and_exits_zero() {
  local output
  local exit_code=0
  output="$(./bashunit --list-tags "$ALPHA" 2>&1)" || exit_code=$?

  assert_equals 0 "$exit_code"
  assert_empty "$output"
}

# --list-tags implies --list, so the run is a query in --parallel too.
function test_list_tags_prints_only_the_tags_in_parallel() {
  local output
  output="$(./bashunit --parallel --list-tags "$TAGGED" 2>&1)"

  assert_same "\
fast
slow" "$output"
}
