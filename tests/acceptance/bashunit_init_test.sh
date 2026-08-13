#!/usr/bin/env bash
# shellcheck disable=SC2317

set -euo pipefail

BASHUNIT_PATH="$PWD/bashunit"

function set_up() {
  TMP_DIR=$(mktemp -d)
}

function tear_down() {
  rm -rf "$TMP_DIR"
}

function test_bashunit_init_creates_structure() {
  pushd "$TMP_DIR" >/dev/null
  "$BASHUNIT_PATH" init >"$TMP_DIR/init.log"
  assert_file_exists "tests/example_test.sh"
  assert_file_exists "tests/bootstrap.sh"
  popd >/dev/null
}

function test_bashunit_init_custom_directory() {
  pushd "$TMP_DIR" >/dev/null
  "$BASHUNIT_PATH" init custom >"$TMP_DIR/init.log"
  assert_file_exists "custom/example_test.sh"
  assert_file_exists "custom/bootstrap.sh"
  popd >/dev/null
}

function test_bashunit_init_creates_github_workflow() {
  pushd "$TMP_DIR" >/dev/null
  "$BASHUNIT_PATH" init >"$TMP_DIR/init.log"
  assert_file_exists ".github/workflows/tests.yml"
  assert_file_contains ".github/workflows/tests.yml" "TypedDevs/bashunit@"
  popd >/dev/null
}

function test_bashunit_init_does_not_overwrite_existing_workflow() {
  pushd "$TMP_DIR" >/dev/null
  mkdir -p ".github/workflows"
  echo "custom-workflow" >".github/workflows/tests.yml"
  "$BASHUNIT_PATH" init >"$TMP_DIR/init.log"
  assert_file_contains ".github/workflows/tests.yml" "custom-workflow"
  popd >/dev/null
}

function test_bashunit_init_updates_env() {
  bashunit::skip "flaky" && return

  pushd "$TMP_DIR" >/dev/null
  echo "BASHUNIT_BOOTSTRAP=old/bootstrap.sh" >.env
  "$BASHUNIT_PATH" init custom >"$TMP_DIR/init.log"
  assert_file_exists "custom/example_test.sh"
  assert_file_exists "custom/bootstrap.sh"
  assert_file_contains .env "#BASHUNIT_BOOTSTRAP=old/bootstrap.sh"
  assert_file_contains .env "BASHUNIT_BOOTSTRAP=custom/bootstrap.sh"
  popd >/dev/null
}

# `bashunit init` is run more than once in practice -- re-scaffolding, or a
# setup script that is not guarded. The files it writes are idempotent; .env
# was not: every run commented out the previous BASHUNIT_BOOTSTRAP and appended
# a fresh copy, so a third run left three lines, two of them dead (#1175).
function test_bashunit_init_does_not_duplicate_the_bootstrap_setting() {
  pushd "$TMP_DIR" >/dev/null
  "$BASHUNIT_PATH" init >"$TMP_DIR/init.log"
  "$BASHUNIT_PATH" init >>"$TMP_DIR/init.log"
  "$BASHUNIT_PATH" init >>"$TMP_DIR/init.log"

  local active commented
  active=$("$GREP" -c '^BASHUNIT_BOOTSTRAP=' .env || true)
  commented=$("$GREP" -c '^#BASHUNIT_BOOTSTRAP=' .env || true)
  popd >/dev/null

  assert_same 1 "$active"
  assert_same 0 "$commented"
}

# Whatever else lives in .env is the user's and predates bashunit.
function test_bashunit_init_keeps_the_rest_of_an_existing_env_file() {
  pushd "$TMP_DIR" >/dev/null
  printf '%s\n' 'MY_SECRET=keepme' >.env
  "$BASHUNIT_PATH" init >"$TMP_DIR/init.log"
  popd >/dev/null

  assert_file_contains "$TMP_DIR/.env" "MY_SECRET=keepme"
}

# The three scaffolded files are announced; the .env write was not, so a user
# reviewing what init touched before committing would miss it.
function test_bashunit_init_reports_the_env_file_it_writes() {
  pushd "$TMP_DIR" >/dev/null
  "$BASHUNIT_PATH" init >"$TMP_DIR/init.log"
  popd >/dev/null

  assert_file_contains "$TMP_DIR/init.log" ".env"
}
