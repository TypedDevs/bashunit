#!/usr/bin/env bash
set -euo pipefail

# Regression guard for #834. The dev entrypoint never sourced src/benchmark.sh
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
