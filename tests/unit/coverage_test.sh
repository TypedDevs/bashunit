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

function test_coverage_disabled_by_default() {
  assert_equals "false" "$BASHUNIT_COVERAGE"
}

function test_is_coverage_enabled_returns_false_when_disabled() {
  BASHUNIT_COVERAGE="false"
  # Use subshell to capture exit code without triggering errexit
  local result
  result=$(bashunit::env::is_coverage_enabled && echo "true" || echo "false")
  assert_equals "false" "$result"
}

function test_is_coverage_enabled_returns_true_when_enabled() {
  BASHUNIT_COVERAGE="true"
  local result
  result=$(bashunit::env::is_coverage_enabled && echo "true" || echo "false")
  assert_equals "true" "$result"
}

function test_coverage_init_creates_temp_files() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  assert_not_empty "$_BASHUNIT_COVERAGE_DATA_FILE"
  assert_not_empty "$_BASHUNIT_COVERAGE_TRACKED_FILES"
  assert_file_exists "$_BASHUNIT_COVERAGE_DATA_FILE"
  assert_file_exists "$_BASHUNIT_COVERAGE_TRACKED_FILES"
}

function test_coverage_init_does_nothing_when_disabled() {
  BASHUNIT_COVERAGE="false"
  bashunit::coverage::init

  assert_empty "$_BASHUNIT_COVERAGE_DATA_FILE"
}

function test_coverage_should_track_excludes_test_files() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_PATHS=""
  BASHUNIT_COVERAGE_EXCLUDE="*_test.sh"
  bashunit::coverage::init

  # Use subshell to capture exit code without triggering errexit
  local result
  result=$(bashunit::coverage::should_track '/path/to/my_test.sh' && echo "tracked" || echo "excluded")
  assert_equals "excluded" "$result"
}

function test_coverage_should_track_excludes_vendor() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_PATHS=""
  BASHUNIT_COVERAGE_EXCLUDE="vendor/*"
  bashunit::coverage::init

  local result
  result=$(bashunit::coverage::should_track '/project/vendor/lib.sh' && echo "tracked" || echo "excluded")
  assert_equals "excluded" "$result"
}

function test_coverage_should_track_excludes_bashunit_src() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local result
  result=$(bashunit::coverage::should_track '/path/to/bashunit/src/runner.sh' && echo "tracked" || echo "excluded")
  assert_equals "excluded" "$result"
}

function test_coverage_get_executable_lines_counts_correctly() {
  local temp_file
  temp_file=$(mktemp)

  cat > "$temp_file" << 'EOF'
#!/usr/bin/env bash

# This is a comment
function my_func() {
  echo "hello"
  echo "world"
}

my_func
EOF

  # Expected executable lines:
  # Line 1: shebang (not counted - it's a comment)
  # Line 3: comment (not counted)
  # Line 4: function declaration (not counted)
  # Line 5: echo "hello" (counted)
  # Line 6: echo "world" (counted)
  # Line 7: } (not counted)
  # Line 9: my_func (counted)
  # Total: 3 executable lines

  local count
  count=$(bashunit::coverage::get_executable_lines "$temp_file")

  assert_equals "3" "$count"

  rm -f "$temp_file"
}

function test_coverage_record_line_writes_to_file() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_PATHS="/"
  BASHUNIT_COVERAGE_EXCLUDE=""
  bashunit::coverage::init

  local test_file="/some/path/script.sh"
  bashunit::coverage::record_line "$test_file" "10"
  bashunit::coverage::record_line "$test_file" "20"
  bashunit::coverage::record_line "$test_file" "10"

  # In parallel mode, data is written to a per-process file
  local data_file="$_BASHUNIT_COVERAGE_DATA_FILE"
  if bashunit::parallel::is_enabled; then
    data_file="${_BASHUNIT_COVERAGE_DATA_FILE}.$$"
  fi

  local content
  content=$(cat "$data_file")

  assert_contains "$test_file:10" "$content"
  assert_contains "$test_file:20" "$content"
}

function test_coverage_check_threshold_passes_when_no_minimum() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_MIN=""
  bashunit::coverage::init

  assert_successful_code "bashunit::coverage::check_threshold"
}

function test_coverage_cleanup_removes_temp_files() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local coverage_dir
  coverage_dir=$(dirname "$_BASHUNIT_COVERAGE_DATA_FILE")

  assert_directory_exists "$coverage_dir"

  bashunit::coverage::cleanup

  assert_directory_not_exists "$coverage_dir"
}

function test_coverage_default_paths_is_empty_for_auto_discovery() {
  assert_equals "" "$_BASHUNIT_DEFAULT_COVERAGE_PATHS"
}

function test_coverage_default_report_is_lcov() {
  assert_equals "coverage/lcov.info" "$_BASHUNIT_DEFAULT_COVERAGE_REPORT"
}

function test_coverage_default_threshold_low_is_50() {
  assert_equals "50" "$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_LOW"
}

