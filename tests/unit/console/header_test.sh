#!/usr/bin/env bash

# shellcheck disable=SC2155

function test_print_help_contains_usage() {
  local output
  output=$(bashunit::console_header::print_help)

  assert_contains "Usage:" "$output"
  assert_contains "bashunit" "$output"
}

function test_print_help_contains_commands() {
  local output
  output=$(bashunit::console_header::print_help)

  assert_contains "Commands:" "$output"
  assert_contains "test" "$output"
  assert_contains "bench" "$output"
  assert_contains "assert" "$output"
  assert_contains "doc" "$output"
  assert_contains "init" "$output"
  assert_contains "learn" "$output"
  assert_contains "watch" "$output"
  assert_contains "upgrade" "$output"
}

function test_print_help_contains_examples() {
  local output
  output=$(bashunit::console_header::print_help)

  assert_contains "Examples:" "$output"
}

function test_print_test_help_contains_options() {
  local output
  output=$(bashunit::console_header::print_test_help)

  assert_contains "Options:" "$output"
  assert_contains "--filter" "$output"
  assert_contains "--parallel" "$output"
  assert_contains "--verbose" "$output"
  assert_contains "Coverage:" "$output"
}

function test_print_bench_help_contains_usage() {
  local output
  output=$(bashunit::console_header::print_bench_help)

  assert_contains "Usage: bashunit bench" "$output"
  assert_contains "Examples:" "$output"
}

function test_print_doc_help_contains_usage() {
  local output
  output=$(bashunit::console_header::print_doc_help)

  assert_contains "Usage: bashunit doc" "$output"
  assert_contains "filter" "$output"
}

function test_print_init_help_contains_usage() {
  local output
  output=$(bashunit::console_header::print_init_help)

  assert_contains "Usage: bashunit init" "$output"
  assert_contains "bootstrap.sh" "$output"
}

function test_print_learn_help_contains_lessons() {
  local output
  output=$(bashunit::console_header::print_learn_help)

  assert_contains "Usage: bashunit learn" "$output"
  assert_contains "tutorial" "$output"
}

function test_print_upgrade_help_contains_usage() {
  local output
  output=$(bashunit::console_header::print_upgrade_help)

  assert_contains "Usage: bashunit upgrade" "$output"
}

function test_print_assert_help_contains_examples() {
  local output
  output=$(bashunit::console_header::print_assert_help)

  assert_contains "Usage: bashunit assert" "$output"
  assert_contains "equals" "$output"
}

function test_print_watch_help_contains_requirements() {
  local output
  output=$(bashunit::console_header::print_watch_help)

  assert_contains "Usage: bashunit watch" "$output"
  assert_contains "fswatch" "$output"
  assert_contains "inotifywait" "$output"
}

function test_print_version_with_env_returns_empty_when_header_disabled() {
  local original="$BASHUNIT_SHOW_HEADER"
  export BASHUNIT_SHOW_HEADER="false"

  local output
  output=$(bashunit::console_header::print_version_with_env "")

  assert_empty "$output"

  export BASHUNIT_SHOW_HEADER="$original"
}

function test_print_version_shows_version_string() {
  local output
  output=$(bashunit::console_header::print_version "" "dummy_file.sh")

  assert_contains "$BASHUNIT_VERSION" "$output"
}
