#!/usr/bin/env bash
# shellcheck disable=SC2155

_BASHUNIT_TOTAL_TESTS_COUNT=0

function bashunit::console_results::render_result() {
  if [[ "$(bashunit::state::is_duplicated_test_functions_found)" == true ]]; then
    bashunit::console_results::print_execution_time
    printf "%s%s%s\n" "${_BASHUNIT_COLOR_RETURN_ERROR}" "Duplicate test functions found" "${_BASHUNIT_COLOR_DEFAULT}"
    printf "File with duplicate functions: %s\n" "$(bashunit::state::get_file_with_duplicated_function_names)"
    printf "Duplicate functions: %s\n" "$(bashunit::state::get_duplicated_function_names)"
    return 1
  fi

  if bashunit::env::is_simple_output_enabled; then
    printf "\n\n"
  fi

  # Cache state values to avoid repeated subshell invocations
  local tests_passed=$_BASHUNIT_TESTS_PASSED
  local tests_skipped=$_BASHUNIT_TESTS_SKIPPED
  local tests_incomplete=$_BASHUNIT_TESTS_INCOMPLETE
  local tests_snapshot=$_BASHUNIT_TESTS_SNAPSHOT
  local tests_failed=$_BASHUNIT_TESTS_FAILED
  local assertions_passed=$_BASHUNIT_ASSERTIONS_PASSED
  local assertions_skipped=$_BASHUNIT_ASSERTIONS_SKIPPED
  local assertions_incomplete=$_BASHUNIT_ASSERTIONS_INCOMPLETE
  local assertions_snapshot=$_BASHUNIT_ASSERTIONS_SNAPSHOT
  local assertions_failed=$_BASHUNIT_ASSERTIONS_FAILED

  local total_tests=0
  ((total_tests += tests_passed)) || true
  ((total_tests += tests_skipped)) || true
  ((total_tests += tests_incomplete)) || true
  ((total_tests += tests_snapshot)) || true
  ((total_tests += tests_failed)) || true

  local total_assertions=0
  ((total_assertions += assertions_passed)) || true
  ((total_assertions += assertions_skipped)) || true
  ((total_assertions += assertions_incomplete)) || true
  ((total_assertions += assertions_snapshot)) || true
  ((total_assertions += assertions_failed)) || true

  printf "%sTests:     %s" "$_BASHUNIT_COLOR_FAINT" "$_BASHUNIT_COLOR_DEFAULT"
  if [[ "$tests_passed" -gt 0 ]] || [[ "$assertions_passed" -gt 0 ]]; then
    printf " %s%s passed%s," "$_BASHUNIT_COLOR_PASSED" "$tests_passed" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [[ "$tests_skipped" -gt 0 ]] || [[ "$assertions_skipped" -gt 0 ]]; then
    printf " %s%s skipped%s," "$_BASHUNIT_COLOR_SKIPPED" "$tests_skipped" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [[ "$tests_incomplete" -gt 0 ]] || [[ "$assertions_incomplete" -gt 0 ]]; then
    printf " %s%s incomplete%s," "$_BASHUNIT_COLOR_INCOMPLETE" "$tests_incomplete" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [[ "$tests_snapshot" -gt 0 ]] || [[ "$assertions_snapshot" -gt 0 ]]; then
    printf " %s%s snapshot%s," "$_BASHUNIT_COLOR_SNAPSHOT" "$tests_snapshot" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [[ "$tests_failed" -gt 0 ]] || [[ "$assertions_failed" -gt 0 ]]; then
    printf " %s%s failed%s," "$_BASHUNIT_COLOR_FAILED" "$tests_failed" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  printf " %s total\n" "$total_tests"

  printf "%sAssertions:%s" "$_BASHUNIT_COLOR_FAINT" "$_BASHUNIT_COLOR_DEFAULT"
  if [[ "$tests_passed" -gt 0 ]] || [[ "$assertions_passed" -gt 0 ]]; then
      printf " %s%s passed%s," "$_BASHUNIT_COLOR_PASSED" "$assertions_passed" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [[ "$tests_skipped" -gt 0 ]] || [[ "$assertions_skipped" -gt 0 ]]; then
    printf " %s%s skipped%s," "$_BASHUNIT_COLOR_SKIPPED" "$assertions_skipped" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [[ "$tests_incomplete" -gt 0 ]] || [[ "$assertions_incomplete" -gt 0 ]]; then
    printf " %s%s incomplete%s," "$_BASHUNIT_COLOR_INCOMPLETE" "$assertions_incomplete" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [[ "$tests_snapshot" -gt 0 ]] || [[ "$assertions_snapshot" -gt 0 ]]; then
    printf " %s%s snapshot%s," "$_BASHUNIT_COLOR_SNAPSHOT" "$assertions_snapshot" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [[ "$tests_failed" -gt 0 ]] || [[ "$assertions_failed" -gt 0 ]]; then
    printf " %s%s failed%s," "$_BASHUNIT_COLOR_FAILED" "$assertions_failed" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  printf " %s total\n" "$total_assertions"

  if [[ "$tests_failed" -gt 0 ]]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_ERROR" " Some tests failed " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 1
  fi

  if [[ "$tests_incomplete" -gt 0 ]]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_INCOMPLETE" " Some tests incomplete " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 0
  fi

  if [[ "$tests_skipped" -gt 0 ]]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_SKIPPED" " Some tests skipped " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 0
  fi

  if [[ "$tests_snapshot" -gt 0 ]]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_SNAPSHOT" " Some snapshots created " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 0
  fi

  if [[ $total_tests -eq 0 ]]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_ERROR" " No tests found " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 1
  fi

  printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_SUCCESS" " All tests passed " "$_BASHUNIT_COLOR_DEFAULT"
  bashunit::console_results::print_execution_time
  return 0
}

