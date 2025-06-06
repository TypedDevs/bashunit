#!/usr/bin/env bash

function main::exec_tests() {
  local filter=$1
  local files=("${@:2}")

  local test_files=()
  while IFS= read -r line; do
    test_files+=("$line")
  done < <(helper::load_test_files "$filter" "${files[@]}")

  if [[ ${#test_files[@]} -eq 0 || -z "${test_files[0]}" ]]; then
    printf "%sError: At least one file path is required.%s\n" "${_COLOR_FAILED}" "${_COLOR_DEFAULT}"
    console_header::print_help
    exit 1
  fi

  # Trap SIGINT (Ctrl-C) and call the cleanup function
  trap 'main::cleanup' SIGINT
  trap '[[ $? -eq $EXIT_CODE_STOP_ON_FAILURE ]] && main::handle_stop_on_failure_sync' EXIT

  if env::is_parallel_run_enabled && ! parallel::is_enabled; then
    printf "%sWarning: Parallel tests are supported on macOS, Ubuntu and Windows.\n" "${_COLOR_INCOMPLETE}"
    printf "For other OS (like Alpine), --parallel is not enabled due to inconsistent results,\n"
    printf "particularly involving race conditions.%s " "${_COLOR_DEFAULT}"
    printf "%sFallback using --no-parallel%s\n" "${_COLOR_SKIPPED}" "${_COLOR_DEFAULT}"
  fi

  if parallel::is_enabled; then
    parallel::reset
  fi

  console_header::print_version_with_env "$filter" "${test_files[@]}"

  if env::is_verbose_enabled; then
    if env::is_simple_output_enabled; then
      echo ""
    fi
    printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '#'
    printf "%s\n" "Filter:      ${filter:-None}"
    printf "%s\n" "Total files: ${#test_files[@]}"
    printf "%s\n" "Test files:"
    printf -- "- %s\n" "${test_files[@]}"
    printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '.'
    env::print_verbose
    printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '#'
  fi

  runner::load_test_files "$filter" "${test_files[@]}"

  if parallel::is_enabled; then
    wait
  fi

  if parallel::is_enabled && parallel::must_stop_on_failure; then
    printf "\r%sStop on failure enabled...%s\n"  "${_COLOR_SKIPPED}" "${_COLOR_DEFAULT}"
  fi

  console_results::print_failing_tests_and_reset
  console_results::render_result
  exit_code=$?

  if [[ -n "$BASHUNIT_LOG_JUNIT" ]]; then
    reports::generate_junit_xml "$BASHUNIT_LOG_JUNIT"
  fi

  if [[ -n "$BASHUNIT_REPORT_HTML" ]]; then
    reports::generate_report_html "$BASHUNIT_REPORT_HTML"
  fi

  cleanup_temp_files
  exit $exit_code
}

function main::exec_benchmarks() {
  local filter=$1
  local files=("${@:2}")

  local bench_files=()
  while IFS= read -r line; do
    bench_files+=("$line")
  done < <(helper::load_bench_files "$filter" "${files[@]}")

  if [[ ${#bench_files[@]} -eq 0 || -z "${bench_files[0]}" ]]; then
    printf "%sError: At least one file path is required.%s\n" "${_COLOR_FAILED}" "${_COLOR_DEFAULT}"
    console_header::print_help
    exit 1
  fi

  console_header::print_version_with_env "$filter" "${bench_files[@]}"

  runner::load_bench_files "$filter" "${bench_files[@]}"

  benchmark::print_results

  cleanup_temp_files
}

function main::cleanup() {
  printf "%sCaught Ctrl-C, killing all child processes...%s\n"  "${_COLOR_SKIPPED}" "${_COLOR_DEFAULT}"
  # Kill all child processes of this script
  pkill -P $$
  cleanup_temp_files
  exit 1
}

function main::handle_stop_on_failure_sync() {
  printf "\n%sStop on failure enabled...%s\n"  "${_COLOR_SKIPPED}" "${_COLOR_DEFAULT}"
  console_results::print_failing_tests_and_reset
  console_results::render_result
  cleanup_temp_files
  exit 1
}

function main::exec_assert() {
  local original_assert_fn=$1
  local args=("${@:2}")

  local assert_fn=$original_assert_fn

  # Check if the function exists
  if ! type "$assert_fn" > /dev/null 2>&1; then
    assert_fn="assert_$assert_fn"
    if ! type "$assert_fn" > /dev/null 2>&1; then
      echo "Function $original_assert_fn does not exist." 1>&2
      exit 127
    fi
  fi

  # Get the last argument safely by calculating the array length
  local last_index=$((${#args[@]} - 1))
  local last_arg="${args[$last_index]}"
  local output=""
  local inner_exit_code=0
  local bashunit_exit_code=0

  # Handle different assert_* functions
  case "$assert_fn" in
    assert_exit_code)
      output=$(main::handle_assert_exit_code "$last_arg")
      inner_exit_code=$?
      # Remove the last argument and append the exit code
      args=("${args[@]:0:last_index}")
      args+=("$inner_exit_code")
      ;;
    *)
      # Add more cases here for other assert_* handlers if needed
      ;;
  esac

  if [[ -n "$output" ]]; then
    echo "$output" 1>&1
    assert_fn="assert_same"
  fi

  # Run the assertion function and write into stderr
  "$assert_fn" "${args[@]}" 1>&2
  bashunit_exit_code=$?

  if [[ "$(state::get_tests_failed)" -gt 0 ]] || [[ "$(state::get_assertions_failed)" -gt 0 ]]; then
    return 1
  fi

  return "$bashunit_exit_code"
}

function main::handle_assert_exit_code() {
  local cmd="$1"
  local output
  local inner_exit_code=0

  if [[ $(command -v "${cmd%% *}") ]]; then
    output=$(eval "$cmd" 2>&1 || echo "inner_exit_code:$?")
    local last_line
    last_line=$(echo "$output" | tail -n 1)
    if echo "$last_line" | grep -q 'inner_exit_code:[0-9]*'; then
      inner_exit_code=$(echo "$last_line" | grep -o 'inner_exit_code:[0-9]*' | cut -d':' -f2)
      if ! [[ $inner_exit_code =~ ^[0-9]+$ ]]; then
        inner_exit_code=1
      fi
      output=$(echo "$output" | sed '$d')
    fi
    echo "$output"
    return "$inner_exit_code"
  else
    echo "Command not found: $cmd" 1>&2
    return 127
  fi
}
