#!/usr/bin/env bash

# `.env` is loaded with `set -o allexport; source .env`, so every line is an
# unconditional assignment. Listing a name with an empty value therefore
# OVERRODE a value the caller exported, which meant a project could not document
# a setting in .env/.env.example without breaking it on the command line (#865).
#
# An empty entry now means "not configured here" and leaves the caller's value
# alone, matching how .bashunitrc already applies values (`${key:-val}`).
# A non-empty entry still wins, which is what a project config is for.

BASHUNIT_PATH="$PWD/bashunit"

function set_up() {
  WORK_DIR=$(mktemp -d)
  printf '#!/usr/bin/env bash\n\nfunction test_ok() {\n  assert_same "1" "1"\n}\n' \
    >"$WORK_DIR/probe_test.sh"
}

function tear_down() {
  rm -rf "$WORK_DIR"
}

function test_an_empty_env_entry_does_not_override_an_exported_value() {
  printf 'BASHUNIT_OUTPUT_FORMAT=\n' >"$WORK_DIR/.env"

  local output
  pushd "$WORK_DIR" >/dev/null || return 1
  output=$(BASHUNIT_OUTPUT_FORMAT=tap "$BASHUNIT_PATH" . 2>&1) || true
  popd >/dev/null || return 1

  assert_contains "TAP version 13" "$output"
}

function test_a_non_empty_env_entry_still_applies() {
  printf 'BASHUNIT_OUTPUT_FORMAT=tap\n' >"$WORK_DIR/.env"

  local output
  pushd "$WORK_DIR" >/dev/null || return 1
  output=$("$BASHUNIT_PATH" . 2>&1) || true
  popd >/dev/null || return 1

  assert_contains "TAP version 13" "$output"
}

# A project that pins a value must still win over the ambient environment: an
# empty caller value is not a deliberate choice, so the .env entry applies.
function test_a_non_empty_env_entry_applies_over_an_empty_exported_value() {
  printf 'BASHUNIT_OUTPUT_FORMAT=tap\n' >"$WORK_DIR/.env"

  local output
  pushd "$WORK_DIR" >/dev/null || return 1
  output=$(BASHUNIT_OUTPUT_FORMAT='' "$BASHUNIT_PATH" . 2>&1) || true
  popd >/dev/null || return 1

  assert_contains "TAP version 13" "$output"
}

function test_env_file_still_sets_a_value_the_caller_did_not_provide() {
  printf 'BASHUNIT_OUTPUT_FORMAT=tap\n' >"$WORK_DIR/.env"

  local output
  pushd "$WORK_DIR" >/dev/null || return 1
  output=$("$BASHUNIT_PATH" . 2>&1) || true
  popd >/dev/null || return 1

  assert_contains "ok 1 - Ok" "$output"
}
