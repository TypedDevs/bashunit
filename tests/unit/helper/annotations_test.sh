#!/usr/bin/env bash

# The scan itself rides on build_provider_map (one awk pass per file), so these
# build a map from a fixture on disk and assert the lookups over it.

function set_up() {
  FIXTURE="$(bashunit::temp_file)"
  # Composed at run time: a literal `function test_x() {` in this file would be
  # picked up by the duplicate-function scan of this very test file.
  FN="test_annotated"
  OTHER_FN="test_plain"
}

function build_map() { # $1 = file content
  printf '%s\n' "$1" >"$FIXTURE"
  bashunit::helper::build_provider_map "$FIXTURE"
}

function test_annotations_are_read_from_the_block_above_the_function() {
  build_map "# @timeout 30
# @retry 2
${FN}() { :; }"

  bashunit::helper::annotations_for_function "$FN"

  assert_same "30" "$_BASHUNIT_ANNOT_TIMEOUT_OUT"
  assert_same "2" "$_BASHUNIT_ANNOT_RETRY_OUT"
  assert_same "false" "$_BASHUNIT_ANNOT_SKIP_OUT"
}

function test_skip_carries_its_reason() {
  build_map "# @skip needs a live database
${FN}() { :; }"

  bashunit::helper::annotations_for_function "$FN"

  assert_same "true" "$_BASHUNIT_ANNOT_SKIP_OUT"
  assert_same "needs a live database" "$_BASHUNIT_ANNOT_REASON_OUT"
}

function test_skip_without_a_reason() {
  build_map "# @skip
${FN}() { :; }"

  bashunit::helper::annotations_for_function "$FN"

  assert_same "true" "$_BASHUNIT_ANNOT_SKIP_OUT"
  assert_empty "$_BASHUNIT_ANNOT_REASON_OUT"
}

function test_a_blank_line_breaks_the_association() {
  build_map "# @timeout 30

${FN}() { :; }"

  bashunit::helper::annotations_for_function "$FN"

  assert_empty "$_BASHUNIT_ANNOT_TIMEOUT_OUT"
}

function test_another_comment_keeps_the_block_open() {
  build_map "# @timeout 30
# just a note
${FN}() { :; }"

  bashunit::helper::annotations_for_function "$FN"

  assert_same "30" "$_BASHUNIT_ANNOT_TIMEOUT_OUT"
}

function test_an_unannotated_function_reads_empty() {
  build_map "# @timeout 30
${FN}() { :; }
${OTHER_FN}() { :; }"

  bashunit::helper::annotations_for_function "$OTHER_FN"

  assert_empty "$_BASHUNIT_ANNOT_TIMEOUT_OUT"
  assert_empty "$_BASHUNIT_ANNOT_RETRY_OUT"
  assert_same "false" "$_BASHUNIT_ANNOT_SKIP_OUT"
}

function test_annotations_coexist_with_a_data_provider_and_a_tag() {
  build_map "# @tag slow
# @data_provider provide_values
# @timeout 7
${FN}() { :; }"

  bashunit::helper::provider_for_function "$FN"
  bashunit::helper::annotations_for_function "$FN"

  assert_same "provide_values" "$_BASHUNIT_PROVIDER_FN_OUT"
  assert_same "7" "$_BASHUNIT_ANNOT_TIMEOUT_OUT"
}

function test_timeout_zero_is_kept_as_an_explicit_value() {
  build_map "# @timeout 0
${FN}() { :; }"

  bashunit::helper::annotations_for_function "$FN"

  assert_same "0" "$_BASHUNIT_ANNOT_TIMEOUT_OUT"
}