function test_coverage_default_threshold_high_is_80() {
  assert_equals "80" "$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_HIGH"
}

function test_coverage_is_executable_line_returns_true_for_commands() {
  local result
  result=$(bashunit::coverage::is_executable_line 'echo "hello"' 2 && echo "yes" || echo "no")
  assert_equals "yes" "$result"
}

function test_coverage_is_executable_line_returns_false_for_comments() {
  local result
  result=$(bashunit::coverage::is_executable_line '# this is a comment' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_shebang() {
  # Shebang is a comment line, not executable (only runs when script invoked directly)
  local result
  result=$(bashunit::coverage::is_executable_line '#!/usr/bin/env bash' 1 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_function_declaration() {
  local result
  result=$(bashunit::coverage::is_executable_line 'function my_func() {' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_empty_line() {
  local result
  result=$(bashunit::coverage::is_executable_line '   ' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_brace_only() {
  local result
  result=$(bashunit::coverage::is_executable_line '}' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_then() {
  local result
  result=$(bashunit::coverage::is_executable_line '  then' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_else() {
  local result
  result=$(bashunit::coverage::is_executable_line '  else' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_fi() {
  local result
  result=$(bashunit::coverage::is_executable_line '  fi' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_do() {
  local result
  result=$(bashunit::coverage::is_executable_line '  do' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_done() {
  local result
  result=$(bashunit::coverage::is_executable_line '  done' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_esac() {
  local result
  result=$(bashunit::coverage::is_executable_line '  esac' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_case_terminator() {
  local result
  result=$(bashunit::coverage::is_executable_line '      ;;' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_case_pattern() {
  local result
  result=$(bashunit::coverage::is_executable_line '    --exit)' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_wildcard_case() {
  local result
  result=$(bashunit::coverage::is_executable_line '    *)' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_case_fallthrough() {
  local result
  result=$(bashunit::coverage::is_executable_line '      ;&' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_case_continue() {
  local result
  result=$(bashunit::coverage::is_executable_line '      ;;&' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_in_keyword() {
  local result
  result=$(bashunit::coverage::is_executable_line '  in' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_standalone_paren() {
  local result
  result=$(bashunit::coverage::is_executable_line '  )' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_check_threshold_fails_when_below_minimum() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_MIN="80"
  bashunit::coverage::init

  # Create a tracked file with some executable lines but no hits
  local temp_file
  temp_file=$(mktemp)
  cat > "$temp_file" << 'EOF'
#!/usr/bin/env bash
echo "line 1"
echo "line 2"
EOF

  echo "$temp_file" > "$_BASHUNIT_COVERAGE_TRACKED_FILES"

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
  cat > "$temp_file" << 'EOF'
#!/usr/bin/env bash
echo "line 1"
echo "line 2"
EOF

  echo "$temp_file" > "$_BASHUNIT_COVERAGE_TRACKED_FILES"

  # Simulate some hits
  echo "${temp_file}:2" >> "$_BASHUNIT_COVERAGE_DATA_FILE"

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

function test_coverage_normalize_path_returns_absolute_path() {
  local temp_file
  temp_file=$(mktemp)

  local result
  result=$(bashunit::coverage::normalize_path "$temp_file")

  # Result should be an absolute path starting with /
  assert_matches "^/" "$result"

  # Result should contain the actual temp file name
  assert_contains "$(basename "$temp_file")" "$result"

  rm -f "$temp_file"
}

function test_coverage_should_track_caches_decisions() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_PATHS="/"
  BASHUNIT_COVERAGE_EXCLUDE=""
  bashunit::coverage::init

  local test_file="/some/path/script.sh"

  # First call should cache the decision
  bashunit::coverage::should_track "$test_file"

  # Verify cache file contains the decision
  # In parallel mode, cache is written to per-process file
  local cache_file="$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
  if bashunit::parallel::is_enabled; then
    cache_file="${cache_file}.$$"
  fi

  local cache_content
  cache_content=$(cat "$cache_file")

  assert_contains "${test_file}:" "$cache_content"
}

function test_coverage_default_excludes_test_files() {
  assert_contains "*_test.sh" "$_BASHUNIT_DEFAULT_COVERAGE_EXCLUDE"
  assert_contains "*Test.sh" "$_BASHUNIT_DEFAULT_COVERAGE_EXCLUDE"
}

# === Helper function tests ===

function test_coverage_get_coverage_class_returns_high() {
  local result
  result=$(bashunit::coverage::get_coverage_class 85)
  assert_equals "high" "$result"
}

function test_coverage_get_coverage_class_returns_medium() {
  local result
  result=$(bashunit::coverage::get_coverage_class 65)
  assert_equals "medium" "$result"
}

function test_coverage_get_coverage_class_returns_low() {
  local result
  result=$(bashunit::coverage::get_coverage_class 30)
  assert_equals "low" "$result"
}

function test_coverage_get_coverage_class_boundary_high() {
  local result
  result=$(bashunit::coverage::get_coverage_class 80)
  assert_equals "high" "$result"
}

function test_coverage_get_coverage_class_boundary_low() {
  local result
  result=$(bashunit::coverage::get_coverage_class 50)
  assert_equals "medium" "$result"
}

function test_coverage_calculate_percentage_basic() {
  local result
  result=$(bashunit::coverage::calculate_percentage 5 10)
  assert_equals "50" "$result"
}

function test_coverage_calculate_percentage_full_coverage() {
  local result
  result=$(bashunit::coverage::calculate_percentage 100 100)
  assert_equals "100" "$result"
}

function test_coverage_calculate_percentage_zero_hits() {
  local result
  result=$(bashunit::coverage::calculate_percentage 0 50)
  assert_equals "0" "$result"
}

function test_coverage_calculate_percentage_zero_executable() {
  local result
  result=$(bashunit::coverage::calculate_percentage 0 0)
  assert_equals "0" "$result"
}

function test_coverage_html_escape_ampersand() {
  local result
  result=$(bashunit::coverage::html_escape 'foo & bar')
  assert_equals 'foo &amp; bar' "$result"
}

function test_coverage_html_escape_less_than() {
  local result
  result=$(bashunit::coverage::html_escape 'x < y')
  assert_equals 'x &lt; y' "$result"
}

function test_coverage_html_escape_greater_than() {
  local result
  result=$(bashunit::coverage::html_escape 'x > y')
  assert_equals 'x &gt; y' "$result"
}

function test_coverage_html_escape_combined() {
  local result
  # shellcheck disable=SC2016 # Single quotes intentional - testing literal string escaping
  result=$(bashunit::coverage::html_escape 'if [[ $a < $b && $c > $d ]]; then')
  # shellcheck disable=SC2016
  assert_equals 'if [[ $a &lt; $b &amp;&amp; $c &gt; $d ]]; then' "$result"
}

function test_coverage_path_to_filename_converts_slashes() {
  cd /tmp || return
  local result
  result=$(bashunit::coverage::path_to_filename '/tmp/src/lib/utils.sh')
  assert_equals 'src_lib_utils_sh' "$result"
}

function test_coverage_path_to_filename_handles_dots() {
  cd /tmp || return
  local result
  result=$(bashunit::coverage::path_to_filename '/tmp/test.spec.sh')
  assert_equals 'test_spec_sh' "$result"
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
  } >> "$_BASHUNIT_COVERAGE_TRACKED_FILES"

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
  cat > "$temp_file" << 'EOF'
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

function test_coverage_extract_functions_finds_basic_function() {
  local temp_file
  temp_file=$(mktemp)
  cat > "$temp_file" << 'EOF'
#!/usr/bin/env bash
function my_func() {
  echo "hello"
}
EOF

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_contains "my_func" "$result"

  rm -f "$temp_file"
}

function test_coverage_extract_functions_finds_namespaced_function() {
  local temp_file
  temp_file=$(mktemp)
  cat > "$temp_file" << 'EOF'
#!/usr/bin/env bash
function bashunit::helper::do_thing() {
  echo "hello"
}
EOF

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_contains "bashunit::helper::do_thing" "$result"

  rm -f "$temp_file"
}

function test_coverage_extract_functions_finds_multiple_functions() {
  local temp_file
  temp_file=$(mktemp)
  cat > "$temp_file" << 'EOF'
#!/usr/bin/env bash
function func_one() {
  echo "one"
}
function func_two() {
  echo "two"
}
EOF

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_contains "func_one" "$result"
  assert_contains "func_two" "$result"

  rm -f "$temp_file"
}

function test_coverage_get_line_hits_returns_zero_when_no_file() {
  _BASHUNIT_COVERAGE_DATA_FILE=""

  local result
  result=$(bashunit::coverage::get_line_hits "/path/to/file.sh" 10)

  assert_equals "0" "$result"
}

function test_coverage_get_line_hits_counts_correctly() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local test_file="/test/script.sh"
  {
    echo "${test_file}:5"
    echo "${test_file}:5"
    echo "${test_file}:5"
  } >> "$_BASHUNIT_COVERAGE_DATA_FILE"

  local result
  result=$(bashunit::coverage::get_line_hits "$test_file" 5)

  assert_equals "3" "$result"
}

function test_coverage_get_hit_lines_returns_zero_when_no_data() {
  _BASHUNIT_COVERAGE_DATA_FILE=""

  local result
  result=$(bashunit::coverage::get_hit_lines "/path/to/file.sh")

  assert_equals "0" "$result"
}

function test_coverage_report_text_shows_no_files_message() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  # Empty tracked files
  : > "$_BASHUNIT_COVERAGE_TRACKED_FILES"

  local output
  output=$(bashunit::coverage::report_text)

  assert_contains "Total: 0/0 (0%)" "$output"
}
