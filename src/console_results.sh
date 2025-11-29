#!/usr/bin/env bash
# shellcheck disable=SC2155

_TOTAL_TESTS_COUNT=0

function console_results::render_result() {
  if [[ "$(state::is_duplicated_test_functions_found)" == true ]]; then
    console_results::print_execution_time
    printf "%s%s%s\n" "${_COLOR_RETURN_ERROR}" "Duplicate test functions found" "${_COLOR_DEFAULT}"
    printf "File with duplicate functions: %s\n" "$(state::get_file_with_duplicated_function_names)"
    printf "Duplicate functions: %s\n" "$(state::get_duplicated_function_names)"
    return 1
  fi

  if env::is_simple_output_enabled; then
    printf "\n\n"
  fi

  # Cache state values to avoid repeated subshell invocations
  local tests_passed=$_TESTS_PASSED
  local tests_skipped=$_TESTS_SKIPPED
  local tests_incomplete=$_TESTS_INCOMPLETE
  local tests_snapshot=$_TESTS_SNAPSHOT
  local tests_failed=$_TESTS_FAILED
  local assertions_passed=$_ASSERTIONS_PASSED
  local assertions_skipped=$_ASSERTIONS_SKIPPED
  local assertions_incomplete=$_ASSERTIONS_INCOMPLETE
  local assertions_snapshot=$_ASSERTIONS_SNAPSHOT
  local assertions_failed=$_ASSERTIONS_FAILED

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

  printf "%sTests:     %s" "$_COLOR_FAINT" "$_COLOR_DEFAULT"
  if [[ "$tests_passed" -gt 0 ]] || [[ "$assertions_passed" -gt 0 ]]; then
    printf " %s%s passed%s," "$_COLOR_PASSED" "$tests_passed" "$_COLOR_DEFAULT"
  fi
  if [[ "$tests_skipped" -gt 0 ]] || [[ "$assertions_skipped" -gt 0 ]]; then
    printf " %s%s skipped%s," "$_COLOR_SKIPPED" "$tests_skipped" "$_COLOR_DEFAULT"
  fi
  if [[ "$tests_incomplete" -gt 0 ]] || [[ "$assertions_incomplete" -gt 0 ]]; then
    printf " %s%s incomplete%s," "$_COLOR_INCOMPLETE" "$tests_incomplete" "$_COLOR_DEFAULT"
  fi
  if [[ "$tests_snapshot" -gt 0 ]] || [[ "$assertions_snapshot" -gt 0 ]]; then
    printf " %s%s snapshot%s," "$_COLOR_SNAPSHOT" "$tests_snapshot" "$_COLOR_DEFAULT"
  fi
  if [[ "$tests_failed" -gt 0 ]] || [[ "$assertions_failed" -gt 0 ]]; then
    printf " %s%s failed%s," "$_COLOR_FAILED" "$tests_failed" "$_COLOR_DEFAULT"
  fi
  printf " %s total\n" "$total_tests"

  printf "%sAssertions:%s" "$_COLOR_FAINT" "$_COLOR_DEFAULT"
  if [[ "$tests_passed" -gt 0 ]] || [[ "$assertions_passed" -gt 0 ]]; then
      printf " %s%s passed%s," "$_COLOR_PASSED" "$assertions_passed" "$_COLOR_DEFAULT"
  fi
  if [[ "$tests_skipped" -gt 0 ]] || [[ "$assertions_skipped" -gt 0 ]]; then
    printf " %s%s skipped%s," "$_COLOR_SKIPPED" "$assertions_skipped" "$_COLOR_DEFAULT"
  fi
  if [[ "$tests_incomplete" -gt 0 ]] || [[ "$assertions_incomplete" -gt 0 ]]; then
    printf " %s%s incomplete%s," "$_COLOR_INCOMPLETE" "$assertions_incomplete" "$_COLOR_DEFAULT"
  fi
  if [[ "$tests_snapshot" -gt 0 ]] || [[ "$assertions_snapshot" -gt 0 ]]; then
    printf " %s%s snapshot%s," "$_COLOR_SNAPSHOT" "$assertions_snapshot" "$_COLOR_DEFAULT"
  fi
  if [[ "$tests_failed" -gt 0 ]] || [[ "$assertions_failed" -gt 0 ]]; then
    printf " %s%s failed%s," "$_COLOR_FAILED" "$assertions_failed" "$_COLOR_DEFAULT"
  fi
  printf " %s total\n" "$total_assertions"

  if [[ "$tests_failed" -gt 0 ]]; then
    printf "\n%s%s%s\n" "$_COLOR_RETURN_ERROR" " Some tests failed " "$_COLOR_DEFAULT"
    console_results::print_execution_time
    return 1
  fi

  if [[ "$tests_incomplete" -gt 0 ]]; then
    printf "\n%s%s%s\n" "$_COLOR_RETURN_INCOMPLETE" " Some tests incomplete " "$_COLOR_DEFAULT"
    console_results::print_execution_time
    return 0
  fi

  if [[ "$tests_skipped" -gt 0 ]]; then
    printf "\n%s%s%s\n" "$_COLOR_RETURN_SKIPPED" " Some tests skipped " "$_COLOR_DEFAULT"
    console_results::print_execution_time
    return 0
  fi

  if [[ "$tests_snapshot" -gt 0 ]]; then
    printf "\n%s%s%s\n" "$_COLOR_RETURN_SNAPSHOT" " Some snapshots created " "$_COLOR_DEFAULT"
    console_results::print_execution_time
    return 0
  fi

  if [[ $total_tests -eq 0 ]]; then
    printf "\n%s%s%s\n" "$_COLOR_RETURN_ERROR" " No tests found " "$_COLOR_DEFAULT"
    console_results::print_execution_time
    return 1
  fi

  printf "\n%s%s%s\n" "$_COLOR_RETURN_SUCCESS" " All tests passed " "$_COLOR_DEFAULT"
  console_results::print_execution_time
  return 0
}