function bashunit::console_results::print_execution_time() {
  if ! bashunit::env::is_show_execution_time_enabled; then
    return
  fi

  local time=$(bashunit::clock::total_runtime_in_milliseconds | awk '{printf "%.0f", $1}')

  if [[ "$time" -lt 1000 ]]; then
    printf "${_BASHUNIT_COLOR_BOLD}%s${_BASHUNIT_COLOR_DEFAULT}\n" \
      "Time taken: ${time}ms"
    return
  fi

  local time_in_seconds=$(( time / 1000 ))

  if [[ "$time_in_seconds" -ge 60 ]]; then
    local minutes=$(( time_in_seconds / 60 ))
    local seconds=$(( time_in_seconds % 60 ))
    printf "${_BASHUNIT_COLOR_BOLD}%s${_BASHUNIT_COLOR_DEFAULT}\n" \
      "Time taken: ${minutes}m ${seconds}s"
    return
  fi

  local formatted_seconds
  formatted_seconds=$(awk "BEGIN {printf \"%.2f\", $time / 1000}")

  printf "${_BASHUNIT_COLOR_BOLD}%s${_BASHUNIT_COLOR_DEFAULT}\n" \
    "Time taken: ${formatted_seconds}s"
}

function bashunit::console_results::format_duration() {
  local duration_ms="$1"

  if [[ "$duration_ms" -ge 60000 ]]; then
    local time_in_seconds=$(( duration_ms / 1000 ))
    local minutes=$(( time_in_seconds / 60 ))
    local seconds=$(( time_in_seconds % 60 ))
    echo "${minutes}m ${seconds}s"
  elif [[ "$duration_ms" -ge 1000 ]]; then
    local formatted_seconds
    formatted_seconds=$(awk "BEGIN {printf \"%.2f\", $duration_ms / 1000}")
    echo "${formatted_seconds}s"
  else
    echo "${duration_ms}ms"
  fi
}

function bashunit::console_results::print_hook_running() {
  local hook_name="$1"

  if bashunit::env::is_failures_only_enabled; then
    return
  fi

  if bashunit::parallel::is_enabled; then
    return
  fi

  if bashunit::env::is_simple_output_enabled; then
    printf "${_BASHUNIT_COLOR_FAINT}[%s...${_BASHUNIT_COLOR_DEFAULT}" "$hook_name"
  else
    printf "  ${_BASHUNIT_COLOR_FAINT}Running %s...${_BASHUNIT_COLOR_DEFAULT}" "$hook_name"
  fi
}

function bashunit::console_results::print_hook_completed() {
  local hook_name="$1"
  local duration_ms="$2"

  if bashunit::env::is_failures_only_enabled; then
    return
  fi

  if bashunit::parallel::is_enabled; then
    return
  fi

  local time_display
  time_display=$(bashunit::console_results::format_duration "$duration_ms")

  if bashunit::env::is_simple_output_enabled; then
    printf " %s] " "$time_display"
  else
    printf " %sdone%s %s(%s)%s\n" \
      "$_BASHUNIT_COLOR_PASSED" "$_BASHUNIT_COLOR_DEFAULT" \
      "$_BASHUNIT_COLOR_FAINT" "$time_display" "$_BASHUNIT_COLOR_DEFAULT"
  fi
}

