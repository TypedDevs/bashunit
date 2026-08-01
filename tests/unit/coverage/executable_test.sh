#!/usr/bin/env bash
# shellcheck disable=SC2317
# shellcheck disable=SC1003 # intentional literal trailing backslashes in test inputs

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
  if [ -n "$_BASHUNIT_COVERAGE_DATA_FILE" ] &&
    [ "$_BASHUNIT_COVERAGE_DATA_FILE" != "$_ORIG_COVERAGE_DATA_FILE" ]; then
    local coverage_dir
    coverage_dir=$(dirname "$_BASHUNIT_COVERAGE_DATA_FILE")
    rm -rf "$coverage_dir" 2>/dev/null || true
  fi

  # Restore original coverage state
  _BASHUNIT_COVERAGE_DATA_FILE="$_ORIG_COVERAGE_DATA_FILE"
  _BASHUNIT_COVERAGE_TRACKED_FILES="$_ORIG_COVERAGE_TRACKED_FILES"
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE="$_ORIG_COVERAGE_TRACKED_CACHE_FILE"
  if [ -n "$_ORIG_COVERAGE" ]; then
    export BASHUNIT_COVERAGE="$_ORIG_COVERAGE"
  else
    unset BASHUNIT_COVERAGE
  fi
  if [ -n "$_ORIG_COVERAGE_PATHS" ]; then
    export BASHUNIT_COVERAGE_PATHS="$_ORIG_COVERAGE_PATHS"
  else
    unset BASHUNIT_COVERAGE_PATHS
  fi
  if [ -n "$_ORIG_COVERAGE_EXCLUDE" ]; then
    export BASHUNIT_COVERAGE_EXCLUDE="$_ORIG_COVERAGE_EXCLUDE"
  else
    unset BASHUNIT_COVERAGE_EXCLUDE
  fi
  if [ -n "$_ORIG_COVERAGE_REPORT" ]; then
    export BASHUNIT_COVERAGE_REPORT="$_ORIG_COVERAGE_REPORT"
  else
    unset BASHUNIT_COVERAGE_REPORT
  fi
  if [ -n "$_ORIG_COVERAGE_MIN" ]; then
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

function test_coverage_is_executable_line_returns_false_for_case_pattern_with_comment() {
  local input='    *thing) # Looks for thing at end of text'
  local result
  result=$(bashunit::coverage::is_executable_line "$input" 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_wildcard_case_with_comment() {
  local result
  result=$(bashunit::coverage::is_executable_line '    *) # fallback' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_done_with_file_redirect() {
  local result
  result=$(bashunit::coverage::is_executable_line '  done < /path/to/file' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_done_with_herestring() {
  local result
  # shellcheck disable=SC2016
  result=$(bashunit::coverage::is_executable_line '  done <<<"$var"' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_done_with_process_sub() {
  local result
  result=$(bashunit::coverage::is_executable_line '  done < <(some_cmd)' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_done_with_redirect_and_comment() {
  local result
  # shellcheck disable=SC2016
  result=$(bashunit::coverage::is_executable_line '  done < "$file" # read input' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_done_with_pipe() {
  local result
  result=$(bashunit::coverage::is_executable_line '  done | sort' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_done_with_fd_redirect() {
  local result
  result=$(bashunit::coverage::is_executable_line '  done 2>&1' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_done_with_background() {
  local result
  result=$(bashunit::coverage::is_executable_line '  done &' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_is_executable_line_returns_false_for_done_with_append_redirect() {
  local result
  result=$(bashunit::coverage::is_executable_line '  done >> /tmp/out.log' 2 && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

# --- _ends_with_continuation (#722) -----------------------------------------

function test_coverage_ends_with_continuation_true_for_single_trailing_backslash() {
  local result
  result=$(bashunit::coverage::_ends_with_continuation 'echo foo \' && echo "yes" || echo "no")
  assert_equals "yes" "$result"
}

function test_coverage_ends_with_continuation_true_for_indented_continuation() {
  local result
  result=$(bashunit::coverage::_ends_with_continuation '  some_command --flag \' && echo "yes" || echo "no")
  assert_equals "yes" "$result"
}

function test_coverage_ends_with_continuation_false_for_no_backslash() {
  local result
  result=$(bashunit::coverage::_ends_with_continuation 'echo foo' && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_ends_with_continuation_false_for_escaped_backslash() {
  local result
  result=$(bashunit::coverage::_ends_with_continuation 'echo foo \\' && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_ends_with_continuation_true_for_three_backslashes() {
  local result
  result=$(bashunit::coverage::_ends_with_continuation 'echo foo \\\' && echo "yes" || echo "no")
  assert_equals "yes" "$result"
}

function test_coverage_ends_with_continuation_false_for_trailing_whitespace_after_backslash() {
  local result
  result=$(bashunit::coverage::_ends_with_continuation 'echo foo \ ' && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_ends_with_continuation_false_for_comment_line() {
  local result
  result=$(bashunit::coverage::_ends_with_continuation '# a trailing slash in a comment \' && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

function test_coverage_ends_with_continuation_false_for_empty_line() {
  local result
  result=$(bashunit::coverage::_ends_with_continuation '' && echo "yes" || echo "no")
  assert_equals "no" "$result"
}

# --- get_all_line_hits continuation propagation (#722) ----------------------

function test_coverage_get_all_line_hits_propagates_across_continuation_chain() {
  local dir
  dir=$(mktemp -d)
  _BASHUNIT_COVERAGE_DATA_FILE="${dir}/coverage.data"

  local src="${dir}/script.sh"
  printf '%s\n' 'echo start \' '  middle \' '  end' 'echo other' >"$src"

  # Start line (1) hit twice, standalone line (4) hit once.
  printf '%s\n' "${src}:1" "${src}:1" "${src}:4" >"$_BASHUNIT_COVERAGE_DATA_FILE"

  local result
  result=$(bashunit::coverage::get_all_line_hits "$src")

  local expected
  expected=$(printf '%s\n' "1:2" "2:2" "3:2" "4:1")

  rm -rf "$dir" 2>/dev/null || true
  _BASHUNIT_COVERAGE_DATA_FILE=""

  assert_equals "$expected" "$result"
}

function test_coverage_get_all_line_hits_does_not_propagate_without_continuation() {
  local dir
  dir=$(mktemp -d)
  _BASHUNIT_COVERAGE_DATA_FILE="${dir}/coverage.data"

  local src="${dir}/script.sh"
  printf '%s\n' 'echo one' 'echo two' >"$src"

  printf '%s\n' "${src}:1" >"$_BASHUNIT_COVERAGE_DATA_FILE"

  local result
  result=$(bashunit::coverage::get_all_line_hits "$src")

  rm -rf "$dir" 2>/dev/null || true
  _BASHUNIT_COVERAGE_DATA_FILE=""

  assert_equals "1:1" "$result"
}
