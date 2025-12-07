#!/usr/bin/env bash
# shellcheck disable=SC2155

# Pre-compiled regex pattern for parsing test result assertions
if [[ -z ${_BASHUNIT_RUNNER_PARSE_RESULT_REGEX+x} ]]; then
  declare -r _BASHUNIT_RUNNER_PARSE_RESULT_REGEX='ASSERTIONS_FAILED=([0-9]*)##ASSERTIONS_PASSED=([0-9]*)##'\
'ASSERTIONS_SKIPPED=([0-9]*)##ASSERTIONS_INCOMPLETE=([0-9]*)##ASSERTIONS_SNAPSHOT=([0-9]*)##'\
'TEST_EXIT_CODE=([0-9]*)'
fi

function bashunit::runner::restore_workdir() {
  cd "$BASHUNIT_WORKING_DIR" 2>/dev/null || true
}

function bashunit::runner::load_test_files() {
  local filter=$1
  shift
  local files=("${@}")
  local scripts_ids=()

  for test_file in "${files[@]}"; do
    if [[ ! -f $test_file ]]; then
      continue
    fi
    unset BASHUNIT_CURRENT_TEST_ID
    export BASHUNIT_CURRENT_SCRIPT_ID="$(bashunit::helper::generate_id "${test_file}")"
    scripts_ids+=("${BASHUNIT_CURRENT_SCRIPT_ID}")
    bashunit::internal_log "Loading file" "$test_file"
    # shellcheck source=/dev/null
    source "$test_file"
    # Update function cache after sourcing new test file
    _BASHUNIT_CACHED_ALL_FUNCTIONS=$(declare -F | awk '{print $3}')
    # Call hook directly (not with `if !`) to preserve errexit behavior inside the hook
    bashunit::runner::run_set_up_before_script "$test_file"
    local setup_before_script_status=$?
    if [[ $setup_before_script_status -ne 0 ]]; then
      # Count the test functions that couldn't run due to set_up_before_script failure
      # and add them as failed (minus 1 since the hook failure already counts as 1)
      local filtered_functions
      filtered_functions=$(bashunit::helper::get_functions_to_run "test" "$filter" "$_BASHUNIT_CACHED_ALL_FUNCTIONS")
      if [[ -n "$filtered_functions" ]]; then
        # shellcheck disable=SC2206
        local functions_to_run=($filtered_functions)
        local additional_failures=$((${#functions_to_run[@]} - 1))
        for ((i = 0; i < additional_failures; i++)); do
          bashunit::state::add_tests_failed
        done
      fi
      bashunit::runner::clean_set_up_and_tear_down_after_script
      if ! bashunit::parallel::is_enabled; then
        bashunit::cleanup_script_temp_files
      fi
      bashunit::runner::restore_workdir
      continue
    fi
    if bashunit::parallel::is_enabled; then
      bashunit::runner::call_test_functions "$test_file" "$filter" 2>/dev/null &
    else
      bashunit::runner::call_test_functions "$test_file" "$filter"
    fi
    bashunit::runner::run_tear_down_after_script "$test_file"
    bashunit::runner::clean_set_up_and_tear_down_after_script
    if ! bashunit::parallel::is_enabled; then
      bashunit::cleanup_script_temp_files
    fi
    bashunit::internal_log "Finished file" "$test_file"
    bashunit::runner::restore_workdir
  done

  if bashunit::parallel::is_enabled; then
    wait
    bashunit::runner::spinner &
    local spinner_pid=$!
    bashunit::parallel::aggregate_test_results "$TEMP_DIR_PARALLEL_TEST_SUITE"
    # Kill the spinner once the aggregation finishes
    disown "$spinner_pid" && kill "$spinner_pid" &>/dev/null
    printf "\r  \r" # Clear the spinner output
    for script_id in "${scripts_ids[@]}"; do
      export BASHUNIT_CURRENT_SCRIPT_ID="${script_id}"
      bashunit::cleanup_script_temp_files
    done
  fi
}

function bashunit::runner::load_bench_files() {
  local filter=$1
  shift
  local files=("${@}")

  for bench_file in "${files[@]}"; do
    [[ -f $bench_file ]] || continue
    unset BASHUNIT_CURRENT_TEST_ID
    export BASHUNIT_CURRENT_SCRIPT_ID="$(bashunit::helper::generate_id "${bench_file}")"
    # shellcheck source=/dev/null
    source "$bench_file"
    # Update function cache after sourcing new bench file
    _BASHUNIT_CACHED_ALL_FUNCTIONS=$(declare -F | awk '{print $3}')
    # Call hook directly (not with `if !`) to preserve errexit behavior inside the hook
    bashunit::runner::run_set_up_before_script "$bench_file"
    local setup_before_script_status=$?
    if [[ $setup_before_script_status -ne 0 ]]; then
      # Count the bench functions that couldn't run due to set_up_before_script failure
      # and add them as failed (minus 1 since the hook failure already counts as 1)
      local filtered_functions
      filtered_functions=$(bashunit::helper::get_functions_to_run "bench" "$filter" "$_BASHUNIT_CACHED_ALL_FUNCTIONS")
      if [[ -n "$filtered_functions" ]]; then
        # shellcheck disable=SC2206
        local functions_to_run=($filtered_functions)
        local additional_failures=$((${#functions_to_run[@]} - 1))
        for ((i = 0; i < additional_failures; i++)); do
          bashunit::state::add_tests_failed
        done
      fi
      bashunit::runner::clean_set_up_and_tear_down_after_script
      bashunit::cleanup_script_temp_files
      bashunit::runner::restore_workdir
      continue
    fi
    bashunit::runner::call_bench_functions "$bench_file" "$filter"
    bashunit::runner::run_tear_down_after_script "$bench_file"
    bashunit::runner::clean_set_up_and_tear_down_after_script
    bashunit::cleanup_script_temp_files
    bashunit::runner::restore_workdir
  done
}

function bashunit::runner::spinner() {
  # Only show spinner when output is to a terminal
  if [[ ! -t 1 ]]; then
    # Not a terminal, just wait silently
    while true; do sleep 1; done
    return
  fi

  if bashunit::env::is_simple_output_enabled; then
    printf "\n"
  fi

  local delay=0.1
  local spin_chars="|/-\\"
  while true; do
    for ((i=0; i<${#spin_chars}; i++)); do
      printf "\r%s" "${spin_chars:$i:1}"
      sleep "$delay"
    done
  done
}

function bashunit::runner::functions_for_script() {
  local script="$1"
  local all_fn_names="$2"

  # Filter the names down to the ones defined in the script, sort them by line number
  shopt -s extdebug
  # shellcheck disable=SC2086
  declare -F $all_fn_names |
    awk -v s="$script" '$3 == s {print $1" " $2}' |
    sort -k2 -n |
    awk '{print $1}'
  shopt -u extdebug
}

function bashunit::runner::parse_data_provider_args() {
  local input="$1"
  local current_arg=""
  local in_quotes=false
  local quote_char=""
  local escaped=false
  local i
  local arg
  local encoded_arg
  local -a args=()

  # Check for shell metacharacters that would break eval or cause globbing
  local has_metachar=false
  if [[ "$input" =~ [^\\][\|\&\;\*] ]] || [[ "$input" =~ ^[\|\&\;\*] ]]; then
    has_metachar=true
  fi

  # Try eval first (needed for $'...' from printf '%q'), unless metacharacters present
  if [[ "$has_metachar" == false ]] && eval "args=($input)" 2>/dev/null && [[ ${#args[@]} -gt 0 ]]; then
    # Successfully parsed - remove sentinel if present
    local last_idx=$((${#args[@]} - 1))
    if [[ -z "${args[$last_idx]}" ]]; then
      unset 'args[$last_idx]'
    fi
    # Print args and return early
    for arg in "${args[@]}"; do
      encoded_arg="$(bashunit::helper::encode_base64 "${arg}")"
      printf '%s\n' "$encoded_arg"
    done
    return
  fi

  # Fallback: parse args from the input string into an array, respecting quotes and escapes
  for ((i=0; i<${#input}; i++)); do
    local char="${input:$i:1}"
    if [ "$escaped" = true ]; then
      case "$char" in
        t) current_arg+=$'\t' ;;
        n) current_arg+=$'\n' ;;
        *) current_arg+="$char" ;;
      esac
      escaped=false
    elif [ "$char" = "\\" ]; then
      escaped=true
    elif [ "$in_quotes" = false ]; then
      case "$char" in
        "$")
          # Handle $'...' syntax
          if [[ "${input:$i:2}" == "$'" ]]; then
            in_quotes=true
            quote_char="'"
            # Skip the $
            i=$((i + 1))
          else
            current_arg+="$char"
          fi
          ;;
        "'" | '"')
          in_quotes=true
          quote_char="$char"
          ;;
        " " | $'\t')
          # Only add non-empty arguments to avoid duplicates from consecutive separators
          if [[ -n "$current_arg" ]]; then
            args+=("$current_arg")
          fi
          current_arg=""
          ;;
        *)
          current_arg+="$char"
          ;;
      esac
    elif [ "$char" = "$quote_char" ]; then
      in_quotes=false
      quote_char=""
    else
      current_arg+="$char"
    fi
  done
  args+=("$current_arg")
  # Remove all trailing empty strings
  while [[ ${#args[@]} -gt 0 ]]; do
    local last_idx=$((${#args[@]} - 1))
    if [[ -z "${args[$last_idx]}" ]]; then
      unset 'args[$last_idx]'
    else
      break
    fi
  done
  # Print one arg per line to stdout, base64-encoded to preserve newlines in the data
  for arg in "${args[@]+"${args[@]}"}"; do
    encoded_arg="$(bashunit::helper::encode_base64 "${arg}")"
    printf '%s\n' "$encoded_arg"
  done
}

function bashunit::runner::call_test_functions() {
  local script="$1"
  local filter="$2"
  local prefix="test"
  # Use cached function names for better performance
  local filtered_functions
  filtered_functions=$(bashunit::helper::get_functions_to_run \
    "$prefix" "$filter" "$_BASHUNIT_CACHED_ALL_FUNCTIONS")
  # shellcheck disable=SC2207
  local functions_to_run=($(bashunit::runner::functions_for_script "$script" "$filtered_functions"))

  if [[ "${#functions_to_run[@]}" -le 0 ]]; then
    return
  fi

  bashunit::runner::render_running_file_header "$script"
  bashunit::helper::check_duplicate_functions "$script" || true

  for fn_name in "${functions_to_run[@]}"; do
    if bashunit::parallel::is_enabled && bashunit::parallel::must_stop_on_failure; then
      break
    fi

    local provider_data=()
    while IFS=" " read -r line; do
      provider_data+=("$line")
    done <<< "$(bashunit::helper::get_provider_data "$fn_name" "$script")"

    # No data provider found
    if [[ "${#provider_data[@]}" -eq 0 ]]; then
      bashunit::runner::run_test "$script" "$fn_name"
      unset fn_name
      continue
    fi

    # Execute the test function for each line of data
    for data in "${provider_data[@]}"; do
      local parsed_data=()
      while IFS= read -r line; do
        parsed_data+=( "$(bashunit::helper::decode_base64 "${line}")" )
      done <<< "$(bashunit::runner::parse_data_provider_args "$data")"
      bashunit::runner::run_test "$script" "$fn_name" "${parsed_data[@]}"
    done
    unset fn_name
  done

  if ! bashunit::env::is_simple_output_enabled; then
    echo ""
  fi
}

function bashunit::runner::call_bench_functions() {
  local script="$1"
  local filter="$2"
  local prefix="bench"

  # Use cached function names for better performance
  local filtered_functions
  filtered_functions=$(bashunit::helper::get_functions_to_run \
    "$prefix" "$filter" "$_BASHUNIT_CACHED_ALL_FUNCTIONS")
  # shellcheck disable=SC2207
  local functions_to_run=($(bashunit::runner::functions_for_script "$script" "$filtered_functions"))

  if [[ "${#functions_to_run[@]}" -le 0 ]]; then
    return
  fi

  if bashunit::env::is_bench_mode_enabled; then
    bashunit::runner::render_running_file_header "$script"
  fi

  for fn_name in "${functions_to_run[@]}"; do
    read -r revs its max_ms <<< "$(bashunit::benchmark::parse_annotations "$fn_name" "$script")"
    bashunit::benchmark::run_function "$fn_name" "$revs" "$its" "$max_ms"
    unset fn_name
  done

  if ! bashunit::env::is_simple_output_enabled; then
    echo ""
  fi
}

function bashunit::runner::render_running_file_header() {
  local script="$1"
  local force="${2:-false}"

  bashunit::internal_log "Running file" "$script"

  if [[ "$force" != true ]] && bashunit::parallel::is_enabled; then
    return
  fi

  if ! bashunit::env::is_simple_output_enabled; then
    if bashunit::env::is_verbose_enabled; then
      printf "\n${_BASHUNIT_COLOR_BOLD}%s${_BASHUNIT_COLOR_DEFAULT}\n" "Running $script"
    else
      printf "${_BASHUNIT_COLOR_BOLD}%s${_BASHUNIT_COLOR_DEFAULT}\n" "Running $script"
    fi
  elif bashunit::env::is_verbose_enabled; then
    printf "\n\n${_BASHUNIT_COLOR_BOLD}%s${_BASHUNIT_COLOR_DEFAULT}" "Running $script"
  fi
}

function bashunit::runner::run_test() {
  local start_time
  start_time=$(bashunit::clock::now)

  local test_file="$1"
  shift
  local fn_name="$1"
  shift

  bashunit::internal_log "Running test" "$fn_name" "$*"
  # Export a unique test identifier so that test doubles can
  # create temporary files scoped per test run. This prevents
  # race conditions when running tests in parallel.
  export BASHUNIT_CURRENT_TEST_ID="$(bashunit::helper::generate_id "$fn_name")"

  bashunit::state::reset_test_title

  local interpolated_fn_name="$(bashunit::helper::interpolate_function_name "$fn_name" "$@")"
  if [[ "$interpolated_fn_name" != "$fn_name" ]]; then
    bashunit::state::set_current_test_interpolated_function_name "$interpolated_fn_name"
  else
    bashunit::state::reset_current_test_interpolated_function_name
  fi
  local current_assertions_failed="$(bashunit::state::get_assertions_failed)"
  local current_assertions_snapshot="$(bashunit::state::get_assertions_snapshot)"
  local current_assertions_incomplete="$(bashunit::state::get_assertions_incomplete)"
  local current_assertions_skipped="$(bashunit::state::get_assertions_skipped)"

  # (FD = File Descriptor)
  # Duplicate the current std-output (FD 1) and assigns it to FD 3.
  # This means that FD 3 now points to wherever the std-output was pointing.
  exec 3>&1

  local test_execution_result=$(
    # shellcheck disable=SC2064
    trap 'exit_code=$?; bashunit::runner::cleanup_on_exit "$test_file" "$exit_code"' EXIT
    bashunit::state::initialize_assertions_count

    # Run set_up and capture exit code without || to preserve errexit behavior
    local setup_exit_code=0
    bashunit::runner::run_set_up "$test_file"
    setup_exit_code=$?
    if [[ $setup_exit_code -ne 0 ]]; then
      exit $setup_exit_code
    fi

    # Apply strict mode setting for test execution
    if bashunit::env::is_strict_mode_enabled; then
      set -euo pipefail
    fi

    # 2>&1: Redirects the std-error (FD 2) to the std-output (FD 1).
    # points to the original std-output.
    "$fn_name" "$@" 2>&1

  )

  # Closes FD 3, which was used temporarily to hold the original stdout.
  exec 3>&-

  local end_time=$(bashunit::clock::now)
  local duration_ns=$((end_time - start_time))
  local duration=$((duration_ns / 1000000))

  if bashunit::env::is_verbose_enabled; then
    if bashunit::env::is_simple_output_enabled; then
      echo ""
    fi

    printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '='
    printf "%s\n" "File:     $test_file"
    printf "%s\n" "Function: $fn_name"
    printf "%s\n" "Duration: $duration ms"
    local raw_text=${test_execution_result%%##ASSERTIONS_*}
    [[ -n $raw_text ]] && printf "%s" "Raw text: ${test_execution_result%%##ASSERTIONS_*}"
    printf "%s\n" "##ASSERTIONS_${test_execution_result#*##ASSERTIONS_}"
    printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '-'
  fi

  local subshell_output=$(bashunit::runner::decode_subshell_output "$test_execution_result")

  if [[ -n "$subshell_output" ]]; then
    # Formatted as "[type]line" @see `bashunit::state::print_line()`
    local type="${subshell_output%%]*}" # Remove everything after "]"
    type="${type#[}"                    # Remove the leading "["
    local line="${subshell_output#*]}"  # Remove everything before and including "]"

    # Replace [type] with a newline to split the messages
    line="${line//\[failed\]/$'\n'}"       # Replace [failed] with newline
    line="${line//\[skipped\]/$'\n'}"      # Replace [skipped] with newline
    line="${line//\[incomplete\]/$'\n'}"   # Replace [incomplete] with newline

    bashunit::state::print_line "$type" "$line"

    subshell_output=$line
  fi

  local runtime_output="${test_execution_result%%##ASSERTIONS_*}"

  local runtime_error=""
  for error in "command not found" "unbound variable" "permission denied" \
      "no such file or directory" "syntax error" "bad substitution" \
      "division by 0" "cannot allocate memory" "bad file descriptor" \
      "segmentation fault" "illegal option" "argument list too long" \
      "readonly variable" "missing keyword" "killed" \
      "cannot execute binary file" "invalid arithmetic operator"; do
    if [[ "$runtime_output" == *"$error"* ]]; then
      runtime_error="${runtime_output#*: }"      # Remove everything up to and including ": "
      runtime_error="${runtime_error//$'\n'/}"   # Remove all newlines using parameter expansion
      break
    fi
  done

  bashunit::runner::parse_result "$fn_name" "$test_execution_result" "$@"

  local total_assertions="$(bashunit::state::calculate_total_assertions "$test_execution_result")"
  local test_exit_code="$(bashunit::state::get_test_exit_code)"

  local encoded_test_title
  encoded_test_title="${test_execution_result##*##TEST_TITLE=}"
  encoded_test_title="${encoded_test_title%%##*}"
  local test_title=""
  [[ -n "$encoded_test_title" ]] && test_title="$(bashunit::helper::decode_base64 "$encoded_test_title")"

  local encoded_hook_failure
  encoded_hook_failure="${test_execution_result##*##TEST_HOOK_FAILURE=}"
  encoded_hook_failure="${encoded_hook_failure%%##*}"
  local hook_failure=""
  if [[ "$encoded_hook_failure" != "$test_execution_result" ]]; then
    hook_failure="$encoded_hook_failure"
  fi

  local encoded_hook_message
  encoded_hook_message="${test_execution_result##*##TEST_HOOK_MESSAGE=}"
  encoded_hook_message="${encoded_hook_message%%##*}"
  local hook_message=""
  if [[ -n "$encoded_hook_message" ]]; then
    hook_message="$(bashunit::helper::decode_base64 "$encoded_hook_message")"
  fi

  bashunit::set_test_title "$test_title"
  local label
  label="$(bashunit::helper::normalize_test_function_name "$fn_name" "$interpolated_fn_name")"
  bashunit::state::reset_test_title
  bashunit::state::reset_current_test_interpolated_function_name

  local failure_label="$label"
  local failure_function="$fn_name"
  if [[ -n "$hook_failure" ]]; then
    failure_label="$(bashunit::helper::normalize_test_function_name "$hook_failure")"
    failure_function="$hook_failure"
  fi

  if [[ -n $runtime_error || $test_exit_code -ne 0 ]]; then
    bashunit::state::add_tests_failed
    local error_message="$runtime_error"
    if [[ -n "$hook_failure" && -n "$hook_message" ]]; then
      error_message="$hook_message"
    elif [[ -z "$error_message" && -n "$hook_message" ]]; then
      error_message="$hook_message"
    fi
    bashunit::console_results::print_error_test "$failure_function" "$error_message"
    bashunit::reports::add_test_failed "$test_file" "$failure_label" "$duration" "$total_assertions"
    bashunit::runner::write_failure_result_output "$test_file" "$failure_function" "$error_message"
    bashunit::internal_log "Test error" "$failure_label" "$error_message"
    return
  fi

  if [[ "$current_assertions_failed" != "$(bashunit::state::get_assertions_failed)" ]]; then
    bashunit::state::add_tests_failed
    bashunit::reports::add_test_failed "$test_file" "$label" "$duration" "$total_assertions"
    bashunit::runner::write_failure_result_output "$test_file" "$fn_name" "$subshell_output"

    bashunit::internal_log "Test failed" "$label"

    if bashunit::env::is_stop_on_failure_enabled; then
      if bashunit::parallel::is_enabled; then
        bashunit::parallel::mark_stop_on_failure
      else
        exit "$EXIT_CODE_STOP_ON_FAILURE"
      fi
    fi
    return
  fi

  if [[ "$current_assertions_snapshot" != "$(bashunit::state::get_assertions_snapshot)" ]]; then
    bashunit::state::add_tests_snapshot
    bashunit::console_results::print_snapshot_test "$label"
    bashunit::reports::add_test_snapshot "$test_file" "$label" "$duration" "$total_assertions"
    bashunit::internal_log "Test snapshot" "$label"
    return
  fi

  if [[ "$current_assertions_incomplete" != "$(bashunit::state::get_assertions_incomplete)" ]]; then
    bashunit::state::add_tests_incomplete
    bashunit::reports::add_test_incomplete "$test_file" "$label" "$duration" "$total_assertions"
    bashunit::runner::write_incomplete_result_output "$test_file" "$fn_name" "$subshell_output"
    bashunit::internal_log "Test incomplete" "$label"
    return
  fi

  if [[ "$current_assertions_skipped" != "$(bashunit::state::get_assertions_skipped)" ]]; then
    bashunit::state::add_tests_skipped
    bashunit::reports::add_test_skipped "$test_file" "$label" "$duration" "$total_assertions"
    bashunit::runner::write_skipped_result_output "$test_file" "$fn_name" "$subshell_output"
    bashunit::internal_log "Test skipped" "$label"
    return
  fi

  if [[ "$fn_name" == "$interpolated_fn_name" ]]; then
    bashunit::console_results::print_successful_test "${label}" "$duration" "$@"
  else
    bashunit::console_results::print_successful_test "${label}" "$duration"
  fi
  bashunit::state::add_tests_passed
  bashunit::reports::add_test_passed "$test_file" "$label" "$duration" "$total_assertions"
  bashunit::internal_log "Test passed" "$label"
}

function bashunit::runner::cleanup_on_exit() {
  local test_file="$1"
  local exit_code="$2"

  set +e
  # Don't use || here - it disables ERR trap in the entire call chain
  bashunit::runner::run_tear_down "$test_file"
  local teardown_status=$?
  bashunit::runner::clear_mocks
  bashunit::cleanup_testcase_temp_files

  if [[ $teardown_status -ne 0 ]]; then
    bashunit::state::set_test_exit_code "$teardown_status"
  else
    bashunit::state::set_test_exit_code "$exit_code"
  fi

  bashunit::state::export_subshell_context
}

function bashunit::runner::decode_subshell_output() {
  local test_execution_result="$1"

  local test_output_base64="${test_execution_result##*##TEST_OUTPUT=}"
  test_output_base64="${test_output_base64%%##*}"
  bashunit::helper::decode_base64 "$test_output_base64"
}

function bashunit::runner::parse_result() {
  local fn_name=$1
  shift
  local execution_result=$1
  shift
  local args=("$@")

  if bashunit::parallel::is_enabled; then
    bashunit::runner::parse_result_parallel "$fn_name" "$execution_result" "${args[@]}"
  else
    bashunit::runner::parse_result_sync "$fn_name" "$execution_result"
  fi
}

function bashunit::runner::parse_result_parallel() {
  local fn_name=$1
  shift
  local execution_result=$1
  shift
  local args=("$@")

  local test_suite_dir="${TEMP_DIR_PARALLEL_TEST_SUITE}/$(basename "$test_file" .sh)"
  mkdir -p "$test_suite_dir"

  local sanitized_args
  sanitized_args=$(echo "${args[*]}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//')
  local template
  if [[ -z "$sanitized_args" ]]; then
    template="${fn_name}.XXXXXX"
  else
    template="${fn_name}-${sanitized_args}.XXXXXX"
  fi

  local unique_test_result_file
  if unique_test_result_file=$(mktemp -p "$test_suite_dir" "$template" 2>/dev/null); then
    true
  else
    unique_test_result_file=$(mktemp "$test_suite_dir/$template")
  fi
  mv "$unique_test_result_file" "${unique_test_result_file}.result"
  unique_test_result_file="${unique_test_result_file}.result"

  bashunit::internal_log "[PARA]" "fn_name:$fn_name" "execution_result:$execution_result"

  bashunit::runner::parse_result_sync "$fn_name" "$execution_result"

  echo "$execution_result" > "$unique_test_result_file"
}

# shellcheck disable=SC2295
function bashunit::runner::parse_result_sync() {
  local fn_name=$1
  local execution_result=$2

  local result_line
  result_line="${execution_result##*$'\n'}"

  local assertions_failed=0
  local assertions_passed=0
  local assertions_skipped=0
  local assertions_incomplete=0
  local assertions_snapshot=0
  local test_exit_code=0

  # Use pre-compiled regex constant
  if [[ $result_line =~ $_BASHUNIT_RUNNER_PARSE_RESULT_REGEX ]]; then
    assertions_failed="${BASH_REMATCH[1]}"
    assertions_passed="${BASH_REMATCH[2]}"
    assertions_skipped="${BASH_REMATCH[3]}"
    assertions_incomplete="${BASH_REMATCH[4]}"
    assertions_snapshot="${BASH_REMATCH[5]}"
    test_exit_code="${BASH_REMATCH[6]}"
  fi

  bashunit::internal_log "[SYNC]" "fn_name:$fn_name" "execution_result:$execution_result"

  ((_BASHUNIT_ASSERTIONS_PASSED += assertions_passed)) || true
  ((_BASHUNIT_ASSERTIONS_FAILED += assertions_failed)) || true
  ((_BASHUNIT_ASSERTIONS_SKIPPED += assertions_skipped)) || true
  ((_BASHUNIT_ASSERTIONS_INCOMPLETE += assertions_incomplete)) || true
  ((_BASHUNIT_ASSERTIONS_SNAPSHOT += assertions_snapshot)) || true
  ((_BASHUNIT_TEST_EXIT_CODE += test_exit_code)) || true

  bashunit::internal_log "result_summary" \
    "failed:$assertions_failed" \
    "passed:$assertions_passed" \
    "skipped:$assertions_skipped" \
    "incomplete:$assertions_incomplete" \
    "snapshot:$assertions_snapshot" \
    "exit_code:$test_exit_code"
}

function bashunit::runner::write_failure_result_output() {
  local test_file=$1
  local fn_name=$2
  local error_msg=$3

  local line_number
  line_number=$(bashunit::helper::get_function_line_number "$fn_name")

  local test_nr="*"
  if ! bashunit::parallel::is_enabled; then
    test_nr=$(bashunit::state::get_tests_failed)
  fi

  echo -e "$test_nr) $test_file:$line_number\n$error_msg" >> "$FAILURES_OUTPUT_PATH"
}

function bashunit::runner::write_skipped_result_output() {
  local test_file=$1
  local fn_name=$2
  local output_msg=$3

  local line_number
  line_number=$(bashunit::helper::get_function_line_number "$fn_name")

  local test_nr="*"
  if ! bashunit::parallel::is_enabled; then
    test_nr=$(bashunit::state::get_tests_skipped)
  fi

  echo -e "$test_nr) $test_file:$line_number\n$output_msg" >> "$SKIPPED_OUTPUT_PATH"
}

function bashunit::runner::write_incomplete_result_output() {
  local test_file=$1
  local fn_name=$2
  local output_msg=$3

  local line_number
  line_number=$(bashunit::helper::get_function_line_number "$fn_name")

  local test_nr="*"
  if ! bashunit::parallel::is_enabled; then
    test_nr=$(bashunit::state::get_tests_incomplete)
  fi

  echo -e "$test_nr) $test_file:$line_number\n$output_msg" >> "$INCOMPLETE_OUTPUT_PATH"
}

function bashunit::runner::record_file_hook_failure() {
  local hook_name="$1"
  local test_file="$2"
  local hook_output="$3"
  local status="$4"
  local render_header="${5:-false}"

  if [[ "$render_header" == true ]]; then
    bashunit::runner::render_running_file_header "$test_file" true
  fi

  if [[ -z "$hook_output" ]]; then
    hook_output="Hook '$hook_name' failed with exit code $status"
  fi

  bashunit::state::add_tests_failed
  bashunit::console_results::print_error_test "$hook_name" "$hook_output"
  bashunit::reports::add_test_failed "$test_file" "$(bashunit::helper::normalize_test_function_name "$hook_name")" 0 0
  bashunit::runner::write_failure_result_output "$test_file" "$hook_name" "$hook_output"

  return "$status"
}

function bashunit::runner::execute_file_hook() {
  local hook_name="$1"
  local test_file="$2"
  local render_header="${3:-false}"

  declare -F "$hook_name" >/dev/null 2>&1 || return 0

  local hook_output=""
  local status=0
  local hook_output_file
  hook_output_file=$(bashunit::temp_file "${hook_name}_output")

  # Enable errexit and errtrace to catch any failing command in the hook.
  # The ERR trap saves the exit status to a global variable (since return value
  # from trap doesn't propagate properly), disables errexit (to prevent caller
  # from exiting) and returns from the hook function, preventing subsequent
  # commands from executing.
  # Variables set before the failure are preserved since we don't use a subshell.
  _BASHUNIT_HOOK_ERR_STATUS=0
  set -eE
  trap '_BASHUNIT_HOOK_ERR_STATUS=$?; set +eE; trap - ERR; return $_BASHUNIT_HOOK_ERR_STATUS' ERR

  {
    "$hook_name"
  } >"$hook_output_file" 2>&1

  # Capture exit status from global variable and clean up
  status=$_BASHUNIT_HOOK_ERR_STATUS
  trap - ERR
  set +eE

  if [[ -f "$hook_output_file" ]]; then
    hook_output=""
    while IFS= read -r line; do
      [[ -z "$hook_output" ]] && hook_output="$line" || hook_output="$hook_output"$'\n'"$line"
    done < "$hook_output_file"
    rm -f "$hook_output_file"
  fi

  if [[ $status -ne 0 ]]; then
    bashunit::runner::record_file_hook_failure "$hook_name" "$test_file" "$hook_output" "$status" "$render_header"
    return $status
  fi

  if [[ -n "$hook_output" ]]; then
    printf "%s\n" "$hook_output"
  fi

  return 0
}

function bashunit::runner::run_set_up() {
  local _test_file="${1-}"
  bashunit::internal_log "run_set_up"
  bashunit::runner::execute_test_hook 'set_up'
}

function bashunit::runner::run_set_up_before_script() {
  local test_file="$1"
  bashunit::internal_log "run_set_up_before_script"
  bashunit::runner::execute_file_hook 'set_up_before_script' "$test_file" true
}

function bashunit::runner::run_tear_down() {
  local _test_file="${1-}"
  bashunit::internal_log "run_tear_down"
  bashunit::runner::execute_test_hook 'tear_down'
}

function bashunit::runner::execute_test_hook() {
  local hook_name="$1"

  declare -F "$hook_name" >/dev/null 2>&1 || return 0

  local hook_output=""
  local status=0
  local hook_output_file
  hook_output_file=$(bashunit::temp_file "${hook_name}_output")

  # Enable errexit and errtrace to catch any failing command in the hook.
  # The ERR trap saves the exit status to a global variable (since return value
  # from trap doesn't propagate properly), disables errexit (to prevent caller
  # from exiting) and returns from the hook function, preventing subsequent
  # commands from executing.
  # Variables set before the failure are preserved since we don't use a subshell.
  _BASHUNIT_HOOK_ERR_STATUS=0
  set -eE
  trap '_BASHUNIT_HOOK_ERR_STATUS=$?; set +eE; trap - ERR; return $_BASHUNIT_HOOK_ERR_STATUS' ERR

  {
    "$hook_name"
  } >"$hook_output_file" 2>&1

  # Capture exit status from global variable and clean up
  status=$_BASHUNIT_HOOK_ERR_STATUS
  trap - ERR
  set +eE

  if [[ -f "$hook_output_file" ]]; then
    hook_output=""
    while IFS= read -r line; do
      [[ -z "$hook_output" ]] && hook_output="$line" || hook_output="$hook_output"$'\n'"$line"
    done < "$hook_output_file"
    rm -f "$hook_output_file"
  fi

  if [[ $status -ne 0 ]]; then
    local message="$hook_output"
    if [[ -n "$hook_output" ]]; then
      printf "%s" "$hook_output"
    else
      message="Hook '$hook_name' failed with exit code $status"
      printf "%s\n" "$message" >&2
    fi
    bashunit::runner::record_test_hook_failure "$hook_name" "$message" "$status"
    return "$status"
  fi

  if [[ -n "$hook_output" ]]; then
    printf "%s" "$hook_output"
  fi

  return 0
}

function bashunit::runner::record_test_hook_failure() {
  local hook_name="$1"
  local hook_message="$2"
  local status="$3"

  if [[ -n "$(bashunit::state::get_test_hook_failure)" ]]; then
    return "$status"
  fi

  bashunit::state::set_test_hook_failure "$hook_name"
  bashunit::state::set_test_hook_message "$hook_message"

  return "$status"
}

function bashunit::runner::clear_mocks() {
  for i in "${!_BASHUNIT_MOCKED_FUNCTIONS[@]}"; do
    bashunit::unmock "${_BASHUNIT_MOCKED_FUNCTIONS[$i]}"
  done
}

function bashunit::runner::run_tear_down_after_script() {
  local test_file="$1"
  bashunit::internal_log "run_tear_down_after_script"
  bashunit::runner::execute_file_hook 'tear_down_after_script' "$test_file"
}

function bashunit::runner::clean_set_up_and_tear_down_after_script() {
  bashunit::internal_log "clean_set_up_and_tear_down_after_script"
  bashunit::helper::unset_if_exists 'set_up'
  bashunit::helper::unset_if_exists 'tear_down'
  bashunit::helper::unset_if_exists 'set_up_before_script'
  bashunit::helper::unset_if_exists 'tear_down_after_script'
}
