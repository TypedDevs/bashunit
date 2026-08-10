#!/usr/bin/env bash

# GitHub parses workflow commands from the job log, so an annotation only lands
# on a pull request if it reaches stdout. Writing it to a file nobody cats
# produced exactly zero annotations.

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh"
}

function test_annotations_reach_stdout_inside_github_actions() {
  local output
  output="$(GITHUB_ACTIONS=true ./bashunit --no-parallel --no-color \
    --env "$TEST_ENV_FILE" "$FIXTURE")" || true

  assert_contains "::error file=$FIXTURE" "$output"
  assert_contains "title=Failure" "$output"
}

function test_the_annotation_carries_the_failing_line() {
  local output
  output="$(GITHUB_ACTIONS=true ./bashunit --no-parallel --no-color \
    --env "$TEST_ENV_FILE" "$FIXTURE")" || true

  assert_matches "::error file=[^,]*,line=[0-9]+,title=" "$output"
}

function test_nothing_extra_is_printed_outside_github_actions() {
  local output
  output="$(./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" "$FIXTURE")" || true

  assert_not_contains "::error" "$output"
}

function test_never_suppresses_annotations_inside_github_actions() {
  local output
  output="$(GITHUB_ACTIONS=true ./bashunit --no-parallel --no-color \
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
  output="$(GITHUB_ACTIONS=true ./bashunit --no-parallel --no-color \
    --env "$TEST_ENV_FILE" "$FIXTURE")" || true

  # One failing test, so one ::error line, with the newlines percent-encoded.
  assert_same "1" "$(printf '%s\n' "$output" | grep -c '^::error' | tr -d ' ')"
  assert_contains "%0A" "$output"
}

function test_log_gha_still_writes_the_file_without_duplicating_stdout() {
  local log_file
  log_file="$(bashunit::temp_file)"

  local output
  output="$(GITHUB_ACTIONS=true ./bashunit --no-parallel --no-color \
    --env "$TEST_ENV_FILE" --log-gha "$log_file" "$FIXTURE")" || true

  assert_contains "::error" "$(cat "$log_file")"
  assert_same "1" "$(printf '%s\n' "$output" | grep -c '^::error' | tr -d ' ')"
}

function test_annotations_survive_parallel_aggregation() {
  local output
  output="$(GITHUB_ACTIONS=true ./bashunit --parallel --no-color \
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
