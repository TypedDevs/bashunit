#!/bin/bash

function runner::load_test_files() {
  local filter=$1
  local files=("${@:2}") # Store all arguments starting from the second as an array

  if [[ "${#files[@]}" == 0 ]]; then
    if [[ -n "${DEFAULT_PATH}" ]]; then
      while IFS='' read -r line; do
        files+=("$line");
      done < <(helper::find_files_recursive "$DEFAULT_PATH")
    else
      printf "%sError: At least one file path is required.%s\n" "${_COLOR_FAILED}" "${_COLOR_DEFAULT}"
      console_header::print_help
      exit 1
    fi
  fi

  for test_file in "${files[@]}"; do
    if [[ ! -f $test_file ]]; then
      continue
    fi

    # shellcheck source=/dev/null
    source "$test_file"

    runner::run_set_up_before_script
    runner::call_test_functions "$test_file" "$filter"
    if [ "$BASHUNIT_PARALLEL_RUN" = true ] ; then
      wait
    fi
    runner::run_tear_down_after_script
    runner::clean_set_up_and_tear_down_after_script
  done
}

function runner::functions_for_script() {
  local script="$1"
  local all_function_names="$2"

  # Filter the names down to the ones defined in the script, sort them by line number
  shopt -s extdebug
  for f in $all_function_names; do
    declare -F "$f" | grep "$script"
  done | sort -k2 -n | awk '{print $1}'
  shopt -u extdebug
}

# Helper function for test authors to invoke a named test case
function run_test() {
  runner::run_test "testing-fn" "$function_name" "$@"
}

function runner::call_test_functions() {
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
  functions_to_run=($(runner::functions_for_script "$script" "$filtered_functions"))

  if [[ "${#functions_to_run[@]}" -gt 0 ]]; then
    if [[ "$SIMPLE_OUTPUT" == false ]]; then
      echo "Running $script"
    fi

    helper::check_duplicate_functions "$script" || true

    for function_name in "${functions_to_run[@]}"; do
      local provider_data=()
      IFS=" " read -r -a provider_data <<< "$(helper::get_provider_data "$function_name" "$script")"

      if [[ "${#provider_data[@]}" -gt 0 ]]; then
        for data in "${provider_data[@]}"; do
          runner::run_test "$script" "$function_name" "$data"
        done
      else
        local multi_invoker
        multi_invoker=$(helper::get_multi_invoker_function "$function_name" "$script")
        if [[ -n "${multi_invoker}" ]]; then
          helper::execute_function_if_exists "${multi_invoker}"
        else
          runner::run_test "$script" "$function_name"
        fi
      fi

      unset function_name
    done
  fi
}

function runner::parse_execution_result() {
  local execution_result=$1

  local assertions_failed
  assertions_failed=$(\
    echo "$execution_result" |\
    tail -n 1 |\
    sed -E -e 's/.*##ASSERTIONS_FAILED=([0-9]*)##.*/\1/g'\
  )

  local assertions_passed
  assertions_passed=$(\
    echo "$execution_result" |\
    tail -n 1 |\
    sed -E -e 's/.*##ASSERTIONS_PASSED=([0-9]*)##.*/\1/g'\
  )

  local assertions_skipped
  assertions_skipped=$(\
    echo "$execution_result" |\
    tail -n 1 |\
    sed -E -e 's/.*##ASSERTIONS_SKIPPED=([0-9]*)##.*/\1/g'\
  )

  local assertions_incomplete
  assertions_incomplete=$(\
    echo "$execution_result" |\
    tail -n 1 |\
    sed -E -e 's/.*##ASSERTIONS_INCOMPLETE=([0-9]*)##.*/\1/g'\
  )

  local assertions_snapshot
  assertions_snapshot=$(\
    echo "$execution_result" |\
    tail -n 1 |\
    sed -E -e 's/.*##ASSERTIONS_SNAPSHOT=([0-9]*)##.*/\1/g'\
  )

  ((_ASSERTIONS_PASSED += assertions_passed)) || true
  ((_ASSERTIONS_FAILED += assertions_failed)) || true
  ((_ASSERTIONS_SKIPPED += assertions_skipped)) || true
  ((_ASSERTIONS_INCOMPLETE += assertions_incomplete)) || true
  ((_ASSERTIONS_SNAPSHOT += assertions_snapshot)) || true
}

function runner::run_test() {
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
    runner::run_set_up

    # 2>&1: Redirects the std-error (FD 2) to the std-output (FD 1).
    # 1>&3: Redirects the std-output (FD 1) to FD 3, which, as set up earlier,
    # points to the original std-output.
    "$function_name" "$@" 2>&1 1>&3

    runner::run_tear_down
    runner::clear_mocks
    state::export_assertions_count
  )

  # Closes FD 3, which was used temporarily to hold the original std-output.
  exec 3>&-

  runner::parse_execution_result "$test_execution_result"

  local runtime_error
  runtime_error=$(\
    echo "$test_execution_result" |\
    tail -n 1 |\
    sed -E -e 's/(.*)##ASSERTIONS_FAILED=.*/\1/g'\
  )
  local total_assertions
  total_assertions="$(state::calculate_total_assertions "$test_execution_result")"

  if [[ -n $runtime_error ]]; then
    state::add_tests_failed
    console_results::print_error_test "$function_name" "$runtime_error"
    logger::test_failed "$test_file" "$function_name" "$start_time" "$total_assertions"
    return
  fi

  if [[ "$current_assertions_failed" != "$(state::get_assertions_failed)" ]]; then
    state::add_tests_failed
    logger::test_failed "$test_file" "$function_name" "$start_time" "$total_assertions"

    if [ "$STOP_ON_FAILURE" = true ]; then
      exit 1
    fi

    return
  fi

  if [[ "$current_assertions_snapshot" != "$(state::get_assertions_snapshot)" ]]; then
    state::add_tests_snapshot
    console_results::print_snapshot_test "$function_name"
    logger::test_snapshot "$test_file" "$function_name" "$start_time" "$total_assertions"
    return
  fi

  if [[ "$current_assertions_incomplete" != "$(state::get_assertions_incomplete)" ]]; then
    state::add_tests_incomplete
    logger::test_incomplete "$test_file" "$function_name" "$start_time" "$total_assertions"
    return
  fi

  if [[ "$current_assertions_skipped" != "$(state::get_assertions_skipped)" ]]; then
    state::add_tests_skipped
    logger::test_skipped "$test_file" "$function_name" "$start_time" "$total_assertions"
    return
  fi

  local label
  label="$(helper::normalize_test_function_name "$function_name")"

  console_results::print_successful_test "${label}" "$@"
  state::add_tests_passed
  logger::test_passed "$test_file" "$function_name" "$start_time" "$total_assertions"
}

function runner::run_set_up() {
  helper::execute_function_if_exists 'set_up'
}

function runner::run_set_up_before_script() {
  helper::execute_function_if_exists 'set_up_before_script'
}

function runner::run_tear_down() {
  helper::execute_function_if_exists 'tear_down'
}

function runner::clear_mocks() {
  for i in "${!MOCKED_FUNCTIONS[@]}"; do
    unmock "${MOCKED_FUNCTIONS[$i]}"
  done
}

function runner::run_tear_down_after_script() {
  helper::execute_function_if_exists 'tear_down_after_script'
}

function runner::clean_set_up_and_tear_down_after_script() {
  helper::unset_if_exists 'set_up'
  helper::unset_if_exists 'tear_down'
  helper::unset_if_exists 'set_up_before_script'
  helper::unset_if_exists 'tear_down_after_script'
}
