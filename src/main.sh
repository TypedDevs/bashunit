#!/usr/bin/env bash

#############################
# Subcommand: test
#############################
function bashunit::main::cmd_test() {
  local filter=""
  local raw_args=()
  local args=()
  local assert_fn=""

  # Parse test-specific options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a|--assert)
        assert_fn="$2"
        shift
        ;;
      -f|--filter)
        filter="$2"
        shift
        ;;
      -s|--simple)
        export BASHUNIT_SIMPLE_OUTPUT=true
        ;;
      --detailed)
        export BASHUNIT_SIMPLE_OUTPUT=false
        ;;
      --debug)
        local output_file="${2:-}"
        if [[ -n "$output_file" && "${output_file:0:1}" != "-" ]]; then
          exec > "$output_file" 2>&1
          shift
        fi
        set -x
        ;;
      -S|--stop-on-failure)
        export BASHUNIT_STOP_ON_FAILURE=true
        ;;
      -p|--parallel)
        export BASHUNIT_PARALLEL_RUN=true
        ;;
      --no-parallel)
        export BASHUNIT_PARALLEL_RUN=false
        ;;
      -e|--env|--boot)
        # shellcheck disable=SC1090
        source "$2"
        shift
        ;;
      -l|--log-junit)
        export BASHUNIT_LOG_JUNIT="$2"
        shift
        ;;
      -r|--report-html)
        export BASHUNIT_REPORT_HTML="$2"
        shift
        ;;
      --no-output)
        export BASHUNIT_NO_OUTPUT=true
        ;;
      -vvv|--verbose)
        export BASHUNIT_VERBOSE=true
        ;;
      -h|--help)
        bashunit::console_header::print_test_help
        exit 0
        ;;
      --show-skipped)
        export BASHUNIT_SHOW_SKIPPED=true
        ;;
      --show-incomplete)
        export BASHUNIT_SHOW_INCOMPLETE=true
        ;;
      *)
        raw_args+=("$1")
        ;;
    esac
    shift
  done

  # Expand positional arguments and extract inline filters
  # Skip filter parsing for assert mode - args are not file paths
  local inline_filter=""
  local inline_filter_file=""
  if [[ ${#raw_args[@]} -gt 0 ]]; then
    if [[ -n "$assert_fn" ]]; then
      # Assert mode: pass args as-is without file path processing
      args=("${raw_args[@]}")
    else
      # Test mode: process file paths and extract inline filters
      for arg in "${raw_args[@]}"; do
        local parsed_path parsed_filter
        {
          read -r parsed_path
          read -r parsed_filter
        } < <(bashunit::helper::parse_file_path_filter "$arg")

        # If an inline filter was found, store it
        if [[ -n "$parsed_filter" ]]; then
          inline_filter="$parsed_filter"
          inline_filter_file="$parsed_path"
        fi

        while IFS= read -r file; do
          args+=("$file")
        done < <(bashunit::helper::find_files_recursive "$parsed_path" '*[tT]est.sh')
      done

      # Resolve line number filter to function name
      if [[ "$inline_filter" == "__line__:"* ]]; then
        local line_number="${inline_filter#__line__:}"
        local resolved_file="${inline_filter_file}"

        # If the file path was a pattern, use the first resolved file
        if [[ ${#args[@]} -gt 0 ]]; then
          resolved_file="${args[0]}"
        fi

        inline_filter=$(bashunit::helper::find_function_at_line "$resolved_file" "$line_number")
        if [[ -z "$inline_filter" ]]; then
          printf "%sError: No test function found at line %s in %s%s\n" \
            "${_BASHUNIT_COLOR_FAILED}" "$line_number" "$resolved_file" "${_BASHUNIT_COLOR_DEFAULT}"
          exit 1
        fi
      fi

      # Use inline filter if no -f filter was provided
      if [[ -z "$filter" && -n "$inline_filter" ]]; then
        filter="$inline_filter"
      fi
    fi
  fi

  # Optional bootstrap
  # shellcheck disable=SC1090
  [[ -f "${BASHUNIT_BOOTSTRAP:-}" ]] && source "$BASHUNIT_BOOTSTRAP"

  if [[ "${BASHUNIT_NO_OUTPUT:-false}" == true ]]; then
    exec >/dev/null 2>&1
  fi

  set +eu

  # Execute
  if [[ -n "$assert_fn" ]]; then
    bashunit::main::exec_assert "$assert_fn" "${args[@]}"
  else
    bashunit::main::exec_tests "$filter" "${args[@]}"
  fi
}

#############################
# Subcommand: bench
#############################
function bashunit::main::cmd_bench() {
  local filter=""
  local raw_args=()
  local args=()

  export BASHUNIT_BENCH_MODE=true
  source "$BASHUNIT_ROOT_DIR/src/benchmark.sh"

  # Parse bench-specific options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--filter)
        filter="$2"
        shift
        ;;
      -s|--simple)
        export BASHUNIT_SIMPLE_OUTPUT=true
        ;;
      --detailed)
        export BASHUNIT_SIMPLE_OUTPUT=false
        ;;
      -e|--env|--boot)
        # shellcheck disable=SC1090
        source "$2"
        shift
        ;;
      -vvv|--verbose)
        export BASHUNIT_VERBOSE=true
        ;;
      -h|--help)
        bashunit::console_header::print_bench_help
        exit 0
        ;;
      *)
        raw_args+=("$1")
        ;;
    esac
    shift
  done

  # Expand positional arguments
  if [[ ${#raw_args[@]} -gt 0 ]]; then
    for arg in "${raw_args[@]}"; do
      while IFS= read -r file; do
        args+=("$file")
      done < <(bashunit::helper::find_files_recursive "$arg" '*[bB]ench.sh')
    done
  fi

  # Optional bootstrap
  # shellcheck disable=SC1090
  [[ -f "${BASHUNIT_BOOTSTRAP:-}" ]] && source "$BASHUNIT_BOOTSTRAP"

  set +eu

  bashunit::main::exec_benchmarks "$filter" "${args[@]}"
}

#############################
# Subcommand: doc
#############################
function bashunit::main::cmd_doc() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    bashunit::console_header::print_doc_help
    exit 0
  fi

  bashunit::doc::print_asserts "${1:-}"
  exit 0
}

#############################
# Subcommand: init
#############################
function bashunit::main::cmd_init() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    bashunit::console_header::print_init_help
    exit 0
  fi

  bashunit::init::project "${1:-}"
  exit 0
}

