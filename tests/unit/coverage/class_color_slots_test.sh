#!/usr/bin/env bash

# The report picks a class and a colour once per file and once per function. It
# used to do that in a subshell, which cost more than every other thing the text
# report did: 168ms of 253ms at 128 files (#1092). The slots below are the same
# decision without the fork, so they have to agree with the stdout helpers
# exactly -- these pin them together, including on the threshold boundaries.

function set_up() {
  # shellcheck disable=SC2034  # read by the class helpers under test
  BASHUNIT_COVERAGE_THRESHOLD_HIGH=80
  # shellcheck disable=SC2034  # read by the class helpers under test
  BASHUNIT_COVERAGE_THRESHOLD_LOW=50
}

# @data_provider percentages
function test_the_class_slot_agrees_with_the_stdout_helper() {
  local pct="$1"

  bashunit::coverage::class_to_slot "$pct"

  assert_same "$(bashunit::coverage::get_coverage_class "$pct")" \
    "$_BASHUNIT_COVERAGE_CLASS_OUT"
}

# @data_provider percentages
function test_the_colour_slot_agrees_with_the_stdout_helper() {
  local pct="$1"

  local class
  class="$(bashunit::coverage::get_coverage_class "$pct")"
  bashunit::coverage::color_to_slot "$class"

  assert_same "$(bashunit::coverage::get_color_for_class "$class")" \
    "$_BASHUNIT_COVERAGE_COLOR_OUT"
}

function percentages() {
  echo 0
  echo 49
  echo 50
  echo 79
  echo 80
  echo 100
}

function test_the_class_slot_follows_the_configured_thresholds() {
  # shellcheck disable=SC2034  # read by the class helpers under test
  BASHUNIT_COVERAGE_THRESHOLD_HIGH=95
  # shellcheck disable=SC2034  # read by the class helpers under test
  BASHUNIT_COVERAGE_THRESHOLD_LOW=90

  bashunit::coverage::class_to_slot 94
  assert_same "medium" "$_BASHUNIT_COVERAGE_CLASS_OUT"

  bashunit::coverage::class_to_slot 95
  assert_same "high" "$_BASHUNIT_COVERAGE_CLASS_OUT"

  bashunit::coverage::class_to_slot 89
  assert_same "low" "$_BASHUNIT_COVERAGE_CLASS_OUT"
}

# An unknown class is not a colour. The stdout helper printed nothing for it,
# so the slot must be emptied rather than left holding the previous caller's.
function test_an_unknown_class_clears_the_colour_slot() {
  bashunit::coverage::color_to_slot "high"
  assert_not_empty "$_BASHUNIT_COVERAGE_COLOR_OUT"

  bashunit::coverage::color_to_slot "nonsense"

  assert_empty "$_BASHUNIT_COVERAGE_COLOR_OUT"
}
