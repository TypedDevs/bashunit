#!/usr/bin/env bash

# Hits recorded inside a subshell used to vanish. The trap engine collected
# them into a shell variable and only wrote it out every 100 records, so
# everything a short-lived `$( )` recorded died with that subshell: on Bash 5 a
# run of tests/unit/assert/basic_test.sh reported 196 of 236 real hits, while
# Bash 3.2 reported all of them -- the same project measured differently per
# Bash version (#1101).
#
# These pin the property directly rather than through the DEBUG trap, so they
# behave the same on every supported Bash.

function set_up() {
  # shellcheck disable=SC2034  # read by coverage::init
  BASHUNIT_COVERAGE="true"
  # shellcheck disable=SC2034  # read by coverage::init
  BASHUNIT_COVERAGE_PATHS="/"
  # shellcheck disable=SC2034  # read by coverage::init
  BASHUNIT_COVERAGE_EXCLUDE=""
  bashunit::coverage::init
}

function data_file_content() {
  local data_file="$_BASHUNIT_COVERAGE_DATA_FILE"
  if bashunit::parallel::is_enabled; then
    data_file="${_BASHUNIT_COVERAGE_DATA_FILE}.$$"
  fi
  cat "$data_file" 2>/dev/null
}

function test_a_hit_recorded_inside_a_subshell_survives_it() {
  local source_file="/some/path/subshell.sh"

  (bashunit::coverage::record_line "$source_file" "7")

  assert_contains "$source_file:7" "$(data_file_content)"
}

function test_a_hit_recorded_inside_a_command_substitution_survives_it() {
  local source_file="/some/path/cmdsub.sh"

  local _discarded
  _discarded="$(bashunit::coverage::record_line "$source_file" "11" && echo recorded)"

  assert_contains "$source_file:11" "$(data_file_content)"
}

# Fewer records than the old buffer limit, so this failed for the same reason.
function test_a_handful_of_hits_reaches_disk_without_a_flush() {
  local source_file="/some/path/handful.sh"

  local i
  for i in 1 2 3; do
    bashunit::coverage::record_line "$source_file" "$i"
  done

  local content
  content="$(data_file_content)"
  assert_contains "$source_file:1" "$content"
  assert_contains "$source_file:2" "$content"
  assert_contains "$source_file:3" "$content"
}
