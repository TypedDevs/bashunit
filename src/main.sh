#!/usr/bin/env bash

#############################
# Subcommand: test
#############################
function bashunit::main::cmd_test() {
  local filter=""
  local IFS=$' \t\n'
  local -a raw_args=()
  local raw_args_count=0
  local -a args=()
  local args_count=0
  local assert_fn=""
  local _bashunit_coverage_opt_set=false

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
        # Support: --env "bootstrap.sh arg1 arg2"
        local boot_file="${2%% *}"
        local boot_args="${2#* }"
        if [[ "$boot_args" != "$2" ]]; then
          export BASHUNIT_BOOTSTRAP_ARGS="$boot_args"
        fi
        # Export all variables from the env file so they're available in subshells
        # (e.g., process substitution used in load_test_files)
        set -o allexport
        # shellcheck disable=SC1090,SC2086
        source "$boot_file" ${BASHUNIT_BOOTSTRAP_ARGS:-}
        set +o allexport
        shift
        ;;
      --log-junit)
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
      --failures-only)
        export BASHUNIT_FAILURES_ONLY=true
        ;;
      --show-output)
        export BASHUNIT_SHOW_OUTPUT_ON_FAILURE=true
        ;;
      --no-output-on-failure)
        export BASHUNIT_SHOW_OUTPUT_ON_FAILURE=false
        ;;
      --no-progress)
        export BASHUNIT_NO_PROGRESS=true
        ;;
      --strict)
        export BASHUNIT_STRICT_MODE=true
        ;;
      -R|--run-all)
        export BASHUNIT_STOP_ON_ASSERTION_FAILURE=false
        ;;
      --skip-env-file)
        export BASHUNIT_SKIP_ENV_FILE=true
        ;;
      -l|--login)
        export BASHUNIT_LOGIN_SHELL=true
        ;;
      --no-color)
        # shellcheck disable=SC2034
        BASHUNIT_NO_COLOR=true
        ;;
      --coverage)
        # Don't export - prevents nested bashunit runs from inheriting coverage
        # shellcheck disable=SC2034
        BASHUNIT_COVERAGE=true
        ;;
      --coverage-paths)
        # shellcheck disable=SC2034
        BASHUNIT_COVERAGE_PATHS="$2"
        shift
        ;;
      --coverage-exclude)
        # shellcheck disable=SC2034
        BASHUNIT_COVERAGE_EXCLUDE="$2"
        shift
        ;;
      --coverage-report)
        # shellcheck disable=SC2034
        BASHUNIT_COVERAGE_REPORT="$2"
        _bashunit_coverage_opt_set=true
        shift
        ;;
      --coverage-min)
        # shellcheck disable=SC2034
        BASHUNIT_COVERAGE_MIN="$2"
        _bashunit_coverage_opt_set=true
        shift
        ;;
      --no-coverage-report)
        # shellcheck disable=SC2034
        BASHUNIT_COVERAGE_REPORT=""
        ;;
      --coverage-report-html)
        # shellcheck disable=SC2034
        # Use default if no value provided or next arg is a flag
        if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
          BASHUNIT_COVERAGE_REPORT_HTML="coverage/html"
        else
          BASHUNIT_COVERAGE_REPORT_HTML="$2"
          shift
        fi
        _bashunit_coverage_opt_set=true
        ;;
      *)
        raw_args[raw_args_count]="$1"; raw_args_count=$((raw_args_count + 1))
        ;;
    esac
    shift
  done

  # Auto-enable coverage when any coverage output option is specified
  if [[ "$_bashunit_coverage_opt_set" == true ]]; then
    # shellcheck disable=SC2034
    BASHUNIT_COVERAGE=true
  fi

  # Expand positional arguments and extract inline filters
  # Skip filter parsing for assert mode - args are not file paths
  local inline_filter=""
  local inline_filter_file=""
  if [[ "$raw_args_count" -gt 0 ]]; then
    if [[ -n "$assert_fn" ]]; then
      # Assert mode: pass args as-is without file path processing
      args=("${raw_args[@]}")
      args_count="$raw_args_count"
    else
      # Test mode: process file paths and extract inline filters
      local arg=""
      for arg in "${raw_args[@]+"${raw_args[@]}"}"; do
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

        local file=""
        while IFS= read -r file; do
          args[args_count]="$file"; args_count=$((args_count + 1))
        done < <(bashunit::helper::find_files_recursive "$parsed_path" '*[tT]est.sh')
      done

      # Resolve line number filter to function name
      if [[ "$inline_filter" == "__line__:"* ]]; then
        local line_number="${inline_filter#__line__:}"
        local resolved_file="${inline_filter_file}"

        # If the file path was a pattern, use the first resolved file
        if [[ "$args_count" -gt 0 ]]; then
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
  # shellcheck disable=SC1090,SC2086
  [[ -f "${BASHUNIT_BOOTSTRAP:-}" ]] && source "$BASHUNIT_BOOTSTRAP" ${BASHUNIT_BOOTSTRAP_ARGS:-}

  if [[ "${BASHUNIT_NO_OUTPUT:-false}" == true ]]; then
    exec >/dev/null 2>&1
  fi

  # Disable strict mode for test execution to allow:
  # - Empty array expansion (set +u)
  # - Non-zero exit codes from failing tests (set +e)
  # - Pipe failures in test output (set +o pipefail)
  set +euo pipefail
  if [[ -n "$assert_fn" ]]; then
    # Disable coverage for assert mode - it's meant for running single assertions,
    # not tracking code coverage. This also prevents issues when parent bashunit
    # runs with coverage and calls subprocess bashunit with -a flag.
    export BASHUNIT_COVERAGE=false
    bashunit::main::exec_assert "$assert_fn" ${args+"${args[@]}"}
  else
    # Bash 3.0 compatible: only pass args if we have files
    # (local args without =() creates a scalar, not an empty array)
    if [[ "$args_count" -gt 0 ]]; then
      bashunit::main::exec_tests "$filter" "${args[@]}"
    else
      bashunit::main::exec_tests "$filter"
    fi
  fi
}

