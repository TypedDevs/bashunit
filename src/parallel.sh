#!/bin/bash

# this function will be invoke with & to force running in a subprocess
function parallel::call_test_functions() {
  local script="$1"
  local filter="$2"
  local prefix="test"
  # Use declare -F to list all function names
  local all_function_names
  all_function_names=$(declare -F | awk '{print $3}')
  local filtered_functions
  # shellcheck disable=SC2207
  filtered_functions=$(helper::get_functions_to_run "$prefix" "$filter" "$all_function_names")

  local functions_to_run
  # shellcheck disable=SC2207
  functions_to_run=($(parallel::functions_for_script "$script" "$filtered_functions"))

  if [[ "${#functions_to_run[@]}" -gt 0 ]]; then
    helper::check_duplicate_functions "$script" || true

    for function_name in "${functions_to_run[@]}"; do
      local provider_data=()
      while IFS=" " read -r line; do
        provider_data+=("$line")
      done <<< "$(helper::get_provider_data "$function_name" "$script")"

      # No data provider found
      if [[ "${#provider_data[@]}" -eq 0 ]]; then
        parallel::run_test "$script" "$function_name"
        unset function_name
        continue
      fi

      # Execute the test function for each line of data
      for data in "${provider_data[@]}"; do
        IFS=" " read -r -a args <<< "$data"
        if [ "${#args[@]}" -gt 1 ]; then
          parallel::run_test "$script" "$function_name" "${args[@]}"
        else
          parallel::run_test "$script" "$function_name" "$data"
        fi
      done
      unset function_name
    done
  fi
}

function parallel::functions_for_script() {
  local script="$1"
  local all_function_names="$2"

  # Filter the names down to the ones defined in the script, sort them by line number
  shopt -s extdebug
  for f in $all_function_names; do
    declare -F "$f" | grep "$script"
  done | sort -k2 -n | awk '{print $1}'
  shopt -u extdebug
}

function parallel::run_test() {
  local start_time
  start_time=$(clock::now)

  local test_file="$1"
  shift
  local function_name="$1"
  shift
  local current_assertions_failed
  current_assertions_failed="$(state::get_assertions_failed)"
  local current_assertions_snapshot
  current_assertions_snapshot="$(state::get_assertions_snapshot)"
  local current_assertions_incomplete
  current_assertions_incomplete="$(state::get_assertions_incomplete)"
  local current_assertions_skipped
  current_assertions_skipped="$(state::get_assertions_skipped)"

  # (FD = File Descriptor)
  # Duplicate the current std-output (FD 1) and assigns it to FD 3.
  # This means that FD 3 now points to wherever the std-output was pointing.
  exec 3>&1

  local test_execution_result
  test_execution_result=$(
    state::initialize_assertions_count
    parallel::run_set_up

    # 2>&1: Redirects the std-error (FD 2) to the std-output (FD 1).
    # points to the original std-output.
    "$function_name" "$@" 2>&1

    parallel::run_tear_down
    parallel::clear_mocks
    state::export_subshell_context
  )

  # Closes FD 3, which was used temporarily to hold the original stdout.
  exec 3>&-

  # shellcheck disable=SC2155
  local test_suite_dir="${TEMP_DIR_PARALLEL_TEST_SUITE}/$(basename "$test_file" .sh)"
  mkdir -p "$test_suite_dir"
  echo "$test_execution_result" > "${test_suite_dir}/${function_name}.result"

  runner::parse_execution_result "$test_execution_result"

  local subshell_output
  subshell_output=$(\
    echo "$test_execution_result" |\
    tail -n 1 |\
    sed -E -e 's/.*##TEST_OUTPUT=(.*)##.*/\1/g' |\
    base64 -d
  )

  if [[ -n "$subshell_output" ]]; then
    # Formatted as "[type]line" @see `state::print_line()`
    local type="${subshell_output%%]*}" # Remove everything after "]"
    type="${type#[}"                    # Remove the leading "["
    local line="${subshell_output#*]}"  # Remove everything before and including "]"
    state::print_line "$type" "$line"

    subshell_output=$line
  fi

  local runtime_output
  runtime_output="${test_execution_result%%##ASSERTIONS*}"

  local runtime_error=""
  for error in "command not found" "unbound variable" "permission denied" \
      "no such file or directory" "syntax error" "bad substitution" \
      "division by 0" "cannot allocate memory" "bad file descriptor" \
      "segmentation fault" "illegal option" "argument list too long" \
      "readonly variable" "missing keyword" "killed" \
      "cannot execute binary file"; do
    if [[ "$runtime_output" == *"$error"* ]]; then
      runtime_error=$(echo "${runtime_output#*: }" | tr -d '\n')
      break
    fi
  done

  local total_assertions
  total_assertions="$(state::calculate_total_assertions "$test_execution_result")"

  local end_time duration_ns duration
  end_time=$(clock::now)
  duration_ns=$(math::calculate "($end_time - $start_time) ")
  duration=$(math::calculate "$duration_ns / 1000000")

  if [[ -n $runtime_error ]]; then
    state::add_tests_failed
    console_results::print_error_test "$function_name" "$runtime_error"
    logger::test_failed "$test_file" "$function_name" "$duration" "$total_assertions"
    runner::write_failure_result_output "$test_file" "$runtime_error"
    return
  fi

  if [[ "$current_assertions_failed" != "$(state::get_assertions_failed)" ]]; then
    state::add_tests_failed
    logger::test_failed "$test_file" "$function_name" "$duration" "$total_assertions"
    runner::write_failure_result_output "$test_file" "$subshell_output"
    if env::is_stop_on_failure_enabled; then
      exit 1
    fi
    return
  fi

  if [[ "$current_assertions_snapshot" != "$(state::get_assertions_snapshot)" ]]; then
    state::add_tests_snapshot
    console_results::print_snapshot_test "$function_name"
    logger::test_snapshot "$test_file" "$function_name" "$duration" "$total_assertions"
    return
  fi

  if [[ "$current_assertions_incomplete" != "$(state::get_assertions_incomplete)" ]]; then
    state::add_tests_incomplete
    logger::test_incomplete "$test_file" "$function_name" "$duration" "$total_assertions"
    return
  fi

  if [[ "$current_assertions_skipped" != "$(state::get_assertions_skipped)" ]]; then
    state::add_tests_skipped
    logger::test_skipped "$test_file" "$function_name" "$duration" "$total_assertions"
    return
  fi

  local label
  label="$(helper::normalize_test_function_name "$function_name")"

  console_results::print_successful_test "${label}" "$duration" "$@"
  state::add_tests_passed
  logger::test_passed "$test_file" "$function_name" "$duration" "$total_assertions"
##
}

