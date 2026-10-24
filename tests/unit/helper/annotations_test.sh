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

function build_indexed_map() {
  local i
  printf '%s\n' "$1" >"$FIXTURE"
  for ((i = 0; i < 65; i++)); do
    printf '# @timeout 0\n# @data_provider rows\nfunction metadata_padding_%s() { :; }\n' "$i"
  done >>"$FIXTURE"
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

function test_metadata_lookup_work_is_bounded_for_late_and_missing_functions() {
  local i name trace lines
  for ((i = 0; i < 100; i++)); do
    printf '# @timeout 0\n# @data_provider rows\nfunction test_index_%s() { :; }\n' "$i"
  done >"$FIXTURE"
  bashunit::helper::build_provider_map "$FIXTURE"
  trace="$(bashunit::temp_file)"

  for name in test_index_99 test_index_absent; do
    (
      trap - DEBUG
      unset BASH_XTRACEFD
      PS4='+'
      set -x
      bashunit::helper::provider_for_function "$name"
      bashunit::helper::annotations_for_function "$name"
      set +x
    ) 2>"$trace"
    lines=$(wc -l <"$trace")

    assert_less_than 100 "$lines"
  done
}

function test_metadata_indexes_distinguish_colons_from_underscores() {
  build_indexed_map '# @timeout 7
# @data_provider rows_colons
function test_index::name() { :; }
# @timeout 9
# @data_provider rows_underscores
function test_index_c_cname() { :; }'

  bashunit::helper::provider_for_function 'test_index::name'
  bashunit::helper::annotations_for_function 'test_index::name'
  assert_same 'rows_colons' "$_BASHUNIT_PROVIDER_FN_OUT"
  assert_same '7' "$_BASHUNIT_ANNOT_TIMEOUT_OUT"

  bashunit::helper::provider_for_function test_index_c_cname
  bashunit::helper::annotations_for_function test_index_c_cname
  assert_same 'rows_underscores' "$_BASHUNIT_PROVIDER_FN_OUT"
  assert_same '9' "$_BASHUNIT_ANNOT_TIMEOUT_OUT"

  bashunit::helper::provider_for_function 'test_index*'
  bashunit::helper::annotations_for_function 'test_index*'
  assert_empty "$_BASHUNIT_PROVIDER_FN_OUT"
  assert_empty "$_BASHUNIT_ANNOT_TIMEOUT_OUT"
}

function test_metadata_indexes_clear_when_a_file_is_missing_or_rebuilt() {
  build_indexed_map "# @timeout 3
# @data_provider rows
${FN}() { :; }"
  bashunit::helper::build_provider_map "$FIXTURE.missing"

  bashunit::helper::provider_for_function "$FN"
  bashunit::helper::annotations_for_function "$FN"
  assert_empty "$_BASHUNIT_PROVIDER_FN_OUT"
  assert_empty "$_BASHUNIT_ANNOT_TIMEOUT_OUT"

  build_map "${FN}() { :; }"
  bashunit::helper::provider_for_function "$FN"
  bashunit::helper::annotations_for_function "$FN"
  assert_empty "$_BASHUNIT_PROVIDER_FN_OUT"
  assert_empty "$_BASHUNIT_ANNOT_TIMEOUT_OUT"
}

function test_metadata_indexes_keep_the_first_definition() {
  build_indexed_map "# @timeout 3
# @data_provider first_rows
${FN}() { :; }
# @timeout 7
# @data_provider second_rows
${FN}() { :; }"

  bashunit::helper::provider_for_function "$FN"
  bashunit::helper::annotations_for_function "$FN"

  assert_same 'first_rows' "$_BASHUNIT_PROVIDER_FN_OUT"
  assert_same '3' "$_BASHUNIT_ANNOT_TIMEOUT_OUT"
}

function test_metadata_indexes_stay_unexported_when_allexport_is_enabled() {
  local exported
  exported=$(
    set -a
    build_indexed_map "# @timeout 3
# @data_provider rows
${FN}() { :; }"
    export -p | grep -E '^declare -x _BASHUNIT_METADATA_(PROVIDER|ANNOT)_' || true
  )

  assert_empty "$exported"
}

function test_small_metadata_maps_avoid_per_function_index_allocation() {
  build_map "# @timeout 3
# @data_provider rows
${FN}() { :; }"

  assert_empty "$(compgen -A variable _BASHUNIT_METADATA_ANNOT_)"
  assert_empty "$(compgen -A variable _BASHUNIT_METADATA_PROVIDER_)"
  bashunit::helper::provider_for_function "$FN"
  bashunit::helper::annotations_for_function "$FN"
  assert_same rows "$_BASHUNIT_PROVIDER_FN_OUT"
  assert_same 3 "$_BASHUNIT_ANNOT_TIMEOUT_OUT"
}

function test_annotations_recorded_after_indexing_remain_visible() {
  build_indexed_map "# @timeout 3
${FN}() { :; }"

  bashunit::helper::annotations_record "$OTHER_FN" 9 2 1 'added later'
  bashunit::helper::annotations_for_function "$OTHER_FN"
  assert_same 9 "$_BASHUNIT_ANNOT_TIMEOUT_OUT"
  assert_same 2 "$_BASHUNIT_ANNOT_RETRY_OUT"
  assert_same true "$_BASHUNIT_ANNOT_SKIP_OUT"
  assert_same 'added later' "$_BASHUNIT_ANNOT_REASON_OUT"
  bashunit::helper::annotations_for_function "$FN"
  assert_same 3 "$_BASHUNIT_ANNOT_TIMEOUT_OUT"
}

function test_large_metadata_indexes_rebuild_positions_between_files() {
  build_indexed_map "# @timeout 3
# @data_provider first_rows
${FN}() { :; }"
  FIXTURE="$(bashunit::temp_file)"

  build_indexed_map "# @timeout 1
# @data_provider other_rows
${OTHER_FN}() { :; }
# @timeout 9
# @data_provider second_rows
${FN}() { :; }"
  bashunit::helper::provider_for_function "$FN"
  bashunit::helper::annotations_for_function "$FN"

  assert_same second_rows "$_BASHUNIT_PROVIDER_FN_OUT"
  assert_same 9 "$_BASHUNIT_ANNOT_TIMEOUT_OUT"
}

function test_metadata_values_survive_the_index_size_boundary() {
  local size i
  for size in 64 65; do
    FIXTURE="$(bashunit::temp_file)"
    for ((i = 0; i < size; i++)); do
      printf '# @timeout %s\n# @data_provider rows_%s\nfunction metadata_boundary_%s() { :; }\n' "$i" "$i" "$i"
    done >"$FIXTURE"
    bashunit::helper::build_provider_map "$FIXTURE"
    bashunit::helper::provider_for_function "metadata_boundary_$((size - 1))"
    bashunit::helper::annotations_for_function "metadata_boundary_$((size - 1))"

    assert_same "rows_$((size - 1))" "$_BASHUNIT_PROVIDER_FN_OUT"
    assert_same "$((size - 1))" "$_BASHUNIT_ANNOT_TIMEOUT_OUT"
    if [ "$size" -eq 64 ]; then
      assert_empty "$(compgen -A variable _BASHUNIT_METADATA_ANNOT_)"
    else
      assert_not_empty "$(compgen -A variable _BASHUNIT_METADATA_ANNOT_)"
    fi
  done
}

function metadata_index_read_failure() {
  case "${2-}" in
  _BASHUNIT_METADATA_*_metadata__padding__*) return 1 ;;
  *)
    # shellcheck disable=SC2162 # Forward the caller's read flags unchanged.
    builtin read "$@"
    ;;
  esac
}

function test_index_setup_failure_keeps_metadata_available_and_cleans_partial_entries() {
  bashunit::mock read metadata_index_read_failure
  build_indexed_map "# @timeout 3
# @data_provider first_rows
${FN}() { :; }"

  bashunit::helper::provider_for_function metadata_padding_64
  bashunit::helper::annotations_for_function metadata_padding_64
  assert_same rows "$_BASHUNIT_PROVIDER_FN_OUT"
  assert_same 0 "$_BASHUNIT_ANNOT_TIMEOUT_OUT"
  bashunit::helper::annotations_for_function "$FN"
  assert_same 3 "$_BASHUNIT_ANNOT_TIMEOUT_OUT"

  FIXTURE="$(bashunit::temp_file)"
  build_map "${FN}() { :; }"
  assert_empty "$(compgen -A variable _BASHUNIT_METADATA_ANNOT_)"
  assert_empty "$(compgen -A variable _BASHUNIT_METADATA_PROVIDER_)"
}
