#!/usr/bin/env bash

# Named suites in .bashunitrc: a project with several tiers of tests had to
# keep the paths and their flags in a Makefile.

function set_up() {
  BIN="$PWD/bashunit"
  # The outer run exports it; clear it so the project's own config decides.
  unset BASHUNIT_SHOW_HEADER
  WORKDIR="$(bashunit::temp_dir)/suites_project"
  mkdir -p "$WORKDIR/tests/unit" "$WORKDIR/tests/acceptance"
  cat >"$WORKDIR/tests/unit/a_test.sh" <<'TEST'
function test_unit_one() { assert_same 1 1; }
TEST
  cat >"$WORKDIR/tests/acceptance/b_test.sh" <<'TEST'
function test_acceptance_one() { assert_same 1 1; }
TEST
  cat >"$WORKDIR/.bashunitrc" <<'RC'
BASHUNIT_SHOW_HEADER=false

[suite:unit]
paths = tests/unit
parallel = true

[suite:acceptance]
paths = tests/acceptance
no-parallel = true
test-timeout = 60

[suite:all]
paths = tests/unit tests/acceptance
RC
}

function run_in_project() { # $@ = bashunit arguments
  (cd "$WORKDIR" && "$BIN" --no-color "$@" 2>&1) || true
}

function test_a_suite_runs_only_its_own_paths() {
  local output
  output=$(run_in_project --suite unit)

  assert_contains "Unit one" "$output"
  assert_not_contains "Acceptance one" "$output"
}

function test_repeated_suites_run_the_union_of_their_paths() {
  local output
  output=$(run_in_project --suite unit --suite acceptance)

  assert_contains "Unit one" "$output"
  assert_contains "Acceptance one" "$output"
}

function test_a_cli_flag_beats_the_suite_setting() {
  local output
  # The suite asks for --parallel; the explicit flag must win, which the
  # summary shows by rendering the sequential per-test lines.
  output=$(run_in_project --suite unit --no-parallel --verbose)

  local line
  line=$(printf '%s\n' "$output" | "$GREP" "BASHUNIT_PARALLEL_RUN:")
  assert_contains "false" "$line"
}

function test_an_unknown_suite_lists_the_defined_ones() {
  local ec=0
  local output
  output=$( (cd "$WORKDIR" && "$BIN" --no-color --suite nope tests/unit 2>&1) ) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "unknown suite 'nope'" "$output"
  assert_contains "unit" "$output"
  assert_contains "acceptance" "$output"
}

function test_list_suites_prints_the_names_and_exits_zero() {
  local ec=0
  local output
  output=$( (cd "$WORKDIR" && "$BIN" --no-color --list-suites 2>&1) ) || ec=$?

  assert_successful_code "" "" "$ec"
  assert_contains "unit" "$output"
  assert_contains "acceptance" "$output"
  assert_contains "all" "$output"
}

# Documented precedence: an explicit path replaces the suite's paths, the same
# way an explicit flag replaces a suite option.
function test_an_explicit_path_replaces_the_suite_paths() {
  local output
  output=$(run_in_project --suite unit tests/acceptance)

  assert_contains "Acceptance one" "$output"
  assert_not_contains "Unit one" "$output"
}

function test_a_bashunitrc_without_suites_behaves_as_before() {
  printf 'BASHUNIT_SHOW_HEADER=false\n' >"$WORKDIR/.bashunitrc"

  local output
  output=$(run_in_project tests/unit)

  assert_contains "Unit one" "$output"
  assert_not_contains "bashunit -" "$output"
}

function test_a_malformed_suite_section_quotes_the_offending_line() {
  cat >"$WORKDIR/.bashunitrc" <<'RC'
[suite:broken]
paths = tests/unit
this line has no equals sign
RC

  local ec=0
  local output
  output=$( (cd "$WORKDIR" && "$BIN" --no-color --suite broken 2>&1) ) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "this line has no equals sign" "$output"
}

function test_an_unknown_suite_option_is_rejected() {
  cat >"$WORKDIR/.bashunitrc" <<'RC'
[suite:broken]
paths = tests/unit
not-a-real-flag = true
RC

  local ec=0
  local output
  output=$( (cd "$WORKDIR" && "$BIN" --no-color --suite broken 2>&1) ) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "not-a-real-flag" "$output"
}

function test_suite_options_carry_values_with_spaces() {
  cat >"$WORKDIR/.bashunitrc" <<'RC'
[suite:spaced]
paths = tests/unit
report-md = a report with spaces.md
RC

  run_in_project --suite spaced >/dev/null

  assert_file_exists "$WORKDIR/a report with spaces.md"
}
