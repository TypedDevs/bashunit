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

function test_coverage_default_report_is_lcov() {
  assert_equals "coverage/lcov.info" "$_BASHUNIT_DEFAULT_COVERAGE_REPORT"
}

function test_coverage_default_threshold_low_is_50() {
  assert_equals "50" "$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_LOW"
}

function test_coverage_default_threshold_high_is_80() {
  assert_equals "80" "$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_HIGH"
}

function test_coverage_default_excludes_test_files() {
  assert_contains "*_test.sh" "$_BASHUNIT_DEFAULT_COVERAGE_EXCLUDE"
  assert_contains "*Test.sh" "$_BASHUNIT_DEFAULT_COVERAGE_EXCLUDE"
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