function console_results::print_execution_time() {
  if ! env::is_show_execution_time_enabled; then
    return
  fi

  local time=$(clock::total_runtime_in_milliseconds | awk '{printf "%.0f", $1}')

  if [[ "$time" -lt 1000 ]]; then
    printf "${_COLOR_BOLD}%s${_COLOR_DEFAULT}\n" \
      "Time taken: $time ms"
    return
  fi

  local time_in_seconds=$(( time / 1000 ))
  local remainder_ms=$(( time % 1000 ))
  local formatted_seconds=$(echo "$time_in_seconds.$remainder_ms" | awk '{printf "%.0f", $1}')

  printf "${_COLOR_BOLD}%s${_COLOR_DEFAULT}\n" \
    "Time taken: $formatted_seconds s"
}

function console_results::print_successful_test() {
  local test_name=$1
  shift
  local duration=${1:-"0"}
  shift

  local line
  if [[ -z "$*" ]]; then
    line=$(printf "%s✓ Passed%s: %s" "$_COLOR_PASSED" "$_COLOR_DEFAULT" "$test_name")
  else
    local quoted_args=""
    for arg in "$@"; do
      if [[ -z "$quoted_args" ]]; then
        quoted_args="'$arg'"
      else
        quoted_args="$quoted_args, '$arg'"
      fi
    done
    line=$(printf "%s✓ Passed%s: %s (%s)" "$_COLOR_PASSED" "$_COLOR_DEFAULT" "$test_name" "$quoted_args")
  fi

  local full_line=$line
  if env::is_show_execution_time_enabled; then
    full_line="$(printf "%s\n" "$(str::rpad "$line" "$duration ms")")"
  fi

  state::print_line "successful" "$full_line"
}

function console_results::print_failure_message() {
  local test_name=$1
  local failure_message=$2

  local line
  line="$(printf "\
${_COLOR_FAILED}✗ Failed${_COLOR_DEFAULT}: %s
    ${_COLOR_FAINT}Message:${_COLOR_DEFAULT} ${_COLOR_BOLD}'%s'${_COLOR_DEFAULT}\n"\
    "${test_name}" "${failure_message}")"

  state::print_line "failure" "$line"
}

function console_results::print_failed_test() {
  local function_name=$1
  local expected=$2
  local failure_condition_message=$3
  local actual=$4
  local extra_key=${5-}
  local extra_value=${6-}

  local line
  line="$(printf "\
${_COLOR_FAILED}✗ Failed${_COLOR_DEFAULT}: %s
    ${_COLOR_FAINT}Expected${_COLOR_DEFAULT} ${_COLOR_BOLD}'%s'${_COLOR_DEFAULT}
    ${_COLOR_FAINT}%s${_COLOR_DEFAULT} ${_COLOR_BOLD}'%s'${_COLOR_DEFAULT}\n" \
    "${function_name}" "${expected}" "${failure_condition_message}" "${actual}")"

  if [ -n "$extra_key" ]; then
    line+="$(printf "\

    ${_COLOR_FAINT}%s${_COLOR_DEFAULT} ${_COLOR_BOLD}'%s'${_COLOR_DEFAULT}\n" \
    "${extra_key}" "${extra_value}")"
  fi

  state::print_line "failed" "$line"
}


