#!/usr/bin/env bash
# shellcheck disable=SC2317

# Save original coverage state to restore after tests
_ORIG_COVERAGE_DATA_FILE=""
_ORIG_COVERAGE_TRACKED_FILES=""
_ORIG_COVERAGE_TRACKED_CACHE_FILE=""
_ORIG_COVERAGE=""
_ORIG_COVERAGE_PATHS=""
_ORIG_COVERAGE_EXCLUDE=""
_ORIG_COVERAGE_REPORT=""
_ORIG_COVERAGE_MIN=""

function set_up() {
  # Save original coverage state
  _ORIG_COVERAGE_DATA_FILE="$_BASHUNIT_COVERAGE_DATA_FILE"
  _ORIG_COVERAGE_TRACKED_FILES="$_BASHUNIT_COVERAGE_TRACKED_FILES"
  _ORIG_COVERAGE_TRACKED_CACHE_FILE="$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
  _ORIG_COVERAGE="${BASHUNIT_COVERAGE:-}"
  _ORIG_COVERAGE_PATHS="${BASHUNIT_COVERAGE_PATHS:-}"
  _ORIG_COVERAGE_EXCLUDE="${BASHUNIT_COVERAGE_EXCLUDE:-}"
  _ORIG_COVERAGE_REPORT="${BASHUNIT_COVERAGE_REPORT:-}"
  _ORIG_COVERAGE_MIN="${BASHUNIT_COVERAGE_MIN:-}"

  # Reset coverage state for testing
  _BASHUNIT_COVERAGE_DATA_FILE=""
  _BASHUNIT_COVERAGE_TRACKED_FILES=""
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE=""
  export BASHUNIT_COVERAGE="false"
  export BASHUNIT_COVERAGE_PATHS="src/"
  export BASHUNIT_COVERAGE_EXCLUDE="tests/*,vendor/*,*_test.sh,*Test.sh"
  export BASHUNIT_COVERAGE_REPORT=""
  export BASHUNIT_COVERAGE_MIN=""
}

function tear_down() {
  # Clean up any coverage temp files created by tests
  if [[ -n "$_BASHUNIT_COVERAGE_DATA_FILE" && "$_BASHUNIT_COVERAGE_DATA_FILE" != "$_ORIG_COVERAGE_DATA_FILE" ]]; then
    local coverage_dir
    coverage_dir=$(dirname "$_BASHUNIT_COVERAGE_DATA_FILE")
    rm -rf "$coverage_dir" 2>/dev/null || true
  fi

  # Restore original coverage state
  _BASHUNIT_COVERAGE_DATA_FILE="$_ORIG_COVERAGE_DATA_FILE"
  _BASHUNIT_COVERAGE_TRACKED_FILES="$_ORIG_COVERAGE_TRACKED_FILES"
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE="$_ORIG_COVERAGE_TRACKED_CACHE_FILE"
  if [[ -n "$_ORIG_COVERAGE" ]]; then
    export BASHUNIT_COVERAGE="$_ORIG_COVERAGE"
  else
    unset BASHUNIT_COVERAGE
  fi
  if [[ -n "$_ORIG_COVERAGE_PATHS" ]]; then
    export BASHUNIT_COVERAGE_PATHS="$_ORIG_COVERAGE_PATHS"
  else
    unset BASHUNIT_COVERAGE_PATHS
  fi
  if [[ -n "$_ORIG_COVERAGE_EXCLUDE" ]]; then
    export BASHUNIT_COVERAGE_EXCLUDE="$_ORIG_COVERAGE_EXCLUDE"
  else
    unset BASHUNIT_COVERAGE_EXCLUDE
  fi
  if [[ -n "$_ORIG_COVERAGE_REPORT" ]]; then
    export BASHUNIT_COVERAGE_REPORT="$_ORIG_COVERAGE_REPORT"
  else
    unset BASHUNIT_COVERAGE_REPORT
  fi
  if [[ -n "$_ORIG_COVERAGE_MIN" ]]; then
    export BASHUNIT_COVERAGE_MIN="$_ORIG_COVERAGE_MIN"
  else
    unset BASHUNIT_COVERAGE_MIN
  fi
}

function test_coverage_check_threshold_passes_when_no_minimum() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_MIN=""
  bashunit::coverage::init

  assert_successful_code "bashunit::coverage::check_threshold"
}

function test_coverage_check_threshold_fails_when_below_minimum() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_MIN="80"
  bashunit::coverage::init

  # Create a tracked file with some executable lines but no hits
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "line 1"
echo "line 2"
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  # Capture only the exit code, suppress output
  local result
  if bashunit::coverage::check_threshold >/dev/null 2>&1; then
    result="passed"
  else
    result="failed"
  fi

  assert_equals "failed" "$result"

  rm -f "$temp_file"
}

function test_coverage_report_lcov_generates_valid_format() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  # Create a test source file
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "line 1"
echo "line 2"
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  # Simulate some hits
  echo "${temp_file}:2" >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  # Generate report to temp file
  local report_file
  report_file=$(mktemp)
  bashunit::coverage::report_lcov "$report_file"

  local content
  content=$(cat "$report_file")

  # Line 1 (shebang) is not counted - only lines 2 and 3 are executable
  assert_contains "TN:" "$content"
  assert_contains "SF:${temp_file}" "$content"
  assert_contains "DA:2," "$content"
  assert_contains "DA:3," "$content"
  assert_contains "LF:2" "$content"
  assert_contains "end_of_record" "$content"

  rm -f "$temp_file" "$report_file"
}

function test_coverage_report_text_shows_no_files_message() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  # Empty tracked files
  : >"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  local output
  output=$(bashunit::coverage::report_text)

  assert_contains "Total: 0/0 (0%)" "$output"
}

function test_coverage_get_tracked_files_returns_empty_when_no_file() {
  _BASHUNIT_COVERAGE_TRACKED_FILES=""

  local result
  result=$(bashunit::coverage::get_tracked_files)

  assert_empty "$result"
}

function test_coverage_get_tracked_files_returns_sorted_unique() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  {
    echo "/path/to/b.sh"
    echo "/path/to/a.sh"
    echo "/path/to/b.sh"
  } >>"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  local result
  result=$(bashunit::coverage::get_tracked_files | tr '\n' ' ')

  # Should be sorted and unique
  assert_equals "/path/to/a.sh /path/to/b.sh " "$result"
}

function test_coverage_get_file_stats_returns_formatted_string() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  # Create a test file with known content
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "line 1"
echo "line 2"
EOF

  # No hits recorded, so 0% coverage
  local result
  result=$(bashunit::coverage::get_file_stats "$temp_file")

  # Format: executable:hit:pct:class
  assert_matches "^2:0:0:low$" "$result"

  rm -f "$temp_file"
}

function test_coverage_get_hit_lines_returns_zero_when_no_data() {
  _BASHUNIT_COVERAGE_DATA_FILE=""

  local result
  result=$(bashunit::coverage::get_hit_lines "/path/to/file.sh")

  assert_equals "0" "$result"
}
