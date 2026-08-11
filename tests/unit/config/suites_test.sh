#!/usr/bin/env bash

# The parser behind `--suite`: [suite:<name>] sections of a .bashunitrc.

function set_up() {
  RC="$(bashunit::temp_file)"
  # load() memoizes by path, and every test writes a different file into the
  # same one, so the cache key has to be cleared between them.
  _BASHUNIT_SUITES_LOADED_FILE=""
}

function load_rc() { # $1 = file content
  printf '%s\n' "$1" >"$RC"
  _BASHUNIT_SUITES_LOADED_FILE=""
  bashunit::suites::load "$RC"
}

function test_a_section_collects_its_paths_and_options() {
  load_rc '[suite:unit]
paths = tests/unit tests/functional
parallel = true
test-timeout = 60'

  bashunit::suites::resolve "unit"

  assert_same "tests/unit tests/functional" "$_BASHUNIT_SUITE_PATHS_OUT"
  assert_same "--parallel
--test-timeout
60" "$_BASHUNIT_SUITE_ARGS_OUT"
}

function test_underscores_read_as_dashes() {
  load_rc '[suite:unit]
test_timeout = 60'

  bashunit::suites::resolve "unit"

  assert_contains "--test-timeout" "$_BASHUNIT_SUITE_ARGS_OUT"
}

function test_a_false_value_leaves_the_flag_out() {
  load_rc '[suite:unit]
paths = tests/unit
parallel = false'

  bashunit::suites::resolve "unit"

  assert_empty "$_BASHUNIT_SUITE_ARGS_OUT"
}

function test_a_value_may_contain_spaces() {
  load_rc '[suite:unit]
report-md = a report.md'

  bashunit::suites::resolve "unit"

  assert_same "--report-md
a report.md" "$_BASHUNIT_SUITE_ARGS_OUT"
}

function test_names_lists_every_section_in_order() {
  load_rc '[suite:unit]
paths = tests/unit

[suite:acceptance]
paths = tests/acceptance'

  assert_same "unit
acceptance" "$(bashunit::suites::names)"
}

function test_global_settings_outside_a_section_are_ignored_here() {
  load_rc 'BASHUNIT_SHOW_HEADER=false

[suite:unit]
paths = tests/unit'

  bashunit::suites::resolve "unit"

  assert_same "tests/unit" "$_BASHUNIT_SUITE_PATHS_OUT"
  assert_empty "$_BASHUNIT_SUITE_ARGS_OUT"
}

function test_a_non_suite_section_closes_the_previous_one() {
  load_rc '[suite:unit]
paths = tests/unit

[other]
parallel = true'

  bashunit::suites::resolve "unit"

  assert_empty "$_BASHUNIT_SUITE_ARGS_OUT"
}

function test_a_file_without_sections_defines_no_suite() {
  load_rc 'BASHUNIT_SHOW_HEADER=false'

  assert_empty "$(bashunit::suites::names)"
}

function test_comments_are_skipped() {
  load_rc '[suite:unit]
# a comment
; another comment
paths = tests/unit'

  bashunit::suites::resolve "unit"

  assert_same "tests/unit" "$_BASHUNIT_SUITE_PATHS_OUT"
}
