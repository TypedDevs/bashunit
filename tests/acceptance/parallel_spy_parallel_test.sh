#!/usr/bin/env bash
# shellcheck disable=SC2155
set -euo pipefail

function test_spies_work_in_parallel() {
        local file1="$(bashunit::current_dir)/fixtures/test_parallel_spy_file1.sh"
        local file2="$(bashunit::current_dir)/fixtures/test_parallel_spy_file2.sh"

        ./bashunit --parallel "$file1" "$file2"
        assert_successful_code
}
