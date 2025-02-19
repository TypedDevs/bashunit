#!/bin/bash
# shellcheck disable=SC2155

function runner::load_test_files() {
  local filter=$1
  shift
  local files=("${@}")

  for test_file in "${files[@]}"; do
    if [[ ! -f $test_file ]]; then
      continue
    fi
    # shellcheck source=/dev/null
    source "$test_file"
    runner::run_set_up_before_script
    if parallel::is_enabled; then
      runner::call_test_functions "$test_file" "$filter" 2>/dev/null &
    else
      runner::call_test_functions "$test_file" "$filter"
    fi
    runner::run_tear_down_after_script
    runner::clean_set_up_and_tear_down_after_script
  done

  if parallel::is_enabled; then
    wait
    runner::spinner &
    local spinner_pid=$!
    parallel::aggregate_test_results "$TEMP_DIR_PARALLEL_TEST_SUITE"
    # Kill the spinner once the aggregation finishes
    disown "$spinner_pid" && kill "$spinner_pid" &>/dev/null
    printf "\r " # Clear the spinner output
  fi
}

function runner::spinner() {
  if env::is_simple_output_enabled; then
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

function runner::call_test_functions() {
  local script="$1"
  local filter="$2"
  local prefix="test"
  # Use declare -F to list all function names
  local all_function_names=$(declare -F | awk '{print $3}')
  local filtered_functions=$(helper::get_functions_to_run "$prefix" "$filter" "$all_function_names")
  # shellcheck disable=SC2207
  local functions_to_run=($(runner::functions_for_script "$script" "$filtered_functions"))

  if [[ "${#functions_to_run[@]}" -le 0 ]]; then
    return
  fi

  runner::render_running_file_header
  helper::check_duplicate_functions "$script" || true

  for function_name in "${functions_to_run[@]}"; do
    if parallel::is_enabled && parallel::must_stop_on_failure; then
      break
    fi

    local provider_data=()
    while IFS=" " read -r line; do
      provider_data+=("$line")
    done <<< "$(helper::get_provider_data "$function_name" "$script")"

    # No data provider found
    if [[ "${#provider_data[@]}" -eq 0 ]]; then
      runner::run_test "$script" "$function_name"
      unset function_name
      continue
    fi

    # Execute the test function for each line of data
    for data in "${provider_data[@]}"; do
      IFS=" " read -r -a args <<< "$data"
      if [ "${#args[@]}" -gt 1 ]; then
        runner::run_test "$script" "$function_name" "${args[@]}"
      else
        runner::run_test "$script" "$function_name" "$data"
      fi
    done
    unset function_name
  done

  if ! env::is_simple_output_enabled; then
    echo ""
  fi
}

function runner::render_running_file_header() {
  if parallel::is_enabled; then
    return
  fi

  if ! env::is_simple_output_enabled; then
    if env::is_verbose_enabled; then
      printf "\n${_COLOR_BOLD}%s${_COLOR_DEFAULT}\n" "Running $script"
    else
      printf "${_COLOR_BOLD}%s${_COLOR_DEFAULT}\n" "Running $script"
    fi
  elif env::is_verbose_enabled; then
    printf "\n\n${_COLOR_BOLD}%s${_COLOR_DEFAULT}" "Running $script"
  fi
}

function runner::run_test() {
  local start_time
  start_time=$(clock::now)

  local test_file="$1"
  shift
  local function_name="$1"
  shift
  local current_assertions_failed="$(state::get_assertions_failed)"
  local current_assertions_snapshot="$(state::get_assertions_snapshot)"
  local current_assertions_incomplete="$(state::get_assertions_incomplete)"
  local current_assertions_skipped="$(state::get_assertions_skipped)"

  # (FD = File Descriptor)
  # Duplicate the current std-output (FD 1) and assigns it to FD 3.
  # This means that FD 3 now points to wherever the std-output was pointing.
  exec 3>&1

  local test_execution_result=$(
    trap '
      state::set_test_exit_code $?
      runner::run_tear_down
      runner::clear_mocks
      state::export_subshell_context
    ' EXIT
    state::initialize_assertions_count
    runner::run_set_up

    # 2>&1: Redirects the std-error (FD 2) to the std-output (FD 1).
    # points to the original std-output.
    "$function_name" "$@" 2>&1

  )

  # Closes FD 3, which was used temporarily to hold the original stdout.
  exec 3>&-

  local end_time=$(clock::now)
  local duration_ns=$(math::calculate "($end_time - $start_time) ")
  local duration=$(math::calculate "$duration_ns / 1000000")

  if env::is_verbose_enabled; then
    if env::is_simple_output_enabled; then
      echo ""
    fi

    printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '='
    printf "%s\n" "File:     $test_file"
    printf "%s\n" "Function: $function_name"
    printf "%s\n" "Duration: $duration ms"
    local raw_text=${test_execution_result%%##ASSERTIONS_*}
    [[ -n $raw_text ]] && printf "%s" "Raw text: ${test_execution_result%%##ASSERTIONS_*}"
    printf "%s\n" "##ASSERTIONS_${test_execution_result#*##ASSERTIONS_}"
    printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '-'
  fi

  local subshell_output=$(runner::decode_subshell_output "$test_execution_result")

  if [[ -n "$subshell_output" ]]; then
    # Formatted as "[type]line" @see `state::print_line()`
    local type="${subshell_output%%]*}" # Remove everything after "]"
    type="${type#[}"                    # Remove the leading "["
    local line="${subshell_output#*]}"  # Remove everything before and including "]"

    # Replace [type] with a newline to split the messages
    line=$(echo "$line" | sed -e 's/\[failed\]/\n/g' \
                              -e 's/\[skipped\]/\n/g' \
                              -e 's/\[incomplete\]/\n/g')

    state::print_line "$type" "$line"

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
      runtime_error=$(echo "${runtime_output#*: }" | tr -d '\n')
      break
    fi
  done

  runner::parse_result "$function_name" "$test_execution_result" "$@"

  local total_assertions="$(state::calculate_total_assertions "$test_execution_result")"
  local test_exit_code="$(state::get_test_exit_code)"

  if [[ -n $runtime_error || $test_exit_code -ne 0 ]]; then
    state::add_tests_failed
    console_results::print_error_test "$function_name" "$runtime_error"
    reports::add_test_failed "$test_file" "$function_name" "$duration" "$total_assertions"
    runner::write_failure_result_output "$test_file" "$runtime_error"
    return
  fi

  if [[ "$current_assertions_failed" != "$(state::get_assertions_failed)" ]]; then
    state::add_tests_failed
    reports::add_test_failed "$test_file" "$function_name" "$duration" "$total_assertions"
    runner::write_failure_result_output "$test_file" "$subshell_output"

    if env::is_stop_on_failure_enabled; then
      if parallel::is_enabled; then
        parallel::mark_stop_on_failure
      else
        exit "$EXIT_CODE_STOP_ON_FAILURE"
      fi
    fi
    return
  fi

  if [[ "$current_assertions_snapshot" != "$(state::get_assertions_snapshot)" ]]; then
    state::add_tests_snapshot
    console_results::print_snapshot_test "$function_name"
    reports::add_test_snapshot "$test_file" "$function_name" "$duration" "$total_assertions"
    return
  fi

  if [[ "$current_assertions_incomplete" != "$(state::get_assertions_incomplete)" ]]; then
    state::add_tests_incomplete
    reports::add_test_incomplete "$test_file" "$function_name" "$duration" "$total_assertions"
    return
  fi

  if [[ "$current_assertions_skipped" != "$(state::get_assertions_skipped)" ]]; then
    state::add_tests_skipped
    reports::add_test_skipped "$test_file" "$function_name" "$duration" "$total_assertions"
    return
  fi

  local label="$(helper::normalize_test_function_name "$function_name")"

  console_results::print_successful_test "${label}" "$duration" "$@"
  state::add_tests_passed
  reports::add_test_passed "$test_file" "$function_name" "$duration" "$total_assertions"
}

function runner::decode_subshell_output() {
  local test_execution_result="$1"

  local test_output_base64="${test_execution_result##*##TEST_OUTPUT=}"
  test_output_base64="${test_output_base64%%##*}"

  local subshell_output
  if command -v base64 >/dev/null; then
    echo "$test_output_base64" | base64 -d
  else
    echo "$test_output_base64" | openssl enc -d -base64
  fi
}

function runner::parse_result() {
  local function_name=$1
  shift
  local execution_result=$1
  shift
  local args=("$@")

  if parallel::is_enabled; then
    runner::parse_result_parallel "$function_name" "$execution_result" "${args[@]}"
  else
    runner::parse_result_sync "$function_name" "$execution_result"
  fi
}

function runner::parse_result_parallel() {
  local function_name=$1
  shift
  local execution_result=$1
  shift
  local args=("$@")

  local test_suite_dir="${TEMP_DIR_PARALLEL_TEST_SUITE}/$(basename "$test_file" .sh)"
  mkdir -p "$test_suite_dir"

  local test_result_file=$(echo "${args[@]}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//')
  if [[ -z "$test_result_file" ]]; then
    test_result_file="${function_name}.$$.result"
  else
    test_result_file="${function_name}-${test_result_file}.$$.result"
  fi

  local unique_test_result_file="${test_suite_dir}/${test_result_file}"
  local count=1

  while [ -e "$unique_test_result_file" ]; do
    unique_test_result_file="${test_suite_dir}/${test_result_file%.result}-$count.result"
    count=$((count + 1))
  done

  log "debug" "[PARA]" "function_name:$function_name" "execution_result:$execution_result"

  runner::parse_result_sync "$function_name" "$execution_result"

  echo "$execution_result" > "$unique_test_result_file"
}

function runner::parse_result_sync() {
  local function_name=$1
  local execution_result=$2

  local assertions_failed=$(\
    echo "$execution_result" |\
    tail -n 1 |\
    sed -E -e 's/.*##ASSERTIONS_FAILED=([0-9]*)##.*/\1/g'\
  )

  local assertions_passed=$(\
    echo "$execution_result" |\
    tail -n 1 |\
    sed -E -e 's/.*##ASSERTIONS_PASSED=([0-9]*)##.*/\1/g'\
  )

  local assertions_skipped=$(\
    echo "$execution_result" |\
    tail -n 1 |\
    sed -E -e 's/.*##ASSERTIONS_SKIPPED=([0-9]*)##.*/\1/g'\
  )

  local assertions_incomplete=$(\
    echo "$execution_result" |\
    tail -n 1 |\
    sed -E -e 's/.*##ASSERTIONS_INCOMPLETE=([0-9]*)##.*/\1/g'\
  )

  local assertions_snapshot=$(\
    echo "$execution_result" |\
    tail -n 1 |\
    sed -E -e 's/.*##ASSERTIONS_SNAPSHOT=([0-9]*)##.*/\1/g'\
  )

  local test_exit_code=$(\
    echo "$execution_result" |\
    tail -n 1 |\
    sed -E -e 's/.*##TEST_EXIT_CODE=([0-9]*)##.*/\1/g'\
  )

  log "debug" "[SYNC]" "function_name:$function_name" "execution_result:$execution_result"

  ((_ASSERTIONS_PASSED += assertions_passed)) || true
  ((_ASSERTIONS_FAILED += assertions_failed)) || true
  ((_ASSERTIONS_SKIPPED += assertions_skipped)) || true
  ((_ASSERTIONS_INCOMPLETE += assertions_incomplete)) || true
  ((_ASSERTIONS_SNAPSHOT += assertions_snapshot)) || true
  ((_TEST_EXIT_CODE += test_exit_code)) || true
}

function runner::write_failure_result_output() {
  local test_file=$1
  local error_msg=$2

  local test_nr="*"
  if ! parallel::is_enabled; then
    test_nr=$(state::get_tests_failed)
  fi

  echo -e "$test_nr) $test_file\n$error_msg" >> "$FAILURES_OUTPUT_PATH"
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
