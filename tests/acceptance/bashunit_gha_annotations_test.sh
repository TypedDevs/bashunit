#!/usr/bin/env bash

# GitHub parses workflow commands from the job log, so an annotation only lands
# on a pull request if it reaches stdout. Writing it to a file nobody cats
# produced exactly zero annotations.
#
# Clearing _BASHUNIT_GHA_ANNOTATIONS_CLAIMED below is how a nested run says
# "pretend I am the top-level one": this suite is itself a bashunit run and has
# already claimed the job log for its process tree, which is the very pollution
# the marker exists to prevent. A run that claims top-level also claims
# $GITHUB_STEP_SUMMARY, so it is pinned empty alongside or the fixtures'
# summaries would land on the real job page under CI.

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh"
}

function test_annotations_reach_stdout_inside_github_actions() {
  local output
  output="$(_BASHUNIT_GHA_ANNOTATIONS_CLAIMED='' GITHUB_STEP_SUMMARY='' GITHUB_ACTIONS=true \
    ./bashunit --no-parallel --no-color \
    --env "$TEST_ENV_FILE" "$FIXTURE")" || true

  assert_contains "::error file=$FIXTURE" "$output"
  assert_contains "title=Failure" "$output"
}

function test_the_annotation_carries_the_failing_line() {
  local output
  output="$(_BASHUNIT_GHA_ANNOTATIONS_CLAIMED='' GITHUB_STEP_SUMMARY='' GITHUB_ACTIONS=true \
    ./bashunit --no-parallel --no-color \
    --env "$TEST_ENV_FILE" "$FIXTURE")" || true

  assert_matches "::error file=[^,]*,line=[0-9]+,title=" "$output"
}

function test_nothing_extra_is_printed_outside_github_actions() {
  local output
  output="$(GITHUB_ACTIONS='' ./bashunit --no-parallel --no-color \
    --env "$TEST_ENV_FILE" "$FIXTURE")" || true

  assert_not_contains "::error" "$output"
}

# The claim marker is left alone here, so this is a genuinely nested run. Under
# CI it inherits GITHUB_ACTIONS=true and must still stay quiet, or every nested
# run in a suite would annotate the parent's log with its own fixtures.
function test_a_nested_run_never_annotates_the_parents_log() {
  local output
  output="$(GITHUB_ACTIONS=true ./bashunit --no-parallel --no-color \
    --env "$TEST_ENV_FILE" "$FIXTURE")" || true

  assert_not_contains "::error" "$output"
}

function test_never_suppresses_annotations_inside_github_actions() {
  local output
  output="$(_BASHUNIT_GHA_ANNOTATIONS_CLAIMED='' GITHUB_STEP_SUMMARY='' GITHUB_ACTIONS=true \
    ./bashunit --no-parallel --no-color \
    --env "$TEST_ENV_FILE" --gha-annotations never "$FIXTURE")" || true

  assert_not_contains "::error" "$output"
}

function test_always_emits_annotations_outside_github_actions() {
  local output
  output="$(./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --gha-annotations always "$FIXTURE")" || true

  assert_contains "::error file=$FIXTURE" "$output"
}

function test_a_multi_line_message_stays_one_annotation() {
  local output
  output="$(_BASHUNIT_GHA_ANNOTATIONS_CLAIMED='' GITHUB_STEP_SUMMARY='' GITHUB_ACTIONS=true \
    ./bashunit --no-parallel --no-color \
    --env "$TEST_ENV_FILE" "$FIXTURE")" || true

  # One failing test, so one ::error line, with the newlines percent-encoded.
  assert_same "1" "$(printf '%s\n' "$output" | grep -c '^::error' | tr -d ' ')"
  assert_contains "%0A" "$output"
}

function test_log_gha_still_writes_the_file_without_duplicating_stdout() {
  local log_file
  log_file="$(bashunit::temp_file)"

  local output
  output="$(_BASHUNIT_GHA_ANNOTATIONS_CLAIMED='' GITHUB_STEP_SUMMARY='' GITHUB_ACTIONS=true \
    ./bashunit --no-parallel --no-color \
    --env "$TEST_ENV_FILE" --log-gha "$log_file" "$FIXTURE")" || true

  assert_contains "::error" "$(cat "$log_file")"
  assert_same "1" "$(printf '%s\n' "$output" | grep -c '^::error' | tr -d ' ')"
}

function test_annotations_survive_parallel_aggregation() {
  local output
  output="$(_BASHUNIT_GHA_ANNOTATIONS_CLAIMED='' GITHUB_STEP_SUMMARY='' GITHUB_ACTIONS=true \
    ./bashunit --parallel --no-color \
    --env "$TEST_ENV_FILE" "$FIXTURE")" || true

  assert_contains "::error file=$FIXTURE" "$output"
}

function test_log_gha_appears_in_the_help() {
  assert_contains "--log-gha" "$(./bashunit test --help)"
}

function test_an_unknown_mode_is_a_usage_error() {
  local ec=0
  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --gha-annotations sometimes "$FIXTURE" 2>&1)" || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "sometimes" "$output"
  assert_contains "auto, always, never" "$output"
}

# GitHub splits an annotation's properties on `,` and its key from its value on
# `=`, so a property VALUE carries a stricter rule than the message: `:` and `,`
# must be percent-encoded too. A custom title containing a comma ended the title
# there and turned the rest into an invented property.
function test_a_comma_in_a_custom_title_does_not_split_the_properties() {
  local dir
  dir="$(bashunit::temp_dir gha_title_comma)"
  {
    printf 'function test_titled() {\n'
    printf '  bashunit::set_test_title "Rejects a,b when x:y is set"\n'
    printf '  assert_same "expected" "actual"\n'
    printf '}\n'
  } >"$dir/title_test.sh"

  local output
  output="$(_BASHUNIT_GHA_ANNOTATIONS_CLAIMED='' GITHUB_STEP_SUMMARY='' GITHUB_ACTIONS=true \
    ./bashunit --no-parallel --no-color \
    --env "$TEST_ENV_FILE" "$dir/title_test.sh")" || true

  local annotation
  annotation="$(printf '%s\n' "$output" | grep '^::error' | head -1)"
  # Everything before the `::` that starts the message is the property list.
  local props="${annotation%%::*}"
  props="${annotation#::error }"
  props="${props%%::*}"

  assert_not_contains "a,b" "$props"
  assert_contains "%2C" "$props"
  assert_contains "%3A" "$props"
}
