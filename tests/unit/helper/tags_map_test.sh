#!/usr/bin/env bash
# shellcheck disable=SC2317

FIXTURE_TAGS_MAP="$(dirname "${BASH_SOURCE[0]}")/../fixtures/tags_map/sample_tags.sh"
FIXTURE_TAGS_MAP_OTHER="$(dirname "${BASH_SOURCE[0]}")/../fixtures/tags_map/sample_tags_other.sh"

function tags_for() {
  bashunit::helper::build_tags_map "$1"
  bashunit::helper::tags_for_function "$2"
  echo "$_BASHUNIT_TAGS_OUT"
}

function test_tags_map_resolves_single_tag() {
  assert_same "single" \
    "$(tags_for "$FIXTURE_TAGS_MAP" "test_single_tag")"
}

function test_tags_map_accumulates_multiple_tags_nearest_first() {
  assert_same "second,first" \
    "$(tags_for "$FIXTURE_TAGS_MAP" "test_multiple_tags")"
}

function test_tags_map_keeps_tag_above_a_plain_comment() {
  assert_same "tagged" \
    "$(tags_for "$FIXTURE_TAGS_MAP" "test_tag_before_nontag_comment")"
}

function test_tags_map_blank_line_breaks_association() {
  assert_same "" \
    "$(tags_for "$FIXTURE_TAGS_MAP" "test_blank_breaks_association")"
}

function test_tags_map_resolves_arrow_style_definition() {
  assert_same "arrow" \
    "$(tags_for "$FIXTURE_TAGS_MAP" "test_arrow_style")"
}

function test_tags_map_returns_empty_when_function_has_no_tags() {
  assert_same "" \
    "$(tags_for "$FIXTURE_TAGS_MAP" "test_no_tags")"
}

function test_tags_map_returns_empty_for_unknown_function() {
  assert_same "" \
    "$(tags_for "$FIXTURE_TAGS_MAP" "test_does_not_exist")"
}

function test_tags_map_returns_empty_for_unreadable_script() {
  assert_same "" \
    "$(tags_for "/no/such/path/nope_test.sh" "test_single_tag")"
}

function test_tags_map_invalidates_cache_per_script_path() {
  # First file: test_single_tag -> single
  assert_same "single" \
    "$(tags_for "$FIXTURE_TAGS_MAP" "test_single_tag")"
  # Second file back to back: same function name, different tag
  assert_same "other" \
    "$(tags_for "$FIXTURE_TAGS_MAP_OTHER" "test_single_tag")"
  # Back to the first file: must rescan, not serve stale second-file data
  assert_same "single" \
    "$(tags_for "$FIXTURE_TAGS_MAP" "test_single_tag")"
}

FIXTURE_FILE_TAGS="$(dirname "${BASH_SOURCE[0]}")/../fixtures/tags_map/sample_file_tags.sh"
FIXTURE_FILE_TAGS_LATE="$(dirname "${BASH_SOURCE[0]}")/../fixtures/tags_map/sample_file_tags_late.sh"

# `# @tags a b` applies to every test in the file, so tagging a whole suite
# no longer means repeating `# @tag` above every function (#1008).
function test_file_level_tags_apply_to_a_test_with_no_tags_of_its_own() {
  assert_same "integration,db" \
    "$(tags_for "$FIXTURE_FILE_TAGS" "test_only_file_tags")"
}

function test_file_level_tags_union_with_function_tags_function_first() {
  assert_same "slow,integration,db" \
    "$(tags_for "$FIXTURE_FILE_TAGS" "test_file_and_function_tags")"
}

function test_a_tag_present_at_both_levels_is_not_duplicated() {
  assert_same "db,integration" \
    "$(tags_for "$FIXTURE_FILE_TAGS" "test_duplicate_between_file_and_function")"
}

# "Anywhere at top level": a file tag below the functions still applies.
function test_file_level_tags_apply_regardless_of_position() {
  assert_same "smoke" \
    "$(tags_for "$FIXTURE_FILE_TAGS_LATE" "test_declared_before_the_file_tags")"
}

# The singular form must not be swallowed by the plural rule or vice versa.
function test_singular_tag_is_still_function_scoped() {
  assert_same "" \
    "$(tags_for "$FIXTURE_TAGS_MAP" "test_no_tags")"
}