function parallel::aggregate_test_results() {
  local total_failed=0
  local total_passed=0
  local total_skipped=0
  local total_incomplete=0
  local total_snapshot=0

  for script_dir in "$TEMP_DIR_PARALLEL_TEST_SUITE"/*; do
    for result_file in "$script_dir"/*.result; do
      while IFS= read -r line; do
        # Extract assertion counts from the result lines using sed
        failed=$(echo "$line" | sed -n 's/.*##ASSERTIONS_FAILED=\([0-9]*\).*/\1/p')
        passed=$(echo "$line" | sed -n 's/.*##ASSERTIONS_PASSED=\([0-9]*\).*/\1/p')
        skipped=$(echo "$line" | sed -n 's/.*##ASSERTIONS_SKIPPED=\([0-9]*\).*/\1/p')
        incomplete=$(echo "$line" | sed -n 's/.*##ASSERTIONS_INCOMPLETE=\([0-9]*\).*/\1/p')
        snapshot=$(echo "$line" | sed -n 's/.*##ASSERTIONS_SNAPSHOT=\([0-9]*\).*/\1/p')

        # Default to 0 if no match is found
        failed=${failed:-0}
        passed=${passed:-0}
        skipped=${skipped:-0}
        incomplete=${incomplete:-0}
        snapshot=${snapshot:-0}

        # Add to the total counts
        total_failed=$((total_failed + failed))
        total_passed=$((total_passed + passed))
        total_skipped=$((total_skipped + skipped))
        total_incomplete=$((total_incomplete + incomplete))
        total_snapshot=$((total_snapshot + snapshot))
      done < "$result_file"

      # Check and update test state based on the parsed results
      if [ "$passed" -gt 0 ]; then
        state::add_tests_passed
      fi

      if [ "$failed" -gt 0 ]; then
        state::add_tests_failed
      fi

      if [ "$skipped" -gt 0 ]; then
        state::add_tests_skipped
      fi

      if [ "$incomplete" -gt 0 ]; then
        state::add_tests_incomplete
      fi

      if [ "$snapshot" -gt 0 ]; then
        state::add_tests_snapshot
      fi
    done
  done

  export _ASSERTIONS_FAILED=$total_failed
  export _ASSERTIONS_PASSED=$total_passed
  export _ASSERTIONS_SKIPPED=$total_skipped
  export _ASSERTIONS_INCOMPLETE=$total_incomplete
  export _ASSERTIONS_SNAPSHOT=$total_snapshot
}


function parallel::write_failure_result_output() {
  local test_file=$1
  local error_msg=$2

  echo -e "$(state::get_tests_failed)) $test_file\n$error_msg" >> "$FAILURES_OUTPUT_PATH"
}

function parallel::run_set_up() {
  helper::execute_function_if_exists 'set_up'
}

function parallel::run_set_up_before_script() {
  helper::execute_function_if_exists 'set_up_before_script'
}

function parallel::run_tear_down() {
  helper::execute_function_if_exists 'tear_down'
}

function parallel::clear_mocks() {
  for i in "${!MOCKED_FUNCTIONS[@]}"; do
    unmock "${MOCKED_FUNCTIONS[$i]}"
  done
}

function parallel::run_tear_down_after_script() {
  helper::execute_function_if_exists 'tear_down_after_script'
}

function parallel::clean_set_up_and_tear_down_after_script() {
  helper::unset_if_exists 'set_up'
  helper::unset_if_exists 'tear_down'
  helper::unset_if_exists 'set_up_before_script'
  helper::unset_if_exists 'tear_down_after_script'
}