function bashunit::console_results::print_successful_test() {
  local test_name=$1
  shift
  local duration=${1:-"0"}
  shift

  local line
  if [[ -z "$*" ]]; then
    line=$(printf "%s✓ Passed%s: %s" "$_BASHUNIT_COLOR_PASSED" "$_BASHUNIT_COLOR_DEFAULT" "$test_name")
  else
    local quoted_args=""
    for arg in "$@"; do
      if [[ -z "$quoted_args" ]]; then
        quoted_args="'$arg'"
      else
        quoted_args="$quoted_args, '$arg'"
      fi
    done
    line=$(printf "%s✓ Passed%s: %s (%s)" \
      "$_BASHUNIT_COLOR_PASSED" "$_BASHUNIT_COLOR_DEFAULT" "$test_name" "$quoted_args")
  fi

  local full_line=$line
  if bashunit::env::is_show_execution_time_enabled; then
    local time_display
    if [[ "$duration" -ge 60000 ]]; then
      local time_in_seconds=$(( duration / 1000 ))
      local minutes=$(( time_in_seconds / 60 ))
      local seconds=$(( time_in_seconds % 60 ))
      time_display="${minutes}m ${seconds}s"
    elif [[ "$duration" -ge 1000 ]]; then
      local formatted_seconds
      formatted_seconds=$(awk "BEGIN {printf \"%.2f\", $duration / 1000}")
      time_display="${formatted_seconds}s"
    else
      time_display="${duration}ms"
    fi
    full_line="$(printf "%s\n" "$(bashunit::str::rpad "$line" "$time_display")")"
  fi

  bashunit::state::print_line "successful" "$full_line"
}

function bashunit::console_results::print_failure_message() {
  local test_name=$1
  local failure_message=$2

  local line
  line="$(printf "\
${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT}: %s
    ${_BASHUNIT_COLOR_FAINT}Message:${_BASHUNIT_COLOR_DEFAULT} ${_BASHUNIT_COLOR_BOLD}'%s'${_BASHUNIT_COLOR_DEFAULT}\n"\
    "${test_name}" "${failure_message}")"

  bashunit::state::print_line "failure" "$line"
}

function bashunit::console_results::print_failed_test() {
  local function_name=$1
  local expected=$2
  local failure_condition_message=$3
  local actual=$4
  local extra_key=${5-}
  local extra_value=${6-}

  local line
  line="$(printf "\
${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT}: %s
    ${_BASHUNIT_COLOR_FAINT}Expected${_BASHUNIT_COLOR_DEFAULT} ${_BASHUNIT_COLOR_BOLD}'%s'${_BASHUNIT_COLOR_DEFAULT}
    ${_BASHUNIT_COLOR_FAINT}%s${_BASHUNIT_COLOR_DEFAULT} ${_BASHUNIT_COLOR_BOLD}'%s'${_BASHUNIT_COLOR_DEFAULT}\n" \
    "${function_name}" "${expected}" "${failure_condition_message}" "${actual}")"

  if [ -n "$extra_key" ]; then
    line+="$(printf "\

    ${_BASHUNIT_COLOR_FAINT}%s${_BASHUNIT_COLOR_DEFAULT} ${_BASHUNIT_COLOR_BOLD}'%s'${_BASHUNIT_COLOR_DEFAULT}\n" \
    "${extra_key}" "${extra_value}")"
  fi

  bashunit::state::print_line "failed" "$line"
}


function bashunit::console_results::print_failed_snapshot_test() {
  local function_name=$1
  local snapshot_file=$2
  local actual_content=${3-}

  local line
  line="$(printf "${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT}: %s
    ${_BASHUNIT_COLOR_FAINT}Expected to match the snapshot${_BASHUNIT_COLOR_DEFAULT}\n" "$function_name")"

  if bashunit::dependencies::has_git; then
    local actual_file="${snapshot_file}.tmp"
    echo "$actual_content" > "$actual_file"

    local git_diff_output
    git_diff_output="$(git diff --no-index --word-diff --color=always \
      "$snapshot_file" "$actual_file" 2>/dev/null \
        | tail -n +6 | sed "s/^/    /")"

    line+="$git_diff_output"
    rm "$actual_file"
  fi

  bashunit::state::print_line "failed_snapshot" "$line"
}

function bashunit::console_results::print_skipped_test() {
  local function_name=$1
  local reason=${2-}

  local line
  line="$(printf "${_BASHUNIT_COLOR_SKIPPED}↷ Skipped${_BASHUNIT_COLOR_DEFAULT}: %s\n" "${function_name}")"

  if [[ -n "$reason" ]]; then
    line+="$(printf "${_BASHUNIT_COLOR_FAINT}    %s${_BASHUNIT_COLOR_DEFAULT}\n" "${reason}")"
  fi

  bashunit::state::print_line "skipped" "$line"
}