#############################
# Subcommand: learn
#############################
function bashunit::main::cmd_learn() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    bashunit::console_header::print_learn_help
    exit 0
  fi

  bashunit::learn::start
  exit 0
}

#############################
# Subcommand: upgrade
#############################
function bashunit::main::cmd_upgrade() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    bashunit::console_header::print_upgrade_help
    exit 0
  fi

  bashunit::upgrade::upgrade
  exit 0
}

#############################
# Test execution
#############################
function bashunit::main::exec_tests() {
  local filter=$1
  local files=("${@:2}")

  local test_files=()
  while IFS= read -r line; do
    test_files+=("$line")
  done < <(bashunit::helper::load_test_files "$filter" "${files[@]}")

  bashunit::internal_log "exec_tests" "filter:$filter" "files:${test_files[*]}"

  if [[ ${#test_files[@]} -eq 0 || -z "${test_files[0]}" ]]; then
    printf "%sError: At least one file path is required.%s\n" "${_BASHUNIT_COLOR_FAILED}" "${_BASHUNIT_COLOR_DEFAULT}"
    bashunit::console_header::print_help
    exit 1
  fi

  # Trap SIGINT (Ctrl-C) and call the cleanup function
  trap 'bashunit::main::cleanup' SIGINT
  trap '[[ $? -eq $EXIT_CODE_STOP_ON_FAILURE ]] && bashunit::main::handle_stop_on_failure_sync' EXIT

  if bashunit::env::is_parallel_run_enabled && ! bashunit::parallel::is_enabled; then
    printf "%sWarning: Parallel tests are supported on macOS, Ubuntu and Windows.\n" "${_BASHUNIT_COLOR_INCOMPLETE}"
    printf "For other OS (like Alpine), --parallel is not enabled due to inconsistent results,\n"
    printf "particularly involving race conditions.%s " "${_BASHUNIT_COLOR_DEFAULT}"
    printf "%sFallback using --no-parallel%s\n" "${_BASHUNIT_COLOR_SKIPPED}" "${_BASHUNIT_COLOR_DEFAULT}"
  fi

  if bashunit::parallel::is_enabled; then
    bashunit::parallel::init
  fi

  bashunit::console_header::print_version_with_env "$filter" "${test_files[@]}"

  if bashunit::env::is_verbose_enabled; then
    if bashunit::env::is_simple_output_enabled; then
      echo ""
    fi
    printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '#'
    printf "%s\n" "Filter:      ${filter:-None}"
    printf "%s\n" "Total files: ${#test_files[@]}"
    printf "%s\n" "Test files:"
    printf -- "- %s\n" "${test_files[@]}"
    printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '.'
    bashunit::env::print_verbose
    printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '#'
  fi

  bashunit::runner::load_test_files "$filter" "${test_files[@]}"

  if bashunit::parallel::is_enabled; then
    wait
  fi

  if bashunit::parallel::is_enabled && bashunit::parallel::must_stop_on_failure; then
    printf "\r%sStop on failure enabled...%s\n"  "${_BASHUNIT_COLOR_SKIPPED}" "${_BASHUNIT_COLOR_DEFAULT}"
  fi

  bashunit::console_results::print_failing_tests_and_reset
  bashunit::console_results::print_incomplete_tests_and_reset
  bashunit::console_results::print_skipped_tests_and_reset
  bashunit::console_results::render_result
  exit_code=$?

  if [[ -n "$BASHUNIT_LOG_JUNIT" ]]; then
    bashunit::reports::generate_junit_xml "$BASHUNIT_LOG_JUNIT"
  fi

  if [[ -n "$BASHUNIT_REPORT_HTML" ]]; then
    bashunit::reports::generate_report_html "$BASHUNIT_REPORT_HTML"
  fi

  if bashunit::parallel::is_enabled; then
    bashunit::parallel::cleanup
  fi

  bashunit::internal_log "Finished tests" "exit_code:$exit_code"
  exit $exit_code
}

function bashunit::main::exec_benchmarks() {
  local filter=$1
  local files=("${@:2}")

  local bench_files=()
  while IFS= read -r line; do
    bench_files+=("$line")
  done < <(bashunit::helper::load_bench_files "$filter" "${files[@]}")

  bashunit::internal_log "exec_benchmarks" "filter:$filter" "files:${bench_files[*]}"

  if [[ ${#bench_files[@]} -eq 0 || -z "${bench_files[0]}" ]]; then
    printf "%sError: At least one file path is required.%s\n" "${_BASHUNIT_COLOR_FAILED}" "${_BASHUNIT_COLOR_DEFAULT}"
    bashunit::console_header::print_help
    exit 1
  fi

  bashunit::console_header::print_version_with_env "$filter" "${bench_files[@]}"

  bashunit::runner::load_bench_files "$filter" "${bench_files[@]}"

  bashunit::benchmark::print_results

  bashunit::internal_log "Finished benchmarks"
}

function bashunit::main::cleanup() {
  printf "%sCaught Ctrl-C, killing all child processes...%s\n" \
    "${_BASHUNIT_COLOR_SKIPPED}" "${_BASHUNIT_COLOR_DEFAULT}"
  # Kill all child processes of this script
  pkill -P $$
  bashunit::cleanup_script_temp_files
  if bashunit::parallel::is_enabled; then
    bashunit::parallel::cleanup
  fi
  exit 1
}

function bashunit::main::handle_stop_on_failure_sync() {
  printf "\n%sStop on failure enabled...%s\n"  "${_BASHUNIT_COLOR_SKIPPED}" "${_BASHUNIT_COLOR_DEFAULT}"
  bashunit::console_results::print_failing_tests_and_reset
  bashunit::console_results::print_incomplete_tests_and_reset
  bashunit::console_results::print_skipped_tests_and_reset
  bashunit::console_results::render_result
  bashunit::cleanup_script_temp_files
  if bashunit::parallel::is_enabled; then
    bashunit::parallel::cleanup
  fi
  exit 1
}

function bashunit::main::exec_assert() {
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
      output=$(bashunit::main::handle_assert_exit_code "$last_arg")
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

  if [[ "$(bashunit::state::get_tests_failed)" -gt 0 ]] || [[ "$(bashunit::state::get_assertions_failed)" -gt 0 ]]; then
    return 1
  fi

  return "$bashunit_exit_code"
}

function bashunit::main::handle_assert_exit_code() {
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
