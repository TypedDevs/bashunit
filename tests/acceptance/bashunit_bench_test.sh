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
function test_bench_fails_on_a_path_that_does_not_exist() {
  local ec=0
  local output
  output=$(./bashunit bench ./no_such_bench_path_test.sh 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "No benchmarks found" "$output"
}

function test_bench_fails_on_a_directory_that_does_not_exist() {
  local ec=0
  local output
  output=$(./bashunit bench ./no_such_bench_dir/ 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "No benchmarks found" "$output"
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
