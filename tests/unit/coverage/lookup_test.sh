#!/usr/bin/env bash

# The hot-path lookups behind should_track, path normalization and the stats
# cache. They used to be one long string scanned with a leading-`*` glob, which
# is quadratic on Bash 3.2: 0.38ms per lookup at 11 entries, 26.7ms at 121 --
# the cache cost more than the work it replaced (#1056).

function tear_down() {
  bashunit::coverage::reset_lookup_namespace "_BASHUNIT_COVLOOKUP_TEST_"
}

function test_a_stored_value_is_read_back() {
  bashunit::coverage::lookup_put "_BASHUNIT_COVLOOKUP_TEST_" "/src/a.sh" "1"

  bashunit::coverage::lookup_get "_BASHUNIT_COVLOOKUP_TEST_" "/src/a.sh"

  assert_same "1" "$_BASHUNIT_COVERAGE_LOOKUP_OUT"
}

function test_an_absent_key_is_a_miss() {
  local ec=0
  bashunit::coverage::lookup_get "_BASHUNIT_COVLOOKUP_TEST_" "/src/never.sh" || ec=$?

  assert_equals "1" "$ec"
  assert_empty "$_BASHUNIT_COVERAGE_LOOKUP_OUT"
}

# The key collapses everything but [a-zA-Z0-9] to `_`, so these two paths share
# one key. The stored path is compared on read, which turns a collision into a
# miss instead of the previous file's answer.
function test_two_paths_sharing_a_key_do_not_answer_for_each_other() {
  bashunit::coverage::lookup_put "_BASHUNIT_COVLOOKUP_TEST_" "/src/a-b.sh" "1"

  local ec=0
  bashunit::coverage::lookup_get "_BASHUNIT_COVLOOKUP_TEST_" "/src/a_b.sh" || ec=$?

  assert_equals "1" "$ec"
}

function test_a_value_with_spaces_survives() {
  bashunit::coverage::lookup_put "_BASHUNIT_COVLOOKUP_TEST_" "/src/a.sh" "/tmp/a dir/a.sh"

  bashunit::coverage::lookup_get "_BASHUNIT_COVLOOKUP_TEST_" "/src/a.sh"

  assert_same "/tmp/a dir/a.sh" "$_BASHUNIT_COVERAGE_LOOKUP_OUT"
}

function test_resetting_a_namespace_drops_its_entries() {
  bashunit::coverage::lookup_put "_BASHUNIT_COVLOOKUP_TEST_" "/src/a.sh" "1"

  bashunit::coverage::reset_lookup_namespace "_BASHUNIT_COVLOOKUP_TEST_"

  local ec=0
  bashunit::coverage::lookup_get "_BASHUNIT_COVLOOKUP_TEST_" "/src/a.sh" || ec=$?
  assert_equals "1" "$ec"
}

# The namespaces are deliberately _BASHUNIT_COVLOOKUP_*, not
# _BASHUNIT_COVERAGE_*: `compgen -v` matches by prefix, so resetting
# "_BASHUNIT_COVERAGE_TRACKED_" would also unset _BASHUNIT_COVERAGE_TRACKED_FILES
# -- the real config value the report and the cleanup both read.
function test_resetting_a_namespace_leaves_the_coverage_config_alone() {
  local original="${_BASHUNIT_COVERAGE_TRACKED_FILES:-}"
  _BASHUNIT_COVERAGE_TRACKED_FILES="/tmp/files.dat"

  bashunit::coverage::reset_lookup_namespace "_BASHUNIT_COVLOOKUP_TRACK_"
  bashunit::coverage::reset_lookup_namespace "_BASHUNIT_COVLOOKUP_PATH_"
  bashunit::coverage::reset_lookup_namespace "_BASHUNIT_COVLOOKUP_STATS_"

  local kept="$_BASHUNIT_COVERAGE_TRACKED_FILES"
  _BASHUNIT_COVERAGE_TRACKED_FILES="$original"

  assert_same "/tmp/files.dat" "$kept"
}
