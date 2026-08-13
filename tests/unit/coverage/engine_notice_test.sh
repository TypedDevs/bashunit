#!/usr/bin/env bash

# Before Bash 4 the DEBUG trap does not reach a subshell even under `set -T`,
# so lines run inside ( ), $( ) or <( ) are never recorded and the percentage
# comes out lower than the same project measures on Bash 4+. The numbers give
# no hint of it, so `--verbose` says so next to the engine it already reports
# (#1112).

function set_up() {
  # shellcheck disable=SC2034  # read by the header under test
  BASHUNIT_VERBOSE=true
  # shellcheck disable=SC2034  # read by coverage::init
  BASHUNIT_COVERAGE="true"
}

function header_output() {
  bashunit::coverage::print_engine_notice 2>&1
}

function test_the_note_names_the_running_bash_when_it_is_older_than_four() {
  if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
    bashunit::skip "the note is only for Bash 3.x" && return
  fi

  local output
  output="$(header_output)"

  assert_contains "does not report lines run inside a subshell" "$output"
  assert_contains "Bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}" "$output"
}

function test_bash_four_and_newer_get_no_note() {
  if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
    bashunit::skip "the note is expected on Bash 3.x" && return
  fi

  local output
  output="$(header_output)"

  assert_not_contains "does not report lines run inside a subshell" "$output"
}

function test_the_note_is_verbose_only() {
  # shellcheck disable=SC2034  # read by the notice under test
  BASHUNIT_VERBOSE=false

  local output
  output="$(header_output)"

  assert_not_contains "does not report lines run inside a subshell" "$output"
}