function bashunit::console_results::print_incomplete_test() {
  local function_name=$1
  local pending=${2-}

  local line
  line="$(printf "${_BASHUNIT_COLOR_INCOMPLETE}✒ Incomplete${_BASHUNIT_COLOR_DEFAULT}: %s\n" "${function_name}")"

  if [[ -n "$pending" ]]; then
    line+="$(printf "${_BASHUNIT_COLOR_FAINT}    %s${_BASHUNIT_COLOR_DEFAULT}\n" "${pending}")"
  fi

  bashunit::state::print_line "incomplete" "$line"
}

function bashunit::console_results::print_snapshot_test() {
  local function_name=$1
  local test_name
  test_name=$(bashunit::helper::normalize_test_function_name "$function_name")

  local line
  line="$(printf "${_BASHUNIT_COLOR_SNAPSHOT}✎ Snapshot${_BASHUNIT_COLOR_DEFAULT}: %s\n" "${test_name}")"

  bashunit::state::print_line "snapshot" "$line"
}

function bashunit::console_results::print_error_test() {
  local function_name=$1
  local error="$2"

  local test_name
  test_name=$(bashunit::helper::normalize_test_function_name "$function_name")

  local line
  line="$(printf "${_BASHUNIT_COLOR_FAILED}✗ Error${_BASHUNIT_COLOR_DEFAULT}: %s
    ${_BASHUNIT_COLOR_FAINT}%s${_BASHUNIT_COLOR_DEFAULT}\n" "${test_name}" "${error}")"

  bashunit::state::print_line "error" "$line"
}

function bashunit::console_results::print_failing_tests_and_reset() {
  if [[ -s "$FAILURES_OUTPUT_PATH" ]]; then
    local total_failed
    total_failed=$(bashunit::state::get_tests_failed)

    if bashunit::env::is_simple_output_enabled; then
      printf "\n\n"
    fi

    if [[ "$total_failed" -eq 1 ]]; then
      echo -e "${_BASHUNIT_COLOR_BOLD}There was 1 failure:${_BASHUNIT_COLOR_DEFAULT}\n"
    else
      echo -e "${_BASHUNIT_COLOR_BOLD}There were $total_failed failures:${_BASHUNIT_COLOR_DEFAULT}\n"
    fi

    sed '${/^$/d;}' "$FAILURES_OUTPUT_PATH" | sed 's/^/|/'
    rm "$FAILURES_OUTPUT_PATH"

    echo ""
  fi
}

function bashunit::console_results::print_skipped_tests_and_reset() {
  if [[ -s "$SKIPPED_OUTPUT_PATH" ]] && bashunit::env::is_show_skipped_enabled; then
    local total_skipped
    total_skipped=$(bashunit::state::get_tests_skipped)

    if bashunit::env::is_simple_output_enabled; then
      printf "\n"
    fi

    if [[ "$total_skipped" -eq 1 ]]; then
      echo -e "${_BASHUNIT_COLOR_BOLD}There was 1 skipped test:${_BASHUNIT_COLOR_DEFAULT}\n"
    else
      echo -e "${_BASHUNIT_COLOR_BOLD}There were $total_skipped skipped tests:${_BASHUNIT_COLOR_DEFAULT}\n"
    fi

    tr -d '\r' < "$SKIPPED_OUTPUT_PATH" | sed '/^[[:space:]]*$/d' | sed 's/^/|/'
    rm "$SKIPPED_OUTPUT_PATH"

    echo ""
  fi
}

function bashunit::console_results::print_incomplete_tests_and_reset() {
  if [[ -s "$INCOMPLETE_OUTPUT_PATH" ]] && bashunit::env::is_show_incomplete_enabled; then
    local total_incomplete
    total_incomplete=$(bashunit::state::get_tests_incomplete)

    if bashunit::env::is_simple_output_enabled; then
      printf "\n"
    fi

    if [[ "$total_incomplete" -eq 1 ]]; then
      echo -e "${_BASHUNIT_COLOR_BOLD}There was 1 incomplete test:${_BASHUNIT_COLOR_DEFAULT}\n"
    else
      echo -e "${_BASHUNIT_COLOR_BOLD}There were $total_incomplete incomplete tests:${_BASHUNIT_COLOR_DEFAULT}\n"
    fi

    tr -d '\r' < "$INCOMPLETE_OUTPUT_PATH" | sed '/^[[:space:]]*$/d' | sed 's/^/|/'
    rm "$INCOMPLETE_OUTPUT_PATH"

    echo ""
  fi
}
