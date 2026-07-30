#!/usr/bin/env bash

function test_functions_for_script_sorts_by_definition_line() {
  local fixture
  fixture="$(bashunit::temp_dir)/ffs_order_fixture.sh"
  {
    echo 'function test_zebra() { :; }'
    echo 'function test_alpha() { :; }'
    echo 'function test_mid() { :; }'
  } >"$fixture"
  # shellcheck source=/dev/null
  source "$fixture"

  local actual
  actual="$(bashunit::runner::functions_for_script "$fixture" "test_alpha test_mid test_zebra")"

  assert_same $'test_zebra\ntest_alpha\ntest_mid' "$actual"
}

function test_functions_for_script_filters_out_functions_from_other_files() {
  local fixture
  fixture="$(bashunit::temp_dir)/ffs_filter_fixture.sh"
  echo 'function test_only_mine() { :; }' >"$fixture"
  # shellcheck source=/dev/null
  source "$fixture"

  # test_functions_for_script_filters_out_functions_from_other_files is defined
  # in this test file, not in the fixture, so it must be filtered out.
  local actual
  actual="$(bashunit::runner::functions_for_script "$fixture" \
    "test_only_mine test_functions_for_script_filters_out_functions_from_other_files")"

  assert_same "test_only_mine" "$actual"
}

function test_functions_for_script_preserves_caller_extdebug_state() {
  local fixture
  fixture="$(bashunit::temp_dir)/ffs_extdebug_fixture.sh"
  echo 'function test_ffs_extdebug() { :; }' >"$fixture"
  # shellcheck source=/dev/null
  source "$fixture"

  # Toggle inside a subshell so the runner's own shell is never touched.
  local state
  state=$(
    shopt -s extdebug
    bashunit::runner::functions_for_script "$fixture" "test_ffs_extdebug" >/dev/null
    if shopt -q extdebug; then echo "on"; else echo "off"; fi
  )

  assert_same "on" "$state"
}
