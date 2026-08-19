#!/usr/bin/env bash
set -euo pipefail

# Regression guard for #834. The dev entrypoint never sourced the benchmark module
# (only the hand-maintained build list bundled it), so `./bashunit bench` worked
# in the built binary but crashed with `command not found` in dev mode — and no
# *_test.sh exercised the bench CLI path.
function test_bench_command_runs_in_dev_mode() {
  local fixture_dir
  fixture_dir=$(bashunit::temp_dir)
  printf '#!/usr/bin/env bash\nfunction bench_sample() { :; }\n' >"$fixture_dir/sample_bench.sh"

  local output
  local exit_code=0
  output=$(./bashunit bench "$fixture_dir/sample_bench.sh" 2>&1) || exit_code=$?

  assert_equals 0 "$exit_code"
  assert_not_contains "command not found" "$output"
  assert_contains "bench_sample" "$output"
}

# `bench` was silent and green where `test` is explicit and red: a path that
# does not exist, or one holding no bench_ function, printed a header and
# exited 0. A typo in the path or in the prefix gave a CI job that measured
# nothing, and a benchmark's whole output is numbers nobody notices are
# missing (#1199).
# #1263 gave `test` a second answer: a path that is not on disk is a wrong
# invocation and gets named, while an empty selection keeps "No benchmarks
# found". `bench` has to follow, or the two drift apart again — which is the
# exact misalignment #1199 closed.
function test_bench_names_a_path_that_does_not_exist() {
  local ec=0
  local output
  output=$(./bashunit bench ./no_such_bench_path_test.sh 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "no_such_bench_path_test.sh" "$output"
  assert_not_contains "No benchmarks found" "$output"
}

function test_bench_names_a_directory_that_does_not_exist() {
  local ec=0
  local output
  output=$(./bashunit bench ./no_such_bench_dir/ 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "no_such_bench_dir" "$output"
  assert_not_contains "No benchmarks found" "$output"
}

function test_bench_fails_when_a_file_holds_no_bench_function() {
  local dir
  dir="$(bashunit::temp_dir)"
  printf 'function test_not_a_bench() { assert_same 1 1; }\n' >"$dir/empty_bench.sh"

  local ec=0
  local output
  output=$(./bashunit bench "$dir/empty_bench.sh" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "No benchmarks found" "$output"
}

# `bench` exits on "No benchmarks found" and on a baseline regression, and
# consulted nothing else -- so a file that failed alongside one that ran left
# the run green. The error is printed either way, which is what makes it a
# silent green rather than a silent failure: a human reading the log sees it,
# CI does not. `test` exits non-zero for both of these shapes.
function test_bench_fails_when_a_files_set_up_before_script_fails() {
  local dir
  dir="$(bashunit::temp_dir bench_hook_fail)"
  printf 'function bench_works() { :; }\n' >"$dir/a_bench.sh"
  {
    printf 'function %s() { return 1; }\n' "set_up_before_script"
    printf 'function bench_never() { :; }\n'
  } >"$dir/b_bench.sh"

  local ec=0
  local output
  output=$(./bashunit bench "$dir" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "Set up before script" "$output"
}

function test_bench_cleans_up_when_set_up_before_script_fails() {
  local dir fixture marker
  dir="$(bashunit::temp_dir bench_setup_failure_cleanup)"
  fixture="$dir/cleanup_bench.sh"
  marker="$dir/resource"
  {
    printf 'RESOURCE=""\n'
    printf 'function set_up_before_script() {\n'
    printf '  RESOURCE="$CLEANUP_MARKER"\n'
    printf '  : >"$RESOURCE"\n'
    printf '  return 1\n'
    printf '}\n'
    printf 'function tear_down_after_script() {\n'
    printf '  rm -f "$RESOURCE"\n'
    printf '}\n'
    printf 'function bench_never_runs() { :; }\n'
  } >"$fixture"

  local exit_code=0
  CLEANUP_MARKER="$marker" ./bashunit bench "$fixture" >/dev/null 2>&1 || exit_code=$?

  assert_general_error "" "" "$exit_code"
  assert_file_not_exists "$marker"
}

function test_bench_fails_when_a_file_cannot_be_sourced() {
  local dir
  dir="$(bashunit::temp_dir bench_source_fail)"
  printf 'function bench_works() { :; }\n' >"$dir/a_bench.sh"
  {
    printf 'function bench_ok() { :; }\n'
    printf 'function broken( {\n'
  } >"$dir/b_bench.sh"

  local ec=0
  local output
  output=$(./bashunit bench "$dir" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
}
