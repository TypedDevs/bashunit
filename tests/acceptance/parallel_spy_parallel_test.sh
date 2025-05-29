#!/usr/bin/env bash
set -euo pipefail

function test_spies_work_in_parallel() {
  local file1=tests/acceptance/fixtures/test_parallel_spy_file1.sh
  local file2=tests/acceptance/fixtures/test_parallel_spy_file2.sh

  ./bashunit --parallel "$file1" "$file2"
  assert_successful_code
}
