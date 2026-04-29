#!/usr/bin/env bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function set_up() {
  BASELINE_FILE=$(mktemp "${TMPDIR:-/tmp}/bashunit-baseline-XXXXXX")
}

function tear_down() {
  [ -n "${BASELINE_FILE:-}" ] && [ -f "$BASELINE_FILE" ] && rm -f "$BASELINE_FILE"
}

function test_bashunit_generate_baseline_writes_xml_with_failures() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_baseline.sh

  ./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --generate-baseline "$BASELINE_FILE" "$test_file" >/dev/null 2>&1 || true

  assert_file_exists "$BASELINE_FILE"

  local content
  content=$(cat "$BASELINE_FILE")

  assert_contains '<?xml version="1.0" encoding="UTF-8"?>' "$content"
  assert_contains '<baseline version="1.0">' "$content"
  assert_contains 'name="Fails"' "$content"
  assert_contains 'name="Also fails"' "$content"
  assert_contains 'status="failed"' "$content"
  assert_not_contains 'name="Passes"' "$content"
}

function test_bashunit_generate_baseline_run_succeeds_with_zero_exit() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_baseline.sh

  local exit_code=0
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --generate-baseline "$BASELINE_FILE" "$test_file" >/dev/null 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
}

function test_bashunit_use_baseline_suppresses_listed_failures() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_baseline.sh

  ./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --generate-baseline "$BASELINE_FILE" "$test_file" >/dev/null 2>&1 || true

  local exit_code=0
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --use-baseline "$BASELINE_FILE" "$test_file" >/dev/null 2>&1 || exit_code=$?

  assert_equals "0" "$exit_code"
}

function test_bashunit_use_baseline_still_reports_unmatched_failures() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_baseline.sh

  cat >"$BASELINE_FILE" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<baseline version="1.0">
  <test file="${test_file}" name="Fails" status="failed"/>
</baseline>
XML

  local exit_code=0
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --use-baseline "$BASELINE_FILE" "$test_file" >/dev/null 2>&1 || exit_code=$?

  assert_not_equals "0" "$exit_code"
}

function test_bashunit_use_baseline_errors_when_file_missing() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_baseline.sh

  local output exit_code=0
  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --use-baseline /nonexistent/baseline.xml "$test_file" 2>&1) || exit_code=$?

  assert_not_equals "0" "$exit_code"
  assert_contains "baseline file not found" "$output"
}
