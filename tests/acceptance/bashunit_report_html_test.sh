#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
        TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
        TEST_ENV_FILE_REPORT_HTML="tests/acceptance/fixtures/.env.report_html"
}

function test_bashunit_when_report_html_option() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_when_report_html.sh

        assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --report-html custom.html "$test_file")"
        assert_file_exists custom.html

        if [[ -f custom.html ]]; then
                rm custom.html
        fi
}

function test_bashunit_when_report_html_env() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_when_report_html.sh

        assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_REPORT_HTML" "$test_file")"
        assert_file_exists report.html

        if [[ -f custom.html ]]; then
                rm custom.html
        fi
}