#############################
# Subcommand: bench
#############################
function bashunit::main::cmd_bench() {
  local filter=""
  local IFS=$' \t\n'
  local -a raw_args=()
  local raw_args_count=0
  local -a args=()
  local args_count=0

  export BASHUNIT_BENCH_MODE=true

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
        # Support: --env "bootstrap.sh arg1 arg2"
        local boot_file="${2%% *}"
        local boot_args="${2#* }"
        if [[ "$boot_args" != "$2" ]]; then
          export BASHUNIT_BOOTSTRAP_ARGS="$boot_args"
        fi
        # Export all variables from the env file so they're available in subshells
        # (e.g., process substitution used in load_test_files)
        set -o allexport
        # shellcheck disable=SC1090,SC2086
        source "$boot_file" ${BASHUNIT_BOOTSTRAP_ARGS:-}
        set +o allexport
        shift
        ;;
      -vvv|--verbose)
        export BASHUNIT_VERBOSE=true
        ;;
      --skip-env-file)
        export BASHUNIT_SKIP_ENV_FILE=true
        ;;
      -l|--login)
        export BASHUNIT_LOGIN_SHELL=true
        ;;
      --no-color)
        # shellcheck disable=SC2034
        BASHUNIT_NO_COLOR=true
        ;;
      -h|--help)
        bashunit::console_header::print_bench_help
        exit 0
        ;;
      *)
        raw_args[raw_args_count]="$1"; raw_args_count=$((raw_args_count + 1))
        ;;
    esac
    shift
  done

  # Expand positional arguments
  if [[ "$raw_args_count" -gt 0 ]]; then
    local arg file
    for arg in "${raw_args[@]+"${raw_args[@]}"}"; do
      while IFS= read -r file; do
        args[args_count]="$file"; args_count=$((args_count + 1))
      done < <(bashunit::helper::find_files_recursive "$arg" '*[bB]ench.sh')
    done
  fi

  # Optional bootstrap
  # shellcheck disable=SC1090,SC2086
  [[ -f "${BASHUNIT_BOOTSTRAP:-}" ]] && source "$BASHUNIT_BOOTSTRAP" ${BASHUNIT_BOOTSTRAP_ARGS:-}

  set +euo pipefail

  # Bash 3.0 compatible: only pass args if we have files
  if [[ "$args_count" -gt 0 ]]; then
    bashunit::main::exec_benchmarks "$filter" "${args[@]}"
  else
    bashunit::main::exec_benchmarks "$filter"
  fi
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
# Subcommand: assert
#############################

