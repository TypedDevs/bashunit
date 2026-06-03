#!/usr/bin/env bash

function set_up() {
  BIN="$PWD/bashunit"
  # The outer run inherits an exported BASHUNIT_SHOW_HEADER; clear it so the
  # child process starts without it and the config file can take effect.
  unset BASHUNIT_SHOW_HEADER
  WORKDIR="$(bashunit::temp_dir)/rc_project"
  mkdir -p "$WORKDIR"
  cat >"$WORKDIR/a_test.sh" <<'TEST'
function test_pass() { assert_same 1 1; }
TEST
}

function test_bashunitrc_config_is_applied() {
  printf 'BASHUNIT_SHOW_HEADER=false\n' >"$WORKDIR/.bashunitrc"

  local output
  output=$(cd "$WORKDIR" && "$BIN" --no-parallel --no-color a_test.sh 2>&1) || true

  assert_not_contains "bashunit -" "$output"
  assert_contains "All tests passed" "$output"
}

function test_without_bashunitrc_header_is_shown() {
  rm -f "$WORKDIR/.bashunitrc"

  local output
  output=$(cd "$WORKDIR" && "$BIN" --no-parallel --no-color a_test.sh 2>&1) || true

  assert_contains "bashunit -" "$output"
}

function test_env_var_overrides_bashunitrc() {
  printf 'BASHUNIT_SHOW_HEADER=false\n' >"$WORKDIR/.bashunitrc"

  local output
  output=$(cd "$WORKDIR" && BASHUNIT_SHOW_HEADER=true "$BIN" --no-parallel --no-color a_test.sh 2>&1) || true

  assert_contains "bashunit -" "$output"
}

function test_skip_env_file_skips_bashunitrc() {
  printf 'BASHUNIT_SHOW_HEADER=false\n' >"$WORKDIR/.bashunitrc"

  local output
  output=$(cd "$WORKDIR" && "$BIN" --no-parallel --no-color --skip-env-file a_test.sh 2>&1) || true

  assert_contains "bashunit -" "$output"
}
