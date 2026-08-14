#!/usr/bin/env bash

# --output sends a machine-readable report to stdout instead of the human
# console rendering, so a pipeline can consume the result without a temp file.

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="tests/acceptance/fixtures/test_bashunit_report_json.sh"
  PASSING="tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh"
  JQ_AVAILABLE=false
  # `|| true` so a jq-less box means "skip", not "hook failed" (#836)
  { command -v jq >/dev/null 2>&1 && JQ_AVAILABLE=true; } || true
}

function test_output_json_emits_a_valid_json_document_on_stdout() {
  if [ "$JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local stdout
  stdout=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --output json "$FIXTURE" 2>/dev/null || true)

  assert_successful_code "$(printf '%s' "$stdout" | jq empty 2>&1)"
  assert_same "2" "$(printf '%s' "$stdout" | jq '.summary.total')"
  assert_same "1" "$(printf '%s' "$stdout" | jq '.summary.failed')"
}

function test_output_json_stdout_carries_no_console_decoration() {
  local stdout
  stdout=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --output json "$FIXTURE" 2>/dev/null || true)

  assert_not_contains "Running" "$stdout"
  assert_not_contains "Tests:" "$stdout"
  assert_not_contains "Time:" "$stdout"
}

function test_output_junit_emits_xml_on_stdout() {
  local stdout
  stdout=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --output junit "$FIXTURE" 2>/dev/null || true)

  assert_contains "<?xml" "$stdout"
  assert_contains "<testsuites" "$stdout"
  assert_contains 'tests="2"' "$stdout"
}

function test_output_json_and_report_json_produce_both() {
  if [ "$JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local report stdout
  report="$(bashunit::temp_file)"
  stdout=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --output json --report-json "$report" "$FIXTURE" 2>/dev/null || true)

  assert_successful_code "$(printf '%s' "$stdout" | jq empty 2>&1)"
  assert_successful_code "$(jq empty "$report" 2>&1)"
}

function test_output_text_renders_the_same_as_no_flag() {
  local with_flag without_flag
  with_flag=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --output text "$PASSING" 2>&1 | tr -d '0-9')
  without_flag=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$PASSING" 2>&1 | tr -d '0-9')

  assert_same "$without_flag" "$with_flag"
}

# The parallel spinner draws on stdout and is erased with a "\r  \r" once the
# aggregation ends, which would land in front of the XML declaration.
function test_output_junit_starts_with_the_xml_declaration_under_parallel() {
  # No `| head -1`: under --strict the pipe closes early and SIGPIPEs the run.
  local output
  output=$(./bashunit --parallel --env "$TEST_ENV_FILE" --output junit "$FIXTURE" 2>/dev/null || true)

  assert_same '<?xml version="1.0" encoding="UTF-8"?>' "${output%%$'\n'*}"
}

# The guard above only ever covered `--parallel`, and parallel is *not* the
# default. Sequential emitted a blank line between a file's tests and the next,
# which landed in front of the document: `bashunit --output junit` -- the plain
# documented command -- produced XML no parser accepts.
function test_output_junit_starts_with_the_xml_declaration_sequentially() {
  local output
  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --output junit "$FIXTURE" 2>/dev/null || true)

  assert_same '<?xml version="1.0" encoding="UTF-8"?>' "${output%%$'\n'*}"
}

# Asserting the first line is not the same as asserting a parser accepts it.
function test_output_junit_is_well_formed_xml() {
  if ! command -v xmllint >/dev/null 2>&1; then
    bashunit::skip "xmllint required" && return
  fi
  local file
  file="$(bashunit::temp_file)"
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --output junit "$FIXTURE" >"$file" 2>/dev/null || true

  local errors
  errors=$(xmllint --noout "$file" 2>&1) || true

  assert_empty "$errors"
}

# JSON tolerates leading whitespace, so `jq` accepted the same stray byte and
# the defect stayed invisible on that side. Assert the document starts where it
# should rather than only that it parses.
function test_output_json_starts_with_the_document_sequentially() {
  local output
  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --output json "$FIXTURE" 2>/dev/null || true)

  assert_same "{" "${output%%$'\n'*}"
}

# Regression guard for #1004: the rows are collected inside the per-test worker,
# so a parallel run used to report zero tests.
function test_output_json_reports_every_test_under_parallel() {
  if [ "$JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local stdout
  stdout=$(./bashunit --parallel --env "$TEST_ENV_FILE" --output json "$FIXTURE" 2>/dev/null || true)

  assert_successful_code "$(printf '%s' "$stdout" | jq empty 2>&1)"
  assert_same "2" "$(printf '%s' "$stdout" | jq '.summary.total')"
}

function test_output_json_keeps_the_failing_exit_code() {
  local ec=0
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --output json "$FIXTURE" >/dev/null 2>&1 || ec=$?

  assert_general_error "" "" "$ec"
}

function test_output_json_keeps_the_passing_exit_code() {
  local ec=0
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --output json "$PASSING" >/dev/null 2>&1 || ec=$?

  assert_successful_code "" "" "$ec"
}

function test_unknown_output_format_lists_the_supported_ones() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --output jsonn "$PASSING" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "text, tap, json, junit" "$output"
}
