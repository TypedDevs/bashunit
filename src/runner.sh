#!/usr/bin/env bash
# shellcheck disable=SC2155

function runner::load_test_files() {
  local filter=$1
  shift
  local files=("${@}")
  local scripts_ids=()

  for test_file in "${files[@]}"; do
    if [[ ! -f $test_file ]]; then
      continue
    fi
    unset BASHUNIT_CURRENT_TEST_ID
    export BASHUNIT_CURRENT_SCRIPT_ID="$(helper::generate_id "${test_file}")"
    scripts_ids+=("${BASHUNIT_CURRENT_SCRIPT_ID}")
    internal_log "Loading file" "$test_file"
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
    if ! parallel::is_enabled; then
      cleanup_script_temp_files
    fi
    internal_log "Finished file" "$test_file"
  done

  if parallel::is_enabled; then
    wait
    runner::spinner &
    local spinner_pid=$!
    parallel::aggregate_test_results "$TEMP_DIR_PARALLEL_TEST_SUITE"
    # Kill the spinner once the aggregation finishes
    disown "$spinner_pid" && kill "$spinner_pid" &>/dev/null
    printf "\r " # Clear the spinner output
    for script_id in "${scripts_ids[@]}"; do
      export BASHUNIT_CURRENT_SCRIPT_ID="${script_id}"
      cleanup_script_temp_files
    done
  fi
}

