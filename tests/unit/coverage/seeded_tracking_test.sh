#!/usr/bin/env bash

# A source file entered the tracked list the first time one of its lines
# executed, so a file no test ever reached was absent from the report and could
# not lower the percentage. Coverage was measured over the files that ran, not
# over the files the user asked about (#1053).

function set_up() {
  WORK="$(bashunit::temp_dir)/seed"
  mkdir -p "$WORK/src/sub"
  printf 'function ran() {\n  echo "yes"\n}\n' >"$WORK/src/ran.sh"
  printf 'function never() {\n  echo "no"\n}\n' >"$WORK/src/never.sh"
  printf 'function nested() {\n  echo "deep"\n}\n' >"$WORK/src/sub/nested.sh"
  printf 'function helper() {\n  echo "x"\n}\n' >"$WORK/src/helper_test.sh"

  _ORIG_PATHS="${BASHUNIT_COVERAGE_PATHS:-}"
  _ORIG_EXCLUDE="${BASHUNIT_COVERAGE_EXCLUDE:-}"
  _ORIG_COVERAGE="${BASHUNIT_COVERAGE:-false}"
}

function tear_down() {
  BASHUNIT_COVERAGE_PATHS="$_ORIG_PATHS"
  BASHUNIT_COVERAGE_EXCLUDE="$_ORIG_EXCLUDE"
  BASHUNIT_COVERAGE="$_ORIG_COVERAGE"
}

function seed_with() { # $1 = paths, $2 = excludes
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_PATHS="$1"
  BASHUNIT_COVERAGE_EXCLUDE="${2:-}"
  bashunit::coverage::init
  # Seeding happens once, at report time: the denominator is a reporting
  # concern, and doing it in init made every capture-only run walk the project.
  bashunit::coverage::seed_tracked_files
  bashunit::coverage::get_tracked_files
}

function test_a_file_no_test_executed_is_tracked_from_the_start() {
  local tracked
  tracked=$(seed_with "$WORK/src")

  assert_contains "never.sh" "$tracked"
}

function test_seeding_descends_into_subdirectories() {
  local tracked
  tracked=$(seed_with "$WORK/src")

  assert_contains "sub/nested.sh" "$tracked"
}

function test_the_exclude_patterns_remove_a_seeded_file() {
  local tracked
  tracked=$(seed_with "$WORK/src" "*_test.sh")

  assert_not_contains "helper_test.sh" "$tracked"
  assert_contains "never.sh" "$tracked"
}

function test_a_single_file_path_is_seeded() {
  local tracked
  tracked=$(seed_with "$WORK/src/never.sh")

  assert_contains "never.sh" "$tracked"
  assert_not_contains "ran.sh" "$tracked"
}

# Seeded paths are normalized, because the capture path records normalized
# paths: the same file listed twice reports once with no hits at all.
function test_a_seeded_path_is_absolute() {
  local tracked
  tracked=$(seed_with "$WORK/src")

  assert_not_contains "./" "$tracked"
  # Normalized, so the expectation has to be too: $TMPDIR can carry a trailing
  # slash, and the seed collapses it exactly as the capture path does.
  assert_contains "$(bashunit::coverage::normalize_path "$WORK/src/never.sh")" "$tracked"
}

# Defined behaviour: seeding happens once, before the run. A file that appears
# afterwards is still tracked if it executes, but is not seeded.
function test_a_file_created_after_seeding_is_not_seeded() {
  local tracked
  tracked=$(seed_with "$WORK/src")
  printf 'function late() { :; }\n' >"$WORK/src/late.sh"

  # Seeding runs once per run; a file that appears afterwards is still tracked
  # if it executes, but the report does not invent it.
  assert_not_contains "late.sh" "$tracked"
}

function test_no_coverage_paths_seeds_nothing() {
  local tracked
  tracked=$(seed_with "")

  assert_empty "$tracked"
}
