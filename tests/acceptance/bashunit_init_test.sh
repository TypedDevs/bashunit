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

# A bootstrap that fails to load left the run with nothing: no tests, no
# summary, and exit 0 -- so CI passed having executed nothing. The file is
# optional (BASHUNIT_BOOTSTRAP defaults to tests/bootstrap.sh, which most
# projects do not have), but a file that exists and is broken is a different
# thing from one that is absent (#1179).
function test_a_bootstrap_with_a_syntax_error_fails_the_run() {
  pushd "$TMP_DIR" >/dev/null
  printf 'function broken( {\n' >boot.sh
  printf 'function test_ok() { assert_same 1 1; }\n' >t_test.sh

  local ec=0
  local output
  output=$(BASHUNIT_BOOTSTRAP=boot.sh "$BASHUNIT_PATH" --no-parallel t_test.sh 2>&1) || ec=$?
  popd >/dev/null

  assert_general_error "" "" "$ec"
  assert_contains "bootstrap" "$output"
}

function test_a_bootstrap_that_exits_non_zero_says_so() {
  pushd "$TMP_DIR" >/dev/null
  printf 'exit 3\n' >boot.sh
  printf 'function test_ok() { assert_same 1 1; }\n' >t_test.sh

  local ec=0
  local output
  output=$(BASHUNIT_BOOTSTRAP=boot.sh "$BASHUNIT_PATH" --no-parallel t_test.sh 2>&1) || ec=$?
  popd >/dev/null

  assert_not_same 0 "$ec"
  assert_contains "bootstrap" "$output"
}

# An absent bootstrap stays silent: the default path is one most projects do
# not have, and failing on it would break every one of them.
function test_an_absent_bootstrap_is_still_ignored() {
  pushd "$TMP_DIR" >/dev/null
  printf 'function test_ok() { assert_same 1 1; }\n' >t_test.sh

  local ec=0
  local output
  output=$(BASHUNIT_BOOTSTRAP=tests/bootstrap.sh "$BASHUNIT_PATH" --no-parallel t_test.sh 2>&1) || ec=$?
  popd >/dev/null

  assert_same 0 "$ec"
  assert_not_contains "bootstrap" "$output"
}

# #1180 covered the BASHUNIT_BOOTSTRAP env path. The --env/--boot *flag* sources
# its file at a different call site, and had the same hole: exit 0, no tests,
# no summary (#1181).
function test_an_env_flag_file_with_a_syntax_error_fails_the_run() {
  pushd "$TMP_DIR" >/dev/null
  printf 'function broken( {\n' >boot.sh
  printf 'function test_ok() { assert_same 1 1; }\n' >t_test.sh

  local ec=0
  local output
  output=$("$BASHUNIT_PATH" --no-parallel --env boot.sh t_test.sh 2>&1) || ec=$?
  popd >/dev/null

  assert_general_error "" "" "$ec"
  assert_contains "bootstrap" "$output"
}

function test_an_env_flag_file_that_exits_says_so() {
  pushd "$TMP_DIR" >/dev/null
  printf 'exit 3\n' >boot.sh
  printf 'function test_ok() { assert_same 1 1; }\n' >t_test.sh

  local ec=0
  local output
  output=$("$BASHUNIT_PATH" --no-parallel --env boot.sh t_test.sh 2>&1) || ec=$?
  popd >/dev/null

  assert_not_same 0 "$ec"
  assert_contains "bootstrap" "$output"
}

# `--env` takes "file arg1 arg2", so it splits its value on the first space.
# That is deliberate, and it makes a path containing a space unusable -- but
# the message named a truncated path the user never typed:
#
#   Error: cannot read the bootstrap file: 'my'.
#
# for `--env "my boot.sh"`. The file is right there, so the reader is told
# their existing file does not exist. Explain the split and name the way out.
function test_an_env_path_with_a_space_explains_the_split() {
  pushd "$TMP_DIR" >/dev/null
  printf 'BASHUNIT_SHOW_HEADER=false\n' >"my boot.sh"
  printf 'function test_ok() { assert_same 1 1; }\n' >t_test.sh

  local ec=0
  local output
  output=$("$BASHUNIT_PATH" --no-parallel --env "my boot.sh" t_test.sh 2>&1) || ec=$?
  popd >/dev/null

  assert_general_error "" "" "$ec"
  assert_contains "space" "$output"
  assert_contains "BASHUNIT_BOOTSTRAP" "$output"
}

# The advice has to work: the env var is not split, so it takes the path whole.
function test_the_bootstrap_env_var_accepts_a_path_with_a_space() {
  pushd "$TMP_DIR" >/dev/null
  printf 'BASHUNIT_SHOW_HEADER=false\n' >"my boot.sh"
  printf 'function test_ok() { assert_same 1 1; }\n' >t_test.sh

  local ec=0
  local output
  output=$(BASHUNIT_BOOTSTRAP="my boot.sh" "$BASHUNIT_PATH" --no-parallel t_test.sh 2>&1) || ec=$?
  popd >/dev/null

  assert_same 0 "$ec"
  assert_contains "1 passed" "$output"
}

# A genuinely missing file, with no space involved, keeps the plain message:
# the explanation must not fire where it would be noise.
function test_a_missing_env_file_without_a_space_stays_terse() {
  pushd "$TMP_DIR" >/dev/null
  printf 'function test_ok() { assert_same 1 1; }\n' >t_test.sh

  local ec=0
  local output
  output=$("$BASHUNIT_PATH" --no-parallel --env absent.sh t_test.sh 2>&1) || ec=$?
  popd >/dev/null

  assert_general_error "" "" "$ec"
  assert_contains "cannot read the bootstrap file" "$output"
  assert_not_contains "BASHUNIT_BOOTSTRAP" "$output"
}

# Passing arguments after the file is the reason for the split, so it must keep
# working: the file resolves and the explanation stays quiet.
function test_env_arguments_after_the_file_still_work() {
  pushd "$TMP_DIR" >/dev/null
  printf 'BASHUNIT_BOOT_ARG="$1"\n' >boot.sh
  printf 'function test_ok() { assert_same 1 1; }\n' >t_test.sh

  local ec=0
  local output
  output=$("$BASHUNIT_PATH" --no-parallel --env "boot.sh hello" t_test.sh 2>&1) || ec=$?
  popd >/dev/null

  assert_same 0 "$ec"
  assert_not_contains "cannot read the bootstrap file" "$output"
}

# A healthy --env file must still be sourced and its values reach the run.
function test_a_healthy_env_flag_file_still_loads() {
  pushd "$TMP_DIR" >/dev/null
  printf 'BASHUNIT_SHOW_HEADER=false\n' >boot.sh
  printf 'function test_ok() { assert_same 1 1; }\n' >t_test.sh

  local ec=0
  local output
  output=$("$BASHUNIT_PATH" --no-parallel --env boot.sh t_test.sh 2>&1) || ec=$?
  popd >/dev/null

  assert_same 0 "$ec"
  assert_contains "1 passed" "$output"
}