# Check if a name corresponds to an assertion function (not a file or command)
function bashunit::main::is_assertion_function() {
  local name="$1"
  declare -F "assert_$name" &>/dev/null || declare -F "$name" &>/dev/null
}

# Check if assertion operates on exit codes
function bashunit::main::is_exit_code_assertion() {
  local name="$1"
  case "$name" in
    exit_code|successful_code|unsuccessful_code|general_error|command_not_found)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

function bashunit::main::cmd_assert() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    bashunit::console_header::print_assert_help
    exit 0
  fi

  local first_arg="${1:-}"
  if [[ -z "$first_arg" ]]; then
    printf "%sError: Assert function name or command is required.%s\n" \
      "${_BASHUNIT_COLOR_FAILED}" "${_BASHUNIT_COLOR_DEFAULT}"
    bashunit::console_header::print_assert_help
    exit 1
  fi

  # Disable strict mode for assert execution
  set +euo pipefail

  # Route to appropriate handler based on first argument
  if bashunit::main::is_assertion_function "$first_arg"; then
    # Old single-assertion syntax: bashunit assert <fn> <args...>
    local assert_fn="$first_arg"
    shift
    bashunit::main::exec_assert "$assert_fn" "$@"
  elif [[ $# -ge 2 ]] && bashunit::main::is_assertion_function "$2"; then
    # New multi-assertion syntax: bashunit assert "<cmd>" <assertion1> <arg1> ...
    # Detected by: first arg is not assertion, but second arg is an assertion name
    bashunit::main::exec_multi_assert "$@"
  else
    # Fallback: try as single assertion (may fail with function not found)
    bashunit::main::exec_assert "$@"
  fi
  exit $?
}

#############################
# Test execution
#############################
function bashunit::main::exec_tests() {
  local filter=$1
  shift

  # Bash 3.0 compatible: collect files into array
  local test_files
  local test_files_count=0
  local _line
  while IFS= read -r _line; do
    [[ -z "$_line" ]] && continue
    test_files[test_files_count]="$_line"
    test_files_count=$((test_files_count + 1))
  done < <(bashunit::helper::load_test_files "$filter" "$@")

  bashunit::internal_log "exec_tests" "filter:$filter" "files:${test_files[*]:-}"

  if [[ "$test_files_count" -eq 0 ]]; then
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

  # Generate coverage report if enabled
  if bashunit::env::is_coverage_enabled; then
    # Aggregate per-process coverage data from parallel runs
    if bashunit::parallel::is_enabled; then
      bashunit::coverage::aggregate_parallel
    fi

    bashunit::coverage::report_text

    if [[ -n "$BASHUNIT_COVERAGE_REPORT" ]]; then
      bashunit::coverage::report_lcov "$BASHUNIT_COVERAGE_REPORT"
    fi

    if [[ -n "$BASHUNIT_COVERAGE_REPORT_HTML" ]]; then
      bashunit::coverage::report_html "$BASHUNIT_COVERAGE_REPORT_HTML"
    fi

    # Check minimum threshold
    if ! bashunit::coverage::check_threshold; then
      exit_code=1
    fi

    bashunit::coverage::cleanup
  fi

  if bashunit::parallel::is_enabled; then
    bashunit::parallel::cleanup
  fi

  bashunit::internal_log "Finished tests" "exit_code:$exit_code"
  exit $exit_code
}

function bashunit::main::exec_benchmarks() {
  local filter=$1
  shift

  # Bash 3.0 compatible: collect files into array
  local bench_files
  local bench_files_count=0
  local _line
  while IFS= read -r _line; do
    [[ -z "$_line" ]] && continue
    bench_files[bench_files_count]="$_line"
    bench_files_count=$((bench_files_count + 1))
  done < <(bashunit::helper::load_bench_files "$filter" "$@")

  bashunit::internal_log "exec_benchmarks" "filter:$filter" "files:${bench_files[*]:-}"

  if [[ "$bench_files_count" -eq 0 ]]; then
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
  local -a args=()
  local args_count=$(($# - 1))
  [[ $# -gt 1 ]] && args=("${@:2}")

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
  local last_index=$((args_count - 1))
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
      args[last_index]="$inner_exit_code"
      ;;
    *)
      # Add more cases here for other assert_* handlers if needed
      ;;
  esac

  if [[ -n "$output" ]]; then
    echo "$output" 1>&1
    assert_fn="assert_same"
  fi

  # Set a friendly test title for CLI assert command output
  bashunit::state::set_test_title "assert ${original_assert_fn#assert_}"

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

# Execute multiple assertions on a single command output
# Usage: exec_multi_assert "command" assertion1 arg1 [assertion2 arg2 ...]
function bashunit::main::exec_multi_assert() {
  local cmd="$1"
  shift

  # Require at least one assertion
  if [[ $# -lt 1 ]]; then
    printf "%sError: Multi-assertion mode requires at least one assertion.%s\n" \
      "${_BASHUNIT_COLOR_FAILED}" "${_BASHUNIT_COLOR_DEFAULT}" 1>&2
    printf "Usage: bashunit assert \"<command>\" <assertion1> <arg1> [<assertion2> <arg2>...]\n" 1>&2
    return 1
  fi

  # Check that assertions come in pairs (assertion + arg)
  if [[ $# -lt 2 ]] || [[ $(($# % 2)) -ne 0 ]]; then
    local assertion_name="${1:-}"
    printf "%sError: Missing argument for assertion '%s'.%s\n" \
      "${_BASHUNIT_COLOR_FAILED}" "$assertion_name" "${_BASHUNIT_COLOR_DEFAULT}" 1>&2
    return 1
  fi

  # Execute command and capture output + exit code
  local stdout
  local cmd_exit_code
  stdout=$(eval "$cmd" 2>&1)
  cmd_exit_code=$?

  # Print stdout for user visibility
  if [[ -n "$stdout" ]]; then
    echo "$stdout" 1>&1
  fi

  # Parse and execute assertions in pairs
  local overall_result=0
  while [[ $# -gt 0 ]]; do
    local assertion_name="$1"
    local assertion_arg="${2:-}"

    if [[ -z "$assertion_arg" ]]; then
      printf "%sError: Missing argument for assertion '%s'.%s\n" \
        "${_BASHUNIT_COLOR_FAILED}" "$assertion_name" "${_BASHUNIT_COLOR_DEFAULT}" 1>&2
      return 1
    fi

    shift 2

    # Resolve assertion function name
    local assert_fn="$assertion_name"
    if ! type "$assert_fn" &>/dev/null; then
      assert_fn="assert_$assertion_name"
      if ! type "$assert_fn" &>/dev/null; then
        printf "%sError: Unknown assertion '%s'.%s\n" \
          "${_BASHUNIT_COLOR_FAILED}" "$assertion_name" "${_BASHUNIT_COLOR_DEFAULT}" 1>&2
        return 1
      fi
    fi

    # Set test title for this assertion
    bashunit::state::set_test_title "assert ${assertion_name#assert_}"

    # Execute assertion with appropriate argument
    if bashunit::main::is_exit_code_assertion "$assertion_name"; then
      # Exit code assertion: pass expected value and captured exit code
      "$assert_fn" "$assertion_arg" "" "$cmd_exit_code" 1>&2
    else
      # Output assertion: pass expected value and captured stdout
      "$assert_fn" "$assertion_arg" "$stdout" 1>&2
    fi

    if [[ "$(bashunit::state::get_assertions_failed)" -gt 0 ]]; then
      overall_result=1
    fi
  done

  return $overall_result
}
