#!/usr/bin/env bash
set -euo pipefail

# Regression guard for #834. Run-mode flags (--stop-on-failure and the report
# writers) used to be exported, so nested bashunit runs — bashunit's own
# acceptance tests under `build.sh --verify`, or a user's scripts under test
# that call bashunit — inherited them: nested runs aborted before persisting
# the rerun cache, wrote their own reports over the parent's files, and blew
# the per-run fork budget.
function test_run_mode_flags_do_not_leak_into_nested_runs() {
  local dir
  dir=$(bashunit::temp_dir)

  local output
  local exit_code=0
  output=$(./bashunit --no-parallel --skip-env-file \
    --stop-on-failure \
    --log-junit "$dir/log-junit.xml" \
    --report-html "$dir/report.html" \
    --report-tap "$dir/report.tap" \
    --report-json "$dir/report.json" \
    tests/acceptance/fixtures/flag_env_leak/leak_probe.sh 2>&1) || exit_code=$?

  assert_equals 0 "$exit_code"
  assert_contains "1 passed" "$output"
}