function console_results::print_failed_snapshot_test() {
  local function_name=$1
  local snapshot_file=$2
  local actual_content=${3-}

  local line
  line="$(printf "${_COLOR_FAILED}✗ Failed${_COLOR_DEFAULT}: %s
    ${_COLOR_FAINT}Expected to match the snapshot${_COLOR_DEFAULT}\n" "$function_name")"

  if dependencies::has_git; then
    local actual_file="${snapshot_file}.tmp"
    echo "$actual_content" > "$actual_file"

    local git_diff_output
    git_diff_output="$(git diff --no-index --word-diff --color=always \
      "$snapshot_file" "$actual_file" 2>/dev/null \
        | tail -n +6 | sed "s/^/    /")"

    line+="$git_diff_output"
    rm "$actual_file"
  fi

  state::print_line "failed_snapshot" "$line"
}

function console_results::print_skipped_test() {
  local function_name=$1
  local reason=${2-}

  local line
  line="$(printf "${_COLOR_SKIPPED}↷ Skipped${_COLOR_DEFAULT}: %s\n" "${function_name}")"

  if [[ -n "$reason" ]]; then
    line+="$(printf "${_COLOR_FAINT}    %s${_COLOR_DEFAULT}\n" "${reason}")"
  fi

  state::print_line "skipped" "$line"
}

function console_results::print_incomplete_test() {
  local function_name=$1
  local pending=${2-}

  local line
  line="$(printf "${_COLOR_INCOMPLETE}✒ Incomplete${_COLOR_DEFAULT}: %s\n" "${function_name}")"

  if [[ -n "$pending" ]]; then
    line+="$(printf "${_COLOR_FAINT}    %s${_COLOR_DEFAULT}\n" "${pending}")"
  fi

  state::print_line "incomplete" "$line"
}

function console_results::print_snapshot_test() {
  local function_name=$1
  local test_name
  test_name=$(helper::normalize_test_function_name "$function_name")

  local line
  line="$(printf "${_COLOR_SNAPSHOT}✎ Snapshot${_COLOR_DEFAULT}: %s\n" "${test_name}")"

  state::print_line "snapshot" "$line"
}

function console_results::print_error_test() {
  local function_name=$1
  local error="$2"

  local test_name
  test_name=$(helper::normalize_test_function_name "$function_name")

  local line
  line="$(printf "${_COLOR_FAILED}✗ Error${_COLOR_DEFAULT}: %s
    ${_COLOR_FAINT}%s${_COLOR_DEFAULT}\n" "${test_name}" "${error}")"

  state::print_line "error" "$line"
}

function console_results::print_failing_tests_and_reset() {
  if [[ -s "$FAILURES_OUTPUT_PATH" ]]; then
    local total_failed
    total_failed=$(state::get_tests_failed)

    if env::is_simple_output_enabled; then
      printf "\n\n"
    fi

    if [[ "$total_failed" -eq 1 ]]; then
      echo -e "${_COLOR_BOLD}There was 1 failure:${_COLOR_DEFAULT}\n"
    else
      echo -e "${_COLOR_BOLD}There were $total_failed failures:${_COLOR_DEFAULT}\n"
    fi

    sed '${/^$/d;}' "$FAILURES_OUTPUT_PATH" | sed 's/^/|/'
    rm "$FAILURES_OUTPUT_PATH"

    echo ""
  fi
}

function console_results::print_skipped_tests_and_reset() {
  if [[ -s "$SKIPPED_OUTPUT_PATH" ]] && env::is_show_skipped_enabled; then
    local total_skipped
    total_skipped=$(state::get_tests_skipped)

    if [[ "$total_skipped" -eq 1 ]]; then
      echo -e "${_COLOR_BOLD}There was 1 skipped test:${_COLOR_DEFAULT}\n"
    else
      echo -e "${_COLOR_BOLD}There were $total_skipped skipped tests:${_COLOR_DEFAULT}\n"
    fi

    sed '${/^$/d;}' "$SKIPPED_OUTPUT_PATH" | sed 's/^/|/'
    rm "$SKIPPED_OUTPUT_PATH"

    echo ""
  fi
}

function console_results::print_incomplete_tests_and_reset() {
  if [[ -s "$INCOMPLETE_OUTPUT_PATH" ]] && env::is_show_incomplete_enabled; then
    local total_incomplete
    total_incomplete=$(state::get_tests_incomplete)

    if [[ "$total_incomplete" -eq 1 ]]; then
      echo -e "${_COLOR_BOLD}There was 1 incomplete test:${_COLOR_DEFAULT}\n"
    else
      echo -e "${_COLOR_BOLD}There were $total_incomplete incomplete tests:${_COLOR_DEFAULT}\n"
    fi

    sed '${/^$/d;}' "$INCOMPLETE_OUTPUT_PATH" | sed 's/^/|/'
    rm "$INCOMPLETE_OUTPUT_PATH"

    echo ""
  fi
}