function runner::load_bench_files() {
  local filter=$1
  shift
  local files=("${@}")

  for bench_file in "${files[@]}"; do
    [[ -f $bench_file ]] || continue
    unset BASHUNIT_CURRENT_TEST_ID
    export BASHUNIT_CURRENT_SCRIPT_ID="$(helper::generate_id "${test_file}")"
    # shellcheck source=/dev/null
    source "$bench_file"
    runner::run_set_up_before_script
    runner::call_bench_functions "$bench_file" "$filter"
    runner::run_tear_down_after_script
    runner::clean_set_up_and_tear_down_after_script
    cleanup_script_temp_files
  done
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

function runner::parse_data_provider_args() {
  local input="$1"
  local current_arg=""
  local in_quotes=false
  local quote_char=""
  local escaped=false
  local i
  local arg
  local encoded_arg
  local -a args=()
  # Parse args from the input string into an array, respecting quotes and escapes
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
          args+=("$current_arg")
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
  # Print one arg per line to stdout, base64-encoded to preserve newlines in the data
  for arg in "${args[@]}"; do
    encoded_arg="$(echo "$arg" | base64 2>/dev/null)"
    printf '%s\n' "$encoded_arg"
  done
}

function runner::call_test_functions() {
  local script="$1"
  local filter="$2"
  local prefix="test"
  # Use declare -F to list all function names
  local all_fn_names=$(declare -F | awk '{print $3}')
  local filtered_functions=$(helper::get_functions_to_run "$prefix" "$filter" "$all_fn_names")
  # shellcheck disable=SC2207
  local functions_to_run=($(runner::functions_for_script "$script" "$filtered_functions"))

  if [[ "${#functions_to_run[@]}" -le 0 ]]; then
    return
  fi

  runner::render_running_file_header "$script"
  helper::check_duplicate_functions "$script" || true

  for fn_name in "${functions_to_run[@]}"; do
    if parallel::is_enabled && parallel::must_stop_on_failure; then
      break
    fi

    local provider_data=()
    while IFS=" " read -r line; do
      provider_data+=("$line")
    done <<< "$(helper::get_provider_data "$fn_name" "$script")"

    # No data provider found
    if [[ "${#provider_data[@]}" -eq 0 ]]; then
      runner::run_test "$script" "$fn_name"
      unset fn_name
      continue
    fi

    # Execute the test function for each line of data
    for data in "${provider_data[@]}"; do
      local parsed_data=()
      while IFS= read -r line; do
        parsed_data+=( "$(echo "$line" | base64 -d 2>/dev/null)" )
      done <<< "$(runner::parse_data_provider_args "$data")"
      runner::run_test "$script" "$fn_name" "${parsed_data[@]}"
    done
    unset fn_name
  done

  if ! env::is_simple_output_enabled; then
    echo ""
  fi
}

function runner::call_bench_functions() {
  local script="$1"
  local filter="$2"
  local prefix="bench"

  local all_fn_names=$(declare -F | awk '{print $3}')
  local filtered_functions=$(helper::get_functions_to_run "$prefix" "$filter" "$all_fn_names")
  # shellcheck disable=SC2207
  local functions_to_run=($(runner::functions_for_script "$script" "$filtered_functions"))

  if [[ "${#functions_to_run[@]}" -le 0 ]]; then
    return
  fi

  if env::is_bench_mode_enabled; then
    runner::render_running_file_header "$script"
  fi

  for fn_name in "${functions_to_run[@]}"; do
    read -r revs its max_ms <<< "$(benchmark::parse_annotations "$fn_name" "$script")"
    benchmark::run_function "$fn_name" "$revs" "$its" "$max_ms"
    unset fn_name
  done

  if ! env::is_simple_output_enabled; then
    echo ""
  fi
}

function runner::render_running_file_header() {
  local script="$1"

  internal_log "Running file" "$script"

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
  local fn_name="$1"
  shift

  internal_log "Running test" "$fn_name" "$*"
  # Export a unique test identifier so that test doubles can
  # create temporary files scoped per test run. This prevents
  # race conditions when running tests in parallel.
  export BASHUNIT_CURRENT_TEST_ID="$(helper::generate_id "$fn_name")"

  state::reset_test_title

  local interpolated_fn_name="$(helper::interpolate_function_name "$fn_name" "$@")"
  local current_assertions_failed="$(state::get_assertions_failed)"
  local current_assertions_snapshot="$(state::get_assertions_snapshot)"
  local current_assertions_incomplete="$(state::get_assertions_incomplete)"
  local current_assertions_skipped="$(state::get_assertions_skipped)"

  # (FD = File Descriptor)
  # Duplicate the current std-output (FD 1) and assigns it to FD 3.
  # This means that FD 3 now points to wherever the std-output was pointing.
  exec 3>&1

  local test_execution_result=$(
    # shellcheck disable=SC2154
    trap '
      exit_code=$?
      set +e
      state::set_test_exit_code "$exit_code"
      runner::run_tear_down
      runner::clear_mocks
      cleanup_testcase_temp_files
      state::export_subshell_context
    ' EXIT
    state::initialize_assertions_count
    runner::run_set_up

    # 2>&1: Redirects the std-error (FD 2) to the std-output (FD 1).
    # points to the original std-output.
    "$fn_name" "$@" 2>&1

  )

  # Closes FD 3, which was used temporarily to hold the original stdout.
  exec 3>&-

  local end_time=$(clock::now)
  local duration_ns=$((end_time - start_time))
  local duration=$((duration_ns / 1000000))

  if env::is_verbose_enabled; then
    if env::is_simple_output_enabled; then
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

  runner::parse_result "$fn_name" "$test_execution_result" "$@"

  local total_assertions="$(state::calculate_total_assertions "$test_execution_result")"
  local test_exit_code="$(state::get_test_exit_code)"

  local encoded_test_title
  encoded_test_title="${test_execution_result##*##TEST_TITLE=}"
  encoded_test_title="${encoded_test_title%%##*}"
  local test_title=""
  [[ -n "$encoded_test_title" ]] && test_title="$(helper::decode_base64 "$encoded_test_title")"

  state::set_test_title "$test_title"
  local label
  label="$(helper::normalize_test_function_name "$fn_name" "$interpolated_fn_name")"
  state::reset_test_title

  if [[ -n $runtime_error || $test_exit_code -ne 0 ]]; then
    state::add_tests_failed
    console_results::print_error_test "$label" "$runtime_error"
    reports::add_test_failed "$test_file" "$label" "$duration" "$total_assertions"
    runner::write_failure_result_output "$test_file" "$fn_name" "$runtime_error"
    internal_log "Test error" "$label" "$runtime_error"
    return
  fi

  if [[ "$current_assertions_failed" != "$(state::get_assertions_failed)" ]]; then
    state::add_tests_failed
    reports::add_test_failed "$test_file" "$label" "$duration" "$total_assertions"
    runner::write_failure_result_output "$test_file" "$fn_name" "$subshell_output"

    internal_log "Test failed" "$label"

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
    console_results::print_snapshot_test "$label"
    reports::add_test_snapshot "$test_file" "$label" "$duration" "$total_assertions"
    internal_log "Test snapshot" "$label"
    return
  fi

  if [[ "$current_assertions_incomplete" != "$(state::get_assertions_incomplete)" ]]; then
    state::add_tests_incomplete
    reports::add_test_incomplete "$test_file" "$label" "$duration" "$total_assertions"
    internal_log "Test incomplete" "$label"
    return
  fi

  if [[ "$current_assertions_skipped" != "$(state::get_assertions_skipped)" ]]; then
    state::add_tests_skipped
    reports::add_test_skipped "$test_file" "$label" "$duration" "$total_assertions"
    internal_log "Test skipped" "$label"
    return
  fi

  if [[ "$fn_name" == "$interpolated_fn_name" ]]; then
    console_results::print_successful_test "${label}" "$duration" "$@"
  else
    console_results::print_successful_test "${label}" "$duration"
  fi
  state::add_tests_passed
  reports::add_test_passed "$test_file" "$label" "$duration" "$total_assertions"
  internal_log "Test passed" "$label"
}

function runner::decode_subshell_output() {
  local test_execution_result="$1"

  local test_output_base64="${test_execution_result##*##TEST_OUTPUT=}"
  test_output_base64="${test_output_base64%%##*}"
  helper::decode_base64 "$test_output_base64"
}

function runner::parse_result() {
  local fn_name=$1
  shift
  local execution_result=$1
  shift
  local args=("$@")

  if parallel::is_enabled; then
    runner::parse_result_parallel "$fn_name" "$execution_result" "${args[@]}"
  else
    runner::parse_result_sync "$fn_name" "$execution_result"
  fi
}

function runner::parse_result_parallel() {
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

  internal_log "[PARA]" "fn_name:$fn_name" "execution_result:$execution_result"

  runner::parse_result_sync "$fn_name" "$execution_result"

  echo "$execution_result" > "$unique_test_result_file"
}

# shellcheck disable=SC2295
function runner::parse_result_sync() {
  local fn_name=$1
  local execution_result=$2

  local result_line
  result_line=$(echo "$execution_result" | tail -n 1)

  local assertions_failed=0
  local assertions_passed=0
  local assertions_skipped=0
  local assertions_incomplete=0
  local assertions_snapshot=0
  local test_exit_code=0

  local regex
  regex='ASSERTIONS_FAILED=([0-9]*)##'
  regex+='ASSERTIONS_PASSED=([0-9]*)##'
  regex+='ASSERTIONS_SKIPPED=([0-9]*)##'
  regex+='ASSERTIONS_INCOMPLETE=([0-9]*)##'
  regex+='ASSERTIONS_SNAPSHOT=([0-9]*)##'
  regex+='TEST_EXIT_CODE=([0-9]*)'

  if [[ $result_line =~ $regex ]]; then
    assertions_failed="${BASH_REMATCH[1]}"
    assertions_passed="${BASH_REMATCH[2]}"
    assertions_skipped="${BASH_REMATCH[3]}"
    assertions_incomplete="${BASH_REMATCH[4]}"
    assertions_snapshot="${BASH_REMATCH[5]}"
    test_exit_code="${BASH_REMATCH[6]}"
  fi

  internal_log "[SYNC]" "fn_name:$fn_name" "execution_result:$execution_result"

  ((_ASSERTIONS_PASSED += assertions_passed)) || true
  ((_ASSERTIONS_FAILED += assertions_failed)) || true
  ((_ASSERTIONS_SKIPPED += assertions_skipped)) || true
  ((_ASSERTIONS_INCOMPLETE += assertions_incomplete)) || true
  ((_ASSERTIONS_SNAPSHOT += assertions_snapshot)) || true
  ((_TEST_EXIT_CODE += test_exit_code)) || true

  internal_log "result_summary" \
    "failed:$assertions_failed" \
    "passed:$assertions_passed" \
    "skipped:$assertions_skipped" \
    "incomplete:$assertions_incomplete" \
    "snapshot:$assertions_snapshot" \
    "exit_code:$test_exit_code"
}

function runner::write_failure_result_output() {
  local test_file=$1
  local fn_name=$2
  local error_msg=$3

  local line_number
  line_number=$(helper::get_function_line_number "$fn_name")

  local test_nr="*"
  if ! parallel::is_enabled; then
    test_nr=$(state::get_tests_failed)
  fi

  echo -e "$test_nr) $test_file:$line_number\n$error_msg" >> "$FAILURES_OUTPUT_PATH"
}

function runner::run_set_up() {
  internal_log "run_set_up"
  helper::execute_function_if_exists 'set_up'
}

function runner::run_set_up_before_script() {
  internal_log "run_set_up_before_script"
  helper::execute_function_if_exists 'set_up_before_script'
}

function runner::run_tear_down() {
  internal_log "run_tear_down"
  helper::execute_function_if_exists 'tear_down'
}

function runner::clear_mocks() {
  for i in "${!MOCKED_FUNCTIONS[@]}"; do
    unmock "${MOCKED_FUNCTIONS[$i]}"
  done
}

function runner::run_tear_down_after_script() {
  internal_log "run_tear_down_after_script"
  helper::execute_function_if_exists 'tear_down_after_script'
}

function runner::clean_set_up_and_tear_down_after_script() {
  internal_log "clean_set_up_and_tear_down_after_script"
  helper::unset_if_exists 'set_up'
  helper::unset_if_exists 'tear_down'
  helper::unset_if_exists 'set_up_before_script'
  helper::unset_if_exists 'tear_down_after_script'
}
