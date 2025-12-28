#!/usr/bin/env bash
# shellcheck disable=SC2034

function set_up_before_script() {
    TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
    LCOV_FILE="$(bashunit::temp_file "lcov-output")"
}

function test_coverage_includes_src_hits_from_setup_hook() {
    # Enable coverage in-process and exercise code in a hook-like context
    BASHUNIT_COVERAGE=true
    BASHUNIT_COVERAGE_PATHS="src/"
    bashunit::coverage::init

    # Simulate hook execution with coverage trap enabled
    bashunit::coverage::enable_trap
    # Call a src function to generate attributable hits
    local f
    f="$(bashunit::temp_file "cov-hooks")"
    [[ -n "${f:-}" ]] && echo "tmp created" > /dev/null
    bashunit::coverage::disable_trap

    # Generate LCOV and assert presence of src entries
    bashunit::coverage::report_lcov "$LCOV_FILE"
    local lcov
    lcov="$(cat "$LCOV_FILE" 2>/dev/null)"
    assert_contains "SF:$(pwd)/src/" "$lcov"
    assert_contains "DA:" "$lcov"
}
