#!/usr/bin/env bash
# shellcheck disable=SC2155

# Pre-compiled regex pattern for parsing test result assertions
if [ -z "${_BASHUNIT_RUNNER_PARSE_RESULT_REGEX+x}" ]; then
  declare -r _BASHUNIT_RUNNER_PARSE_RESULT_REGEX='ASSERTIONS_FAILED=([0-9]*)##'\
'ASSERTIONS_PASSED=([0-9]*)##ASSERTIONS_SKIPPED=([0-9]*)##'\
'ASSERTIONS_INCOMPLETE=([0-9]*)##ASSERTIONS_SNAPSHOT=([0-9]*)##TEST_EXIT_CODE=([0-9]*)'
fi

function bashunit::runner::restore_workdir() {
  cd "$BASHUNIT_WORKING_DIR" 2>/dev/null || true
}

##
# Whether the running Bash has a reliable `set -o pipefail`. Bash 3.0 shipped a
# broken pipefail (a failing pipeline can wrongly report success), which makes
# `--strict` unsound; on 3.0 we fall back to `set -eu` without pipefail.
# Returns: 0 when pipefail is reliable (Bash >= 3.1), 1 otherwise.
##
function bashunit::runner::_supports_reliable_pipefail() {
  if [ "${BASH_VERSINFO[0]:-0}" -gt 3 ]; then
    return 0
  fi
  [ "${BASH_VERSINFO[0]:-0}" -eq 3 ] && [ "${BASH_VERSINFO[1]:-0}" -ge 1 ]
}

# Caches BASHUNIT_COVERAGE into _BASHUNIT_COVERAGE_ON ("1"|"0") so hot-path checks
# avoid a function dispatch per call. Call once after arg parsing; tests that
# toggle BASHUNIT_COVERAGE mid-run must call this again to refresh.
function bashunit::runner::sync_coverage_flag() {
  if [ "${BASHUNIT_COVERAGE-}" = "true" ]; then
    _BASHUNIT_COVERAGE_ON=1
  else
    _BASHUNIT_COVERAGE_ON=0
  fi
}

function bashunit::runner::source_login_shell_profiles() {
  # shellcheck disable=SC1091
  [ -f /etc/profile ] && source /etc/profile 2>/dev/null || true
  # shellcheck disable=SC1090
  [ -f ~/.bash_profile ] && source ~/.bash_profile 2>/dev/null || true
  # shellcheck disable=SC1090
  [ -f ~/.bash_login ] && source ~/.bash_login 2>/dev/null || true
  # shellcheck disable=SC1090
  [ -f ~/.profile ] && source ~/.profile 2>/dev/null || true
}

function bashunit::runner::export_test_identity() {
  local test_file=$1
  local fn_name=$2
  bashunit::helper::generate_id "$fn_name"
  export BASHUNIT_CURRENT_TEST_ID="$_BASHUNIT_HELPER_ID_OUT"
  bashunit::runner::resolve_test_location "$test_file" "$fn_name"
  export _BASHUNIT_TEST_LOCATION
  if [ "${_BASHUNIT_COVERAGE_ON:-0}" = 1 ]; then
    export _BASHUNIT_COVERAGE_CURRENT_TEST_FILE="$test_file"
    export _BASHUNIT_COVERAGE_CURRENT_TEST_FN="$fn_name"
  fi
}

##
# Resolves "<test_file>:<line>" for a test function and writes it into the
# global _BASHUNIT_TEST_LOCATION, using `declare -F` under `extdebug` to read
# the definition line. Falls back to just the file path when the line cannot be
# determined. Bash 3.0+ compatible. Writes a global slot (no extra subshell).
# Arguments: $1 test file, $2 function name
##
function bashunit::runner::resolve_test_location() {
  local test_file=$1
  local fn_name=$2

  # Enable extdebug only inside the command-substitution subshell so it never
  # leaks into the parent shell — globally toggling extdebug interferes with
  # `set -e`/DEBUG-trap behavior under --strict.
  local def line=""
  def="$(shopt -s extdebug; declare -F "$fn_name" 2>/dev/null)" || true

  # `declare -F` (with extdebug) prints "<name> <line> <file>".
  if [ -n "$def" ]; then
    line=${def#* }
    line=${line%% *}
  fi

  if [ -n "$line" ]; then
    _BASHUNIT_TEST_LOCATION="${test_file}:${line}"
  else
    _BASHUNIT_TEST_LOCATION="$test_file"
  fi
}

# Writes the interpolated test-function name into _BASHUNIT_RUNNER_INTERP_OUT.
# Arguments: $1 fn_name, $@ test arguments
function bashunit::runner::apply_interpolated_title() {
  local fn_name=$1
  shift

  # Only "::N::"-style names interpolate; skip the capture fork for the rest.
  case "$fn_name" in
  *::*) ;;
  *)
    bashunit::state::reset_current_test_interpolated_function_name
    _BASHUNIT_RUNNER_INTERP_OUT=$fn_name
    return
    ;;
  esac

  local interpolated
  interpolated="$(bashunit::helper::interpolate_function_name "$fn_name" "$@")"
  if [ "$interpolated" != "$fn_name" ]; then
    bashunit::state::set_current_test_interpolated_function_name "$interpolated"
  else
    bashunit::state::reset_current_test_interpolated_function_name
  fi
  _BASHUNIT_RUNNER_INTERP_OUT=$interpolated
}

# Hot-path result helpers below return their value via a dedicated global slot
# (`_BASHUNIT_RUNNER_*_OUT`) instead of stdout. This avoids the per-test
# `$(...)` subshell capture that dominated the result-parsing hot path. Callers
# invoke the helper and immediately read the slot:
#
#   bashunit::runner::extract_subshell_type "$subshell_output"
#   type=$_BASHUNIT_RUNNER_TYPE_OUT
#
# A dedicated slot per helper (rather than one shared slot) means nested or
# adjacent calls cannot clobber each other and callers don't need to copy out
# before every other helper runs.
_BASHUNIT_RUNNER_FIELD_OUT=""
_BASHUNIT_RUNNER_TOTAL_OUT=""
_BASHUNIT_RUNNER_TYPE_OUT=""
_BASHUNIT_RUNNER_OUTPUT_OUT=""
_BASHUNIT_RUNNER_INTERP_OUT=""
_BASHUNIT_RUNNER_COUNTS_FAILED_OUT=0
_BASHUNIT_RUNNER_COUNTS_PASSED_OUT=0
_BASHUNIT_RUNNER_COUNTS_SKIPPED_OUT=0
_BASHUNIT_RUNNER_COUNTS_INCOMPLETE_OUT=0
_BASHUNIT_RUNNER_COUNTS_SNAPSHOT_OUT=0
_BASHUNIT_RUNNER_COUNTS_EXIT_CODE_OUT=0
_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT=""
_BASHUNIT_RUNNER_SUBSHELL_OUTPUT_OUT=""
# Suffix appended to a passed-test line when it only passed after retrying.
_BASHUNIT_RETRY_NOTE=""

# Writes the value of an encoded field (##KEY=value##) into _BASHUNIT_RUNNER_FIELD_OUT.
# Arguments: $1 test_execution_result, $2 key
function bashunit::runner::extract_encoded_field() {
  local test_execution_result=$1
  local key=$2
  local marker="##${key}="
  case "$test_execution_result" in
  *"$marker"*)
    local rest="${test_execution_result#*"$marker"}"
    _BASHUNIT_RUNNER_FIELD_OUT="${rest%%##*}"
    ;;
  *) _BASHUNIT_RUNNER_FIELD_OUT="" ;;
  esac
}

# Writes the sum of all ASSERTIONS_* counters into _BASHUNIT_RUNNER_TOTAL_OUT.
# Arguments: $1 test_execution_result
function bashunit::runner::compute_total_assertions() {
  local test_execution_result=$1
  local failed passed skipped incomplete snapshot
  failed="${test_execution_result##*##ASSERTIONS_FAILED=}"
  failed="${failed%%##*}"
  passed="${test_execution_result##*##ASSERTIONS_PASSED=}"
  passed="${passed%%##*}"
  skipped="${test_execution_result##*##ASSERTIONS_SKIPPED=}"
  skipped="${skipped%%##*}"
  incomplete="${test_execution_result##*##ASSERTIONS_INCOMPLETE=}"
  incomplete="${incomplete%%##*}"
  snapshot="${test_execution_result##*##ASSERTIONS_SNAPSHOT=}"
  snapshot="${snapshot%%##*}"
  local total
  total=$((${failed:-0} + ${passed:-0} + ${skipped:-0}))
  total=$((total + ${incomplete:-0} + ${snapshot:-0}))
  _BASHUNIT_RUNNER_TOTAL_OUT=$total
}

# Writes the subshell type marker (text inside leading [...]) into _BASHUNIT_RUNNER_TYPE_OUT.
# Arguments: $1 subshell_output
function bashunit::runner::extract_subshell_type() {
  local subshell_output=$1
  local type="${subshell_output%%]*}"
  _BASHUNIT_RUNNER_TYPE_OUT="${type#[}"
}

# Writes the subshell output (minus the leading [type] marker, with embedded
# status markers replaced by newlines) into _BASHUNIT_RUNNER_OUTPUT_OUT.
# Arguments: $1 subshell_output
function bashunit::runner::format_subshell_output() {
  local subshell_output=$1
  local line="${subshell_output#*]}"
  line=${line//\[failed\]/$'\n'}
  line=${line//\[skipped\]/$'\n'}
  line=${line//\[incomplete\]/$'\n'}
  _BASHUNIT_RUNNER_OUTPUT_OUT=$line
}

##
# Appends a profiling record (duration, test name, file) to PROFILE_OUTPUT_PATH.
# Uses a tab-separated, append-only line so it aggregates correctly across the
# subshells spawned by parallel runs.
# Arguments: $1 duration (ms), $2 test name, $3 test file
##
function bashunit::runner::record_profile() {
  local duration=$1
  local test_name=$2
  local test_file=$3
  printf '%s\t%s\t%s\n' "$duration" "$test_name" "$test_file" >>"$PROFILE_OUTPUT_PATH"
}

# Writes the detected runtime-error message (empty when none) into
# _BASHUNIT_RUNNER_RUNTIME_ERROR_OUT. Return-slot form avoids a per-test fork
# on the hot path (#764).
# Arguments: $1 runtime_output
function bashunit::runner::detect_runtime_error() {
  local runtime_output=$1
  _BASHUNIT_RUNNER_RUNTIME_ERROR_OUT=""
  case "$runtime_output" in
  *"command not found"* | *"unbound variable"* | *"permission denied"* | \
    *"no such file or directory"* | *"syntax error"* | *"bad substitution"* | \
    *"division by 0"* | *"cannot allocate memory"* | *"bad file descriptor"* | \
    *"segmentation fault"* | *"illegal option"* | *"argument list too long"* | \
    *"readonly variable"* | *"missing keyword"* | *"killed"* | \
    *"cannot execute binary file"* | *"invalid arithmetic operator"* | \
    *"ambiguous redirect"* | *"integer expression expected"* | \
    *"too many arguments"* | *"value too great"* | \
    *"not a valid identifier"* | *"unexpected EOF"*)
    local runtime_error="${runtime_output#*: }"
    _BASHUNIT_RUNNER_RUNTIME_ERROR_OUT="${runtime_error//$'\n'/}"
    ;;
  esac
}

##
# Maps a process exit code to a human-readable description when it indicates the
# test was killed by a signal (128 + signal) or timed out. Returns an empty
# string for ordinary exit codes. Bash 3.0+ compatible.
# Arguments: $1 exit code
##
function bashunit::runner::classify_kill_signal() {
  local code=$1

  case "$code" in
  124) printf 'Timed out (killed by `timeout`)' ;;
  130) printf 'Interrupted (SIGINT)' ;;
  137) printf 'Killed (SIGKILL — out of memory or forced termination)' ;;
  143) printf 'Terminated (SIGTERM — e.g. a timeout)' ;;
  *)
    # Generic "killed by signal N" for other 128+N codes (signals 1..64)
    case "$code" in
    '' | *[!0-9]*) return 0 ;;
    esac
    if [ "$code" -gt 128 ] && [ "$code" -le 192 ]; then
      printf 'Killed by signal %s' "$((code - 128))"
    fi
    ;;
  esac
}

function bashunit::runner::print_verbose_test_summary() {
  local test_file=$1
  local fn_name=$2
  local duration=$3
  local test_execution_result=$4

  if bashunit::env::is_simple_output_enabled; then
    echo ""
  fi

  printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '='
  printf "%s\n" "File:     $test_file"
  printf "%s\n" "Function: $fn_name"
  printf "%s\n" "Duration: $duration ms"
  local raw_text=${test_execution_result%%##ASSERTIONS_*}
  [ -n "$raw_text" ] && printf "%s" "Raw text: $raw_text"
  printf "%s\n" "##ASSERTIONS_${test_execution_result#*##ASSERTIONS_}"
  printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '-'
}

# Returns 0 when this Bash supports `wait -n` (Bash 4.3+), 1 otherwise.
function bashunit::runner::_supports_wait_n() {
  local major="${BASH_VERSINFO[0]:-0}"
  local minor="${BASH_VERSINFO[1]:-0}"
  if [ "$major" -gt 4 ]; then
    return 0
  fi
  if [ "$major" -eq 4 ] && [ "$minor" -ge 3 ]; then
    return 0
  fi
  return 1
}

_BASHUNIT_RUNNER_RUNNING_JOBS_OUT=0

# Counts running background jobs into _BASHUNIT_RUNNER_RUNNING_JOBS_OUT. `jobs -pr`
# still needs one command substitution, but the line count is pure-bash, so this
# drops the extra `wc` fork per poll iteration on the parallel hot path (#761).
function bashunit::runner::_count_running_jobs() {
  local running
  running=$(jobs -pr)
  if [ -z "$running" ]; then
    _BASHUNIT_RUNNER_RUNNING_JOBS_OUT=0
    return
  fi
  local newlines="${running//[!$'\n']/}"
  _BASHUNIT_RUNNER_RUNNING_JOBS_OUT=$((${#newlines} + 1))
}

function bashunit::runner::wait_for_job_slot() {
  local max_jobs="${BASHUNIT_PARALLEL_JOBS:-0}"
  if [ "$max_jobs" -le 0 ]; then
    return 0
  fi

  if bashunit::runner::_supports_wait_n; then
    # Bash 4.3+: block until any child exits. No polling, no sleep latency.
    bashunit::runner::_count_running_jobs
    while [ "$_BASHUNIT_RUNNER_RUNNING_JOBS_OUT" -ge "$max_jobs" ]; do
      wait -n 2>/dev/null || break
      bashunit::runner::_count_running_jobs
    done
    return 0
  fi

  # Bash 3.x fallback: adaptive poll starting at 50ms, growing to 200ms to
  # reduce `jobs -r` overhead on long-running tests while staying responsive.
  local delay="0.05"
  local iterations=0
  while true; do
    bashunit::runner::_count_running_jobs
    if [ "$_BASHUNIT_RUNNER_RUNNING_JOBS_OUT" -lt "$max_jobs" ]; then
      break
    fi
    sleep "$delay"
    iterations=$((iterations + 1))
    if [ "$iterations" -eq 4 ]; then
      delay="0.1"
    elif [ "$iterations" -eq 20 ]; then
      delay="0.2"
    fi
  done
}

function bashunit::runner::load_test_files() {
  local filter=$1
  local tag_filter="${2:-}"
  local exclude_tag_filter="${3:-}"
  shift 3
  local IFS=$' \t\n'
  local -a files
  files=("$@")
  local -a scripts_ids=()
  local scripts_ids_count=0

  # Randomize file execution order (deterministic for the resolved seed).
  if bashunit::env::is_random_order_enabled; then
    local -a _shuffled_files=()
    local _sf
    while IFS= read -r _sf; do
      [ -n "$_sf" ] && _shuffled_files[${#_shuffled_files[@]}]=$_sf
    done < <(printf '%s\n' "${files[@]+"${files[@]}"}" | bashunit::math::shuffle "$(bashunit::env::seed)")
    files=("${_shuffled_files[@]+"${_shuffled_files[@]}"}")
  fi

  bashunit::runner::sync_coverage_flag

  # Initialize coverage tracking if enabled
  if [ "$_BASHUNIT_COVERAGE_ON" = 1 ]; then
    # Auto-discover coverage paths if not explicitly set
    if [ -z "$BASHUNIT_COVERAGE_PATHS" ]; then
      BASHUNIT_COVERAGE_PATHS=$(bashunit::coverage::auto_discover_paths "${files[@]}")
      # Fallback: if auto-discovery yields no paths, track the src/ folder
      if [ -z "$BASHUNIT_COVERAGE_PATHS" ]; then
        BASHUNIT_COVERAGE_PATHS="src/"
      fi
    fi
    bashunit::coverage::init
  fi

  local test_file
  for test_file in "${files[@]+"${files[@]}"}"; do
    if [ ! -f "$test_file" ]; then
      continue
    fi
    unset BASHUNIT_CURRENT_TEST_ID
    bashunit::helper::generate_id "${test_file}"
    export BASHUNIT_CURRENT_SCRIPT_ID="$_BASHUNIT_HELPER_ID_OUT"
    scripts_ids[scripts_ids_count]="${BASHUNIT_CURRENT_SCRIPT_ID}"
    scripts_ids_count=$((scripts_ids_count + 1))
    bashunit::internal_log "Loading file" "$test_file"
    local source_err_file source_err source_status
    source_err_file="$(bashunit::temp_file "source_err")"
    # shellcheck source=/dev/null
    source "$test_file" 2>"$source_err_file"
    source_status=$?
    source_err=""
    if [ -s "$source_err_file" ]; then
      source_err="$(cat "$source_err_file")"
    fi
    rm -f "$source_err_file"
    if [ "$source_status" -ne 0 ] || [ "$(printf '%s' "$source_err" |
      "$GREP" -cE 'syntax error|unexpected EOF' || true)" -gt 0 ]; then
      local message="$source_err"
      [ -z "$message" ] && message="Failed to source '$test_file' (exit $source_status)"
      bashunit::runner::record_file_hook_failure \
        "source" "$test_file" "$message" 1 true
      bashunit::runner::clean_set_up_and_tear_down_after_script
      bashunit::runner::restore_workdir
      continue
    fi
    # Update function cache after sourcing new test file
    _BASHUNIT_CACHED_ALL_FUNCTIONS=$(declare -F | awk '{print $3}')
    # Check if any tests match the filter before rendering header or running hooks
    local filtered_functions
    filtered_functions=$(bashunit::helper::get_functions_to_run "test" "$filter" "$_BASHUNIT_CACHED_ALL_FUNCTIONS")
    local functions_for_script
    functions_for_script=$(bashunit::runner::functions_for_script "$test_file" "$filtered_functions")
    # Apply tag filtering to the early check as well
    if [ -n "$tag_filter" ] || [ -n "$exclude_tag_filter" ]; then
      bashunit::helper::build_tags_map "$test_file"
      local _early_filtered=""
      local _early_fn
      for _early_fn in $functions_for_script; do
        bashunit::helper::tags_for_function "$_early_fn"
        if bashunit::helper::function_matches_tags "$_BASHUNIT_TAGS_OUT" "$tag_filter" "$exclude_tag_filter"; then
          _early_filtered="$_early_filtered $_early_fn"
        fi
      done
      functions_for_script="${_early_filtered# }"
    fi
    # Replay filtering: keep only the functions recorded as failing last run.
    if bashunit::rerun::is_enabled && bashunit::rerun::has_entries; then
      functions_for_script=$(bashunit::rerun::filter_functions "$test_file" "$functions_for_script")
    fi
    if [ -z "$functions_for_script" ]; then
      bashunit::runner::clean_set_up_and_tear_down_after_script
      bashunit::runner::restore_workdir
      continue
    fi
    # Render header BEFORE set_up_before_script so user sees activity immediately
    bashunit::runner::render_running_file_header "$test_file"
    # Call hook directly (not with `if !`) to preserve errexit behavior inside the hook
    bashunit::runner::run_set_up_before_script "$test_file"
    local setup_before_script_status=$?
    if [ $setup_before_script_status -ne 0 ]; then
      # Count the test functions that couldn't run due to set_up_before_script failure
      # and add them as failed (minus 1 since the hook failure already counts as 1)
      local filtered_functions
      filtered_functions=$(bashunit::helper::get_functions_to_run "test" "$filter" "$_BASHUNIT_CACHED_ALL_FUNCTIONS")
      if [ -n "$filtered_functions" ]; then
        # Bash 3.0 compatible: separate declaration and assignment for arrays
        local functions_to_run
        # shellcheck disable=SC2206
        functions_to_run=($filtered_functions)
        local additional_failures=$((${#functions_to_run[@]} - 1))
        local i
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
    local _cached_fns="$functions_for_script"
    if bashunit::parallel::is_enabled; then
      bashunit::runner::wait_for_job_slot
      bashunit::runner::call_test_functions \
        "$test_file" "$filter" "$tag_filter" \
        "$exclude_tag_filter" "$_cached_fns" 2>/dev/null &
    else
      bashunit::runner::call_test_functions \
        "$test_file" "$filter" "$tag_filter" \
        "$exclude_tag_filter" "$_cached_fns"
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
    disown "$spinner_pid" 2>/dev/null || true
    kill "$spinner_pid" 2>/dev/null || true
    printf "\r  \r" # Clear the spinner output
    local script_id
    for script_id in "${scripts_ids[@]+"${scripts_ids[@]}"}"; do
      export BASHUNIT_CURRENT_SCRIPT_ID="${script_id}"
      bashunit::cleanup_script_temp_files
    done
  fi
}

function bashunit::runner::load_bench_files() {
  local filter=$1
  shift
  local IFS=$' \t\n'
  local -a files
  files=("$@")

  local bench_file
  for bench_file in "${files[@]+"${files[@]}"}"; do
    [ -f "$bench_file" ] || continue
    unset BASHUNIT_CURRENT_TEST_ID
    bashunit::helper::generate_id "${bench_file}"
    export BASHUNIT_CURRENT_SCRIPT_ID="$_BASHUNIT_HELPER_ID_OUT"
    # shellcheck source=/dev/null
    source "$bench_file"
    # Update function cache after sourcing new bench file
    _BASHUNIT_CACHED_ALL_FUNCTIONS=$(declare -F | awk '{print $3}')
    # Call hook directly (not with `if !`) to preserve errexit behavior inside the hook
    bashunit::runner::run_set_up_before_script "$bench_file"
    local setup_before_script_status=$?
    if [ $setup_before_script_status -ne 0 ]; then
      # Count the bench functions that couldn't run due to set_up_before_script failure
      # and add them as failed (minus 1 since the hook failure already counts as 1)
      local filtered_functions
      filtered_functions=$(bashunit::helper::get_functions_to_run "bench" "$filter" "$_BASHUNIT_CACHED_ALL_FUNCTIONS")
      if [ -n "$filtered_functions" ]; then
        # Bash 3.0 compatible: separate declaration and assignment for arrays
        local functions_to_run
        # shellcheck disable=SC2206
        functions_to_run=($filtered_functions)
        local additional_failures=$((${#functions_to_run[@]} - 1))
        local i
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
  if [ ! -t 1 ]; then
    # Not a terminal, just wait silently
    while true; do sleep 1; done
    return
  fi

  # Don't show spinner in no-progress mode
  if bashunit::env::is_no_progress_enabled; then
    while true; do sleep 1; done
    return
  fi

  if bashunit::env::is_simple_output_enabled; then
    printf "\n"
  fi

  local delay=0.1
  local spin_chars="|/-\\"
  while true; do
    local i
    for ((i = 0; i < ${#spin_chars}; i++)); do
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
  local had_quotes=false # Track if arg was quoted (to preserve empty quoted strings)
  local quote_char=""
  local escaped=false
  local IFS=$' \t\n'
  local i=0
  local arg=""
  local encoded_arg
  local -a args=()
  local args_count=0

  # Check for unescaped shell metacharacters that would break eval or cause
  # globbing. Combines the leading-metachar case and the embedded-metachar
  # case into a single regex to avoid a second grep subprocess per call.
  local has_metachar=false
  if [ "$(echo "$input" | "$GREP" -cE '(^|[^\])[|&;*]' || true)" -gt 0 ]; then
    has_metachar=true
  fi

  # Try eval first (needed for $'...' from printf '%q'), unless metacharacters present
  if [ "$has_metachar" = false ] && eval "args=($input)" 2>/dev/null; then
    # Check if args has elements after eval
    args_count=0
    local _tmp arg
    for _tmp in ${args+"${args[@]}"}; do args_count=$((args_count + 1)); done
    if [ "$args_count" -gt 0 ]; then
      # Successfully parsed - remove sentinel if present
      local last_idx=$((args_count - 1))
      if [ -z "${args[$last_idx]}" ]; then
        unset 'args[$last_idx]'
      fi
      # Print args and return early
      for arg in "${args[@]+"${args[@]}"}"; do
        encoded_arg="$(bashunit::helper::encode_base64 "${arg}")"
        printf '%s\n' "$encoded_arg"
      done
      return
    fi
  fi

  # Fallback: parse args from the input string into an array, respecting quotes and escapes
  local i
  for ((i = 0; i < ${#input}; i++)); do
    local char="${input:$i:1}"
    if [ "$escaped" = true ]; then
      case "$char" in
      t) current_arg="$current_arg"$'\t' ;;
      n) current_arg="$current_arg"$'\n' ;;
      *) current_arg="$current_arg$char" ;;
      esac
      escaped=false
    elif [ "$char" = "\\" ]; then
      escaped=true
    elif [ "$in_quotes" = false ]; then
      case "$char" in
      "$")
        # Handle $'...' syntax
        if [ "${input:$i:2}" = "$'" ]; then
          in_quotes=true
          had_quotes=true
          quote_char="'"
          # Skip the $
          i=$((i + 1))
        else
          current_arg="$current_arg$char"
        fi
        ;;
      "'" | '"')
        in_quotes=true
        had_quotes=true
        quote_char="$char"
        ;;
      " " | $'\t')
        # Add if non-empty OR if was quoted (to preserve empty quoted strings like '')
        if [ -n "$current_arg" ] || [ "$had_quotes" = true ]; then
          args[args_count]="$current_arg"
          args_count=$((args_count + 1))
        fi
        current_arg=""
        had_quotes=false
        ;;
      *)
        current_arg="$current_arg$char"
        ;;
      esac
    elif [ "$char" = "$quote_char" ]; then
      in_quotes=false
      quote_char=""
    else
      current_arg="$current_arg$char"
    fi
  done
  args[args_count]="$current_arg"
  args_count=$((args_count + 1))
  # Remove all trailing empty strings
  while [ "$args_count" -gt 0 ]; do
    local last_idx=$((args_count - 1))
    if [ -z "${args[$last_idx]}" ]; then
      unset 'args[$last_idx]'
      args_count=$((args_count - 1))
    else
      break
    fi
  done
  # Print one arg per line to stdout, base64-encoded to preserve newlines in the data
  local arg
  for arg in ${args+"${args[@]}"}; do
    encoded_arg="$(bashunit::helper::encode_base64 "${arg}")"
    printf '%s\n' "$encoded_arg"
  done
}

function bashunit::runner::call_test_functions() {
  local script="$1"
  local filter="$2"
  local tag_filter="${3:-}"
  local exclude_tag_filter="${4:-}"
  local cached_functions="${5:-}"
  local IFS=$' \t\n'
  local -a functions_to_run=()
  local functions_to_run_count=0

  if [ -n "$cached_functions" ]; then
    # Use pre-computed function list from load_test_files (already tag-filtered)
    local _fn
    for _fn in $cached_functions; do
      [ -z "$_fn" ] && continue
      functions_to_run[functions_to_run_count]="$_fn"
      functions_to_run_count=$((functions_to_run_count + 1))
    done
  else
    # Fallback: compute function list (for direct calls without cache)
    local prefix="test"
    local filtered_functions
    filtered_functions=$(bashunit::helper::get_functions_to_run \
      "$prefix" "$filter" "$_BASHUNIT_CACHED_ALL_FUNCTIONS")
    local _fn
    while IFS= read -r _fn; do
      [ -z "$_fn" ] && continue
      functions_to_run[functions_to_run_count]="$_fn"
      functions_to_run_count=$((functions_to_run_count + 1))
    done < <(bashunit::runner::functions_for_script "$script" "$filtered_functions")

    # Apply tag filtering if --tag or --exclude-tag was specified
    if [ -n "$tag_filter" ] || [ -n "$exclude_tag_filter" ]; then
      bashunit::helper::build_tags_map "$script"
      local -a tag_filtered=()
      local tag_filtered_count=0
      local _tf_fn
      for _tf_fn in "${functions_to_run[@]+"${functions_to_run[@]}"}"; do
        bashunit::helper::tags_for_function "$_tf_fn"
        if bashunit::helper::function_matches_tags "$_BASHUNIT_TAGS_OUT" "$tag_filter" "$exclude_tag_filter"; then
          tag_filtered[tag_filtered_count]="$_tf_fn"
          tag_filtered_count=$((tag_filtered_count + 1))
        fi
      done
      functions_to_run=("${tag_filtered[@]+"${tag_filtered[@]}"}")
      functions_to_run_count=$tag_filtered_count
    fi
  fi

  # Randomize function order within this file. The seed is mixed with a stable
  # per-file value (cksum of the path) so different files get different orders
  # while staying reproducible for the resolved seed.
  if bashunit::env::is_random_order_enabled && [ "$functions_to_run_count" -gt 1 ]; then
    local _base _crc _fn_seed
    _base=$(bashunit::env::seed)
    _crc=$(printf '%s' "$script" | cksum | cut -d' ' -f1)
    _fn_seed=$(((_base + _crc) & 2147483647))
    local -a _shuffled_fns=()
    local _sfn
    while IFS= read -r _sfn; do
      [ -n "$_sfn" ] && _shuffled_fns[${#_shuffled_fns[@]}]=$_sfn
    done < <(printf '%s\n' "${functions_to_run[@]+"${functions_to_run[@]}"}" | bashunit::math::shuffle "$_fn_seed")
    functions_to_run=("${_shuffled_fns[@]+"${_shuffled_fns[@]}"}")
    functions_to_run_count=${#functions_to_run[@]}
  fi

  if [ "$functions_to_run_count" -le 0 ]; then
    return
  fi

  bashunit::helper::check_duplicate_functions "$script" || true

  local -a provider_data=()
  local provider_data_count=0
  local -a parsed_data=()
  local parsed_data_count=0

  # Scan the file once; per-test provider lookups below are pure-bash (#763).
  # The same pass also detects the no-parallel-tests opt-out (#774).
  bashunit::helper::build_provider_map "$script"

  local allow_test_parallel=true
  if [ "$_BASHUNIT_PROVIDER_MAP_NO_PARALLEL" = true ]; then
    allow_test_parallel=false
  fi

  for fn_name in "${functions_to_run[@]+"${functions_to_run[@]}"}"; do
    if bashunit::parallel::is_enabled && bashunit::parallel::must_stop_on_failure; then
      break
    fi

    # No data provider found: run once without forking to capture provider output.
    bashunit::helper::provider_for_function "$fn_name"
    if [ -z "$_BASHUNIT_PROVIDER_FN_OUT" ]; then
      if bashunit::parallel::is_enabled && [ "$allow_test_parallel" = true ]; then
        bashunit::runner::wait_for_job_slot
        bashunit::runner::run_test "$script" "$fn_name" &
      else
        bashunit::runner::run_test "$script" "$fn_name"
      fi
      unset -v fn_name
      continue
    fi

    provider_data=()
    provider_data_count=0
    local line
    while IFS=" " read -r line; do
      [ -z "$line" ] && continue
      provider_data[provider_data_count]="$line"
      provider_data_count=$((provider_data_count + 1))
    done <<<"$(bashunit::helper::execute_function_if_exists "$_BASHUNIT_PROVIDER_FN_OUT")"

    # Execute the test function for each line of data
    local data
    for data in "${provider_data[@]+"${provider_data[@]}"}"; do
      parsed_data=()
      parsed_data_count=0
      local line
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        parsed_data[parsed_data_count]="$(bashunit::helper::decode_base64 "${line}")"
        parsed_data_count=$((parsed_data_count + 1))
      done <<<"$(bashunit::runner::parse_data_provider_args "$data")"
      if bashunit::parallel::is_enabled && [ "$allow_test_parallel" = true ]; then
        bashunit::runner::wait_for_job_slot
        bashunit::runner::run_test "$script" "$fn_name" ${parsed_data+"${parsed_data[@]}"} &
      else
        bashunit::runner::run_test "$script" "$fn_name" ${parsed_data+"${parsed_data[@]}"}
      fi
    done
    unset -v fn_name
  done

  # Wait for all parallel tests within this file to complete
  if bashunit::parallel::is_enabled && [ "$allow_test_parallel" = true ]; then
    wait
  fi
}

function bashunit::runner::call_bench_functions() {
  local script="$1"
  local filter="$2"
  local IFS=$' \t\n'
  local prefix="bench"

  # Use cached function names for better performance
  local filtered_functions
  filtered_functions=$(bashunit::helper::get_functions_to_run \
    "$prefix" "$filter" "$_BASHUNIT_CACHED_ALL_FUNCTIONS")
  local -a functions_to_run=()
  local functions_to_run_count=0
  local _fn
  while IFS= read -r _fn; do
    [ -z "$_fn" ] && continue
    functions_to_run[functions_to_run_count]="$_fn"
    functions_to_run_count=$((functions_to_run_count + 1))
  done < <(bashunit::runner::functions_for_script "$script" "$filtered_functions")

  if [ "$functions_to_run_count" -le 0 ]; then
    return
  fi

  if bashunit::env::is_bench_mode_enabled; then
    bashunit::runner::render_running_file_header "$script"
  fi

  local fn_name
  for fn_name in "${functions_to_run[@]+"${functions_to_run[@]}"}"; do
    read -r revs its max_ms <<<"$(bashunit::benchmark::parse_annotations "$fn_name" "$script")"
    bashunit::benchmark::run_function "$fn_name" "$revs" "$its" "$max_ms"
    unset -v fn_name
  done

  if ! bashunit::env::is_simple_output_enabled; then
    echo ""
  fi
}

function bashunit::runner::render_running_file_header() {
  local script="$1"
  local force="${2:-false}"

  bashunit::internal_log "Running file" "$script"

  if [ "$force" != true ] && bashunit::parallel::is_enabled; then
    return
  fi

  # Suppress file headers in failures-only mode
  if bashunit::env::is_failures_only_enabled; then
    return
  fi

  # Suppress file headers in no-progress mode
  if bashunit::env::is_no_progress_enabled; then
    return
  fi

  if bashunit::env::is_tap_output_enabled; then
    printf "# %s\n" "$script"
  elif ! bashunit::env::is_simple_output_enabled; then
    if bashunit::env::is_verbose_enabled; then
      printf "\n${_BASHUNIT_COLOR_BOLD}%s${_BASHUNIT_COLOR_DEFAULT}\n" "Running $script"
    else
      printf "${_BASHUNIT_COLOR_BOLD}%s${_BASHUNIT_COLOR_DEFAULT}\n" "Running $script"
    fi
  elif bashunit::env::is_verbose_enabled; then
    printf "\n\n${_BASHUNIT_COLOR_BOLD}%s${_BASHUNIT_COLOR_DEFAULT}" "Running $script"
  fi
}

# Result slots for the timeout-aware execution path (see run_with_timeout).
_BASHUNIT_RUNNER_EXEC_OUT=""
_BASHUNIT_RUNNER_TIMED_OUT="false"

##
# Runs a single test inside the capture subshell: sets up the EXIT trap that
# encodes assertion counts/exit code, runs set_up, applies the shell mode and
# finally invokes the test function. Meant to be called from a subshell (either
# the `$(...)` capture or a backgrounded job), so its `set`/`trap`/`exit` calls
# stay isolated. Emits the test stdout (with stderr merged) followed by the
# encoded context from cleanup_on_exit.
# Arguments: $1 test file, $2 function name, $@ test args
##
function bashunit::runner::execute_test_body() {
  local test_file=$1
  shift
  local fn_name=$1
  shift

  # Save subshell stdout to FD 5 so the EXIT trap can restore it.
  # When set -e kills the subshell during a redirected block in
  # execute_test_hook, the redirect leaks into the EXIT trap,
  # causing export_subshell_context output to be lost.
  exec 5>&1
  # shellcheck disable=SC2064
  trap "exit_code=\$?; bashunit::runner::cleanup_on_exit \"$test_file\" \"\$exit_code\"" EXIT
  bashunit::state::initialize_assertions_count

  if bashunit::env::is_login_shell_enabled; then
    bashunit::runner::source_login_shell_profiles
  fi

  # Enable coverage tracking early to include set_up/tear_down hooks
  if [ "${_BASHUNIT_COVERAGE_ON:-0}" = 1 ]; then
    bashunit::coverage::enable_trap
  fi

  # Run set_up and capture exit code without || to preserve errexit behavior
  # shellcheck disable=SC2030
  _BASHUNIT_SETUP_COMPLETED=false
  local setup_exit_code=0
  bashunit::runner::run_set_up "$test_file"
  setup_exit_code=$?
  _BASHUNIT_SETUP_COMPLETED=true
  if [ $setup_exit_code -ne 0 ]; then
    exit $setup_exit_code
  fi

  # Apply shell mode setting for test execution
  if bashunit::env::is_strict_mode_enabled; then
    set -eu
    # Bash 3.0 ships a broken pipefail; only enable it where it is reliable.
    if bashunit::runner::_supports_reliable_pipefail; then
      set -o pipefail
    else
      set +o pipefail
    fi
  else
    set +euo pipefail
  fi

  # 2>&1: Redirects the std-error (FD 2) to the std-output (FD 1).
  # points to the original std-output.
  "$fn_name" "$@" 2>&1
}

##
# Prints an encoded subshell result for a test that timed out: empty assertion
# counters and exit code 124 (the conventional "timed out" code, already mapped
# by classify_kill_signal). The empty TEST_HOOK_MESSAGE/TITLE/OUTPUT fields would
# base64-encode to an empty string anyway, so the line is emitted directly rather
# than mutating the shared _BASHUNIT_* globals (it mirrors the layout produced by
# bashunit::state::export_subshell_context). Bash 3.0+ compatible.
##
function bashunit::runner::build_timeout_result() {
  printf '%s' "##ASSERTIONS_FAILED=0##ASSERTIONS_PASSED=0##ASSERTIONS_SKIPPED=0\
##ASSERTIONS_INCOMPLETE=0##ASSERTIONS_SNAPSHOT=0##TEST_EXIT_CODE=124\
##TEST_HOOK_FAILURE=##TEST_HOOK_MESSAGE=##TEST_TITLE=##TEST_OUTPUT=##"
}

##
# Runs the test body with a watchdog that kills it after BASHUNIT_TEST_TIMEOUT
# seconds. The body runs as a backgrounded job in its own process group (set -m)
# so the watchdog can SIGTERM/SIGKILL the whole tree — a hanging test usually
# blocks in a child process, which signalling the subshell alone cannot reach.
# Writes the captured result to _BASHUNIT_RUNNER_EXEC_OUT and "true"/"false" to
# _BASHUNIT_RUNNER_TIMED_OUT. Bash 3.0+ compatible (validated on Bash 3.2).
# Arguments: $1 test file, $2 function name, $@ test args
##
function bashunit::runner::run_with_timeout() {
  local test_file=$1
  shift
  local fn_name=$1
  shift
  local secs
  secs=$(bashunit::env::test_timeout_secs)

  # NOTE: these must NOT use bashunit::temp_file — that prefixes the current
  # test id, and cleanup_on_exit (run inside the test subshell) would unlink
  # them via cleanup_testcase_temp_files before we read them back here.
  local tmp_dir="${BASHUNIT_TEMP_DIR:-${TMPDIR:-/tmp}}"
  local out_file marker_file
  out_file="$("$MKTEMP" "$tmp_dir/bashunit_timeout_out.XXXXXXX")"
  marker_file="$("$MKTEMP" "$tmp_dir/bashunit_timeout_marker.XXXXXXX")"
  rm -f "$marker_file"

  # Both jobs run in their own process group (set -m) so each can be killed as a
  # whole tree. The body MUST run in an explicit ( ) subshell: a backgrounded { }
  # group does not run its EXIT trap on normal completion, which would drop the
  # encoded assertion context. The watchdog's fds are detached from the caller so
  # a lingering `sleep` can never hold a captured stdout pipe open.
  set -m
  (bashunit::runner::execute_test_body "$test_file" "$fn_name" "$@") >"$out_file" 2>&1 &
  local test_pid=$!
  (
    sleep "$secs"
    # Only a still-running test can have timed out. Without this guard a watchdog
    # that outlived a missed teardown (see below) would mark an already-finished
    # fast test as timed out.
    kill -0 "$test_pid" 2>/dev/null || exit 0
    : >"$marker_file"
    kill -TERM -"$test_pid" 2>/dev/null
    sleep 0.3
    kill -KILL -"$test_pid" 2>/dev/null
  ) </dev/null >/dev/null 2>&1 &
  local watchdog_pid=$!
  set +m

  wait "$test_pid" 2>/dev/null
  # Stop the watchdog by its pid AND its group. `set -m` does not reliably make a
  # backgrounded subshell a group leader in a non-interactive shell, so the
  # group-only kill intermittently misses, letting the watchdog sleep its full
  # timeout and fire against a test that already passed. The direct-pid signal is
  # always deliverable; the group signal also reaps the `sleep` child.
  kill -TERM "$watchdog_pid" 2>/dev/null
  kill -TERM -"$watchdog_pid" 2>/dev/null
  wait "$watchdog_pid" 2>/dev/null

  if [ -f "$marker_file" ]; then
    _BASHUNIT_RUNNER_TIMED_OUT="true"
    _BASHUNIT_RUNNER_EXEC_OUT="$(bashunit::runner::build_timeout_result)"
  else
    _BASHUNIT_RUNNER_TIMED_OUT="false"
    _BASHUNIT_RUNNER_EXEC_OUT="$(cat "$out_file" 2>/dev/null)"
  fi

  rm -f "$out_file" "$marker_file"
}

# Per-test duration is consumed by --profile, --verbose, report files, and the
# execution-time display. When none are active we can skip the clock reads,
# which matters when the clock forks an interpreter (#765).
function bashunit::runner::needs_test_duration() {
  bashunit::env::is_profile_enabled && return 0
  bashunit::env::is_verbose_enabled && return 0
  bashunit::reports::is_enabled && return 0
  bashunit::env::is_show_execution_time_enabled && return 0
  return 1
}

function bashunit::runner::run_test() {
  local start_time=0

  local test_file="$1"
  shift
  local fn_name="$1"
  shift

  bashunit::internal_log "Running test" "$fn_name" "$*"
  bashunit::runner::export_test_identity "$test_file" "$fn_name"

  bashunit::state::reset_test_title
  bashunit::runner::apply_interpolated_title "$fn_name" "$@"
  local interpolated_fn_name=$_BASHUNIT_RUNNER_INTERP_OUT
  local current_assertions_failed="$_BASHUNIT_ASSERTIONS_FAILED"
  local current_assertions_snapshot="$_BASHUNIT_ASSERTIONS_SNAPSHOT"
  local current_assertions_incomplete="$_BASHUNIT_ASSERTIONS_INCOMPLETE"
  local current_assertions_skipped="$_BASHUNIT_ASSERTIONS_SKIPPED"

  # (FD = File Descriptor)
  # Duplicate the current std-output (FD 1) and assigns it to FD 3.
  # This means that FD 3 now points to wherever the std-output was pointing.
  exec 3>&1

  local test_execution_result
  local timed_out="false"
  bashunit::env::resolve_retry_count
  local retry_max=$_BASHUNIT_RETRY_VALIDATED
  local retries_used=0
  local measure_duration=false
  bashunit::runner::needs_test_duration && measure_duration=true
  # Retry wraps ONLY execution: a failed attempt is judged from its encoded
  # result without committing, so the parse/report/counter path below still runs
  # exactly once (on the final attempt) and nothing is double-counted. Each fork
  # in --parallel retries itself before writing its single .result file.
  while :; do
    if [ "$measure_duration" = true ]; then
      bashunit::clock::now_to_slot
      start_time=$_BASHUNIT_CLOCK_NOW_OUT
    fi
    if bashunit::env::is_test_timeout_enabled; then
      bashunit::runner::run_with_timeout "$test_file" "$fn_name" "$@"
      test_execution_result="$_BASHUNIT_RUNNER_EXEC_OUT"
      timed_out="$_BASHUNIT_RUNNER_TIMED_OUT"
    else
      test_execution_result=$(bashunit::runner::execute_test_body "$test_file" "$fn_name" "$@")
    fi

    local attempt_runtime_output="${test_execution_result%%##ASSERTIONS_*}"
    bashunit::runner::detect_runtime_error "$attempt_runtime_output"
    local attempt_runtime_error=$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT
    bashunit::runner::extract_result_counts "$test_execution_result"
    # Mirror the commit-phase failure test exactly (runtime error, non-zero exit,
    # or a failed assertion); snapshot/incomplete/skipped/risky are not failures.
    if [ -z "$attempt_runtime_error" ] &&
      [ "$_BASHUNIT_RUNNER_COUNTS_EXIT_CODE_OUT" -eq 0 ] &&
      [ "$_BASHUNIT_RUNNER_COUNTS_FAILED_OUT" -eq 0 ]; then
      break
    fi
    [ "$retries_used" -ge "$retry_max" ] && break
    retries_used=$((retries_used + 1))
  done

  # Closes FD 3, which was used temporarily to hold the original stdout.
  exec 3>&-

  local duration=0
  if [ "$measure_duration" = true ]; then
    bashunit::clock::now_to_slot
    local end_time=$_BASHUNIT_CLOCK_NOW_OUT
    duration=$(((end_time - start_time) / 1000000))
  fi

  if bashunit::env::is_profile_enabled; then
    bashunit::runner::record_profile "$duration" "$interpolated_fn_name" "$test_file"
  fi

  if bashunit::env::is_verbose_enabled; then
    bashunit::runner::print_verbose_test_summary \
      "$test_file" "$fn_name" "$duration" "$test_execution_result"
  fi

  bashunit::runner::decode_subshell_output "$test_execution_result"
  local subshell_output=$_BASHUNIT_RUNNER_SUBSHELL_OUTPUT_OUT

  if [ -n "$subshell_output" ]; then
    bashunit::runner::extract_subshell_type "$subshell_output"
    local type=$_BASHUNIT_RUNNER_TYPE_OUT
    bashunit::runner::format_subshell_output "$subshell_output"
    subshell_output=$_BASHUNIT_RUNNER_OUTPUT_OUT
    if ! bashunit::env::is_failures_only_enabled; then
      bashunit::state::print_line "$type" "$subshell_output"
    fi
  fi

  # Reuse the final attempt's values (the loop always runs at least once and
  # its locals persist in this function scope), instead of recomputing and
  # forking detect_runtime_error a second time (#764).
  local runtime_output=$attempt_runtime_output
  local runtime_error=$attempt_runtime_error

  # parse_result accumulates _BASHUNIT_TEST_EXIT_CODE; reset it so each test's
  # exit code is read in isolation (a non-zero/timed-out test must not poison
  # the next one).
  _BASHUNIT_TEST_EXIT_CODE=0
  bashunit::runner::parse_result "$fn_name" "$test_execution_result" "$@"

  local test_exit_code="$_BASHUNIT_TEST_EXIT_CODE"

  bashunit::runner::compute_total_assertions "$test_execution_result"
  local total_assertions=$_BASHUNIT_RUNNER_TOTAL_OUT

  bashunit::runner::extract_encoded_field "$test_execution_result" "TEST_TITLE"
  local encoded_test_title=$_BASHUNIT_RUNNER_FIELD_OUT
  bashunit::runner::extract_encoded_field "$test_execution_result" "TEST_HOOK_FAILURE"
  local hook_failure=$_BASHUNIT_RUNNER_FIELD_OUT
  bashunit::runner::extract_encoded_field "$test_execution_result" "TEST_HOOK_MESSAGE"
  local encoded_hook_message=$_BASHUNIT_RUNNER_FIELD_OUT

  local test_title=""
  [ -n "$encoded_test_title" ] && test_title="$(bashunit::helper::decode_base64 "$encoded_test_title")"
  local hook_message=""
  [ -n "$encoded_hook_message" ] && hook_message="$(bashunit::helper::decode_base64 "$encoded_hook_message")"

  bashunit::set_test_title "$test_title"
  bashunit::helper::normalize_test_function_name_to_slot "$fn_name" "$interpolated_fn_name"
  local label=$_BASHUNIT_HELPER_NORMALIZED_OUT
  bashunit::state::reset_test_title
  bashunit::state::reset_current_test_interpolated_function_name

  local failure_label="$label"
  local failure_function="$fn_name"
  if [ -n "$hook_failure" ]; then
    bashunit::helper::normalize_test_function_name_to_slot "$hook_failure"
    failure_label=$_BASHUNIT_HELPER_NORMALIZED_OUT
    failure_function="$hook_failure"
  fi

  if [ -n "$runtime_error" ] || [ "$test_exit_code" -ne 0 ]; then
    bashunit::state::add_tests_failed
    bashunit::rerun::record "$test_file" "$fn_name"
    local error_message="$runtime_error"
    if [ -n "$hook_failure" ] && [ -n "$hook_message" ]; then
      error_message="$hook_message"
    elif [ -z "$error_message" ] && [ -n "$hook_message" ]; then
      error_message="$hook_message"
    fi

    # When the test was killed by a signal (or timed out), replace an empty or
    # generic "Killed" message with a specific cause.
    if [ -z "$hook_failure" ]; then
      local kill_message
      kill_message=$(bashunit::runner::classify_kill_signal "$test_exit_code")
      if [ -n "$kill_message" ]; then
        case "$error_message" in
        '' | *[Kk]illed* | *[Tt]erminated*) error_message="$kill_message" ;;
        esac
      fi
    fi

    # A test that exceeded BASHUNIT_TEST_TIMEOUT gets a clear, specific message.
    if [ "$timed_out" = "true" ]; then
      error_message="Test timed out after $(bashunit::env::test_timeout_secs)s"
    fi

    bashunit::console_results::print_error_test "$failure_function" "$error_message" "$runtime_output"
    bashunit::reports::add_test_failed "$test_file" "$failure_label" "$duration" "$total_assertions" "$error_message"
    bashunit::runner::write_failure_result_output "$test_file" "$failure_function" "$error_message" "$runtime_output"
    bashunit::internal_log "Test error" "$failure_label" "$error_message"

    if bashunit::env::is_stop_on_failure_enabled; then
      if bashunit::parallel::is_enabled; then
        bashunit::parallel::mark_stop_on_failure
      else
        exit "$EXIT_CODE_STOP_ON_FAILURE"
      fi
    fi
    return
  fi

  if [ "$current_assertions_failed" != "$_BASHUNIT_ASSERTIONS_FAILED" ]; then
    bashunit::state::add_tests_failed
    bashunit::rerun::record "$test_file" "$fn_name"
    bashunit::reports::add_test_failed "$test_file" "$label" "$duration" "$total_assertions" "$subshell_output"
    local assertion_runtime_output
    assertion_runtime_output="$(
      bashunit::runner::extract_assertion_runtime_output "$runtime_output" "$subshell_output"
    )"
    bashunit::runner::write_failure_result_output \
      "$test_file" "$fn_name" "$subshell_output" "$assertion_runtime_output"

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

  if [ "$current_assertions_snapshot" != "$_BASHUNIT_ASSERTIONS_SNAPSHOT" ]; then
    bashunit::state::add_tests_snapshot
    # In failures-only mode, suppress snapshot test output
    if ! bashunit::env::is_failures_only_enabled; then
      bashunit::console_results::print_snapshot_test "$label"
    fi
    bashunit::reports::add_test_snapshot "$test_file" "$label" "$duration" "$total_assertions"
    bashunit::internal_log "Test snapshot" "$label"
    return
  fi

  if [ "$current_assertions_incomplete" != "$_BASHUNIT_ASSERTIONS_INCOMPLETE" ]; then
    bashunit::state::add_tests_incomplete
    bashunit::reports::add_test_incomplete "$test_file" "$label" "$duration" "$total_assertions"
    bashunit::runner::write_incomplete_result_output "$test_file" "$fn_name" "$subshell_output"
    bashunit::internal_log "Test incomplete" "$label"
    return
  fi

  if [ "$current_assertions_skipped" != "$_BASHUNIT_ASSERTIONS_SKIPPED" ]; then
    bashunit::state::add_tests_skipped
    bashunit::reports::add_test_skipped "$test_file" "$label" "$duration" "$total_assertions"
    bashunit::runner::write_skipped_result_output "$test_file" "$fn_name" "$subshell_output"
    bashunit::internal_log "Test skipped" "$label"
    return
  fi

  # Check for risky test (zero assertions)
  if [ "$total_assertions" -eq 0 ]; then
    if bashunit::env::is_fail_on_risky_enabled; then
      local risky_msg="Test has no assertions (risky)"
      bashunit::state::add_tests_failed
      bashunit::rerun::record "$test_file" "$fn_name"
      bashunit::console_results::print_error_test "$fn_name" "$risky_msg"
      bashunit::reports::add_test_failed "$test_file" "$label" "$duration" "$total_assertions" "$risky_msg"
      bashunit::runner::write_failure_result_output "$test_file" "$fn_name" "$risky_msg"
      bashunit::internal_log "Test failed (risky)" "$label"
      if bashunit::env::is_stop_on_failure_enabled; then
        if bashunit::parallel::is_enabled; then
          bashunit::parallel::mark_stop_on_failure
        else
          exit "$EXIT_CODE_STOP_ON_FAILURE"
        fi
      fi
      return
    fi
    bashunit::state::add_tests_risky
    if ! bashunit::env::is_failures_only_enabled; then
      bashunit::console_results::print_risky_test "${label}" "$duration"
    fi
    bashunit::reports::add_test_risky "$test_file" "$label" "$duration" "$total_assertions"
    bashunit::runner::write_risky_result_output "$test_file" "$fn_name"
    bashunit::internal_log "Test risky" "$label"
    return
  fi

  # A test that only passed after retrying is annotated so flakiness stays visible.
  _BASHUNIT_RETRY_NOTE=""
  if [ "$retries_used" -gt 0 ]; then
    _BASHUNIT_RETRY_NOTE=" (retry $retries_used/$retry_max)"
  fi
  # In failures-only mode, suppress successful test output
  if ! bashunit::env::is_failures_only_enabled; then
    if [ "$fn_name" = "$interpolated_fn_name" ]; then
      bashunit::console_results::print_successful_test "${label}" "$duration" "$@"
    else
      bashunit::console_results::print_successful_test "${label}" "$duration"
    fi
  fi
  _BASHUNIT_RETRY_NOTE=""
  bashunit::state::add_tests_passed
  bashunit::reports::add_test_passed "$test_file" "$label" "$duration" "$total_assertions"
  bashunit::internal_log "Test passed" "$label"
}

function bashunit::runner::cleanup_on_exit() {
  local test_file="$1"
  local exit_code="$2"

  # Disable coverage trap before cleanup to avoid interference
  if [ "${_BASHUNIT_COVERAGE_ON:-0}" = 1 ]; then
    bashunit::coverage::disable_trap
  fi

  set +e

  # Detect unexpected subshell exit during set_up (Issue #611).
  # When 'source' of a non-existent file fails under set -eE, the ERR trap
  # does not fire. On macOS Bash 3.2, $? is 0 in the EXIT trap; on Linux
  # Bash 5.x, $? is 1. In both cases the hook failure is not recorded.
  # Additionally, the stdout redirect from execute_test_hook leaks into the
  # EXIT trap. Restore stdout from saved FD 5 so export_subshell_context
  # output reaches test_execution_result.
  # shellcheck disable=SC2031
  if [ "${_BASHUNIT_SETUP_COMPLETED:-true}" != "true" ]; then
    exec 1>&5
    if [ "$exit_code" -eq 0 ]; then
      exit_code=1
    fi
    if [ -z "${_BASHUNIT_TEST_HOOK_FAILURE:-}" ]; then
      bashunit::state::set_test_hook_failure "set_up"
      bashunit::state::set_test_hook_message "Hook 'set_up' failed unexpectedly (e.g., source of non-existent file)"
    fi
  fi

  # Don't use || here - it disables ERR trap in the entire call chain
  bashunit::runner::run_tear_down "$test_file"
  local teardown_status=$?
  bashunit::runner::clear_mocks
  bashunit::cleanup_testcase_temp_files

  if [ $teardown_status -ne 0 ]; then
    bashunit::state::set_test_exit_code "$teardown_status"
  else
    bashunit::state::set_test_exit_code "$exit_code"
  fi

  bashunit::state::export_subshell_context
}

# Writes the decoded subshell output into _BASHUNIT_RUNNER_SUBSHELL_OUTPUT_OUT.
# The empty case (a passing test with no captured output) short-circuits with
# no subshell at all; only the non-empty path pays the base64 fork (#762/#764).
# Arguments: $1 test_execution_result
function bashunit::runner::decode_subshell_output() {
  local test_execution_result="$1"

  local test_output_base64="${test_execution_result##*##TEST_OUTPUT=}"
  test_output_base64="${test_output_base64%%##*}"
  if [ -z "$test_output_base64" ] || [ "$test_output_base64" = "_BASHUNIT_EMPTY_" ]; then
    _BASHUNIT_RUNNER_SUBSHELL_OUTPUT_OUT=""
    return
  fi
  _BASHUNIT_RUNNER_SUBSHELL_OUTPUT_OUT="$(bashunit::helper::decode_base64 "$test_output_base64")"
}

function bashunit::runner::is_simple_progress_output() {
  local output="$1"

  [ -n "$output" ] || return 1

  local color
  for color in \
    "$_BASHUNIT_COLOR_DEFAULT" \
    "$_BASHUNIT_COLOR_PASSED" \
    "$_BASHUNIT_COLOR_FAILED" \
    "$_BASHUNIT_COLOR_SKIPPED" \
    "$_BASHUNIT_COLOR_INCOMPLETE" \
    "$_BASHUNIT_COLOR_SNAPSHOT" \
    "$_BASHUNIT_COLOR_RISKY"; do
    [ -n "$color" ] && output="${output//"$color"/}"
  done

  local i
  local char
  for ((i = 0; i < ${#output}; i++)); do
    char="${output:$i:1}"
    case "$char" in
    "." | "F" | "S" | "I" | "N" | "R" | "E" | "?") ;;
    *) return 1 ;;
    esac
  done

  return 0
}

function bashunit::runner::line_exists_in_output() {
  local needle="$1"
  local haystack="$2"
  local line

  while IFS= read -r line || [ -n "$line" ]; do
    [ "$line" = "$needle" ] && return 0
  done <<<"$haystack"

  return 1
}

function bashunit::runner::extract_assertion_runtime_output() {
  local runtime_output="$1"
  local rendered_assertion_output="$2"
  local filtered_output=""
  local line

  while IFS= read -r line || [ -n "$line" ]; do
    if bashunit::runner::line_exists_in_output "$line" "$rendered_assertion_output"; then
      continue
    fi
    if bashunit::runner::is_simple_progress_output "$line"; then
      continue
    fi

    [ -n "$filtered_output" ] && filtered_output="$filtered_output"$'\n'
    filtered_output="$filtered_output$line"
  done <<<"$runtime_output"

  runtime_output="$filtered_output"

  while [ -n "$runtime_output" ]; do
    case "$runtime_output" in
    *$'\n') runtime_output="${runtime_output%$'\n'}" ;;
    *) break ;;
    esac
  done

  echo "$runtime_output"
}

function bashunit::runner::parse_result() {
  local fn_name=$1
  shift
  local execution_result=$1
  shift
  local IFS=$' \t\n'
  local -a args
  args=("$@")

  if bashunit::parallel::is_enabled; then
    bashunit::runner::parse_result_parallel "$fn_name" "$execution_result" ${args+"${args[@]}"}
  else
    bashunit::runner::parse_result_sync "$fn_name" "$execution_result"
  fi
}

function bashunit::runner::parse_result_parallel() {
  local fn_name=$1
  shift
  local execution_result=$1
  shift
  local IFS=$' \t\n'
  local -a args
  args=("$@")

  local test_suite_dir="${TEMP_DIR_PARALLEL_TEST_SUITE}/$(basename "$test_file" .sh)"
  mkdir -p "$test_suite_dir"

  local sanitized_args
  sanitized_args=$(echo "${args[*]+"${args[*]}"}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//')
  local template
  if [ -z "$sanitized_args" ]; then
    template="${fn_name}.XXXXXX"
  else
    template="${fn_name}-${sanitized_args}.XXXXXX"
  fi

  local unique_test_result_file
  if unique_test_result_file=$("$MKTEMP" -p "$test_suite_dir" "$template" 2>/dev/null); then
    true
  else
    unique_test_result_file=$("$MKTEMP" "$test_suite_dir/$template")
  fi
  mv "$unique_test_result_file" "${unique_test_result_file}.result"
  unique_test_result_file="${unique_test_result_file}.result"

  bashunit::internal_log "[PARA]" "fn_name:$fn_name" "execution_result:$execution_result"

  bashunit::runner::parse_result_sync "$fn_name" "$execution_result"

  echo "$execution_result" >"$unique_test_result_file"
}

# shellcheck disable=SC2295
##
# Parses the encoded per-test result's last line into the counts out-slots
# (_BASHUNIT_RUNNER_COUNTS_*_OUT). Pure read: never mutates the cumulative
# _BASHUNIT_ASSERTIONS_* / _BASHUNIT_TEST_EXIT_CODE state, so the retry loop can
# judge an attempt's outcome without committing it.
##
function bashunit::runner::extract_result_counts() {
  local execution_result=$1

  local result_line
  result_line="${execution_result##*$'\n'}"

  local assertions_failed=0
  local assertions_passed=0
  local assertions_skipped=0
  local assertions_incomplete=0
  local assertions_snapshot=0
  local test_exit_code=0

  # Extract values using parameter expansion instead of spawning grep/sed subprocesses
  case "$result_line" in
  *"ASSERTIONS_FAILED="*"##ASSERTIONS_PASSED="*)
    local _tail
    _tail="${result_line##*ASSERTIONS_FAILED=}"
    assertions_failed="${_tail%%##*}"
    _tail="${result_line##*ASSERTIONS_PASSED=}"
    assertions_passed="${_tail%%##*}"
    _tail="${result_line##*ASSERTIONS_SKIPPED=}"
    assertions_skipped="${_tail%%##*}"
    _tail="${result_line##*ASSERTIONS_INCOMPLETE=}"
    assertions_incomplete="${_tail%%##*}"
    _tail="${result_line##*ASSERTIONS_SNAPSHOT=}"
    assertions_snapshot="${_tail%%##*}"
    _tail="${result_line##*TEST_EXIT_CODE=}"
    test_exit_code="${_tail%%##*}"
    # Strip any trailing non-digit suffix (end of line) from the final field
    test_exit_code="${test_exit_code%%[!0-9]*}"
    : "${assertions_failed:=0}"
    : "${assertions_passed:=0}"
    : "${assertions_skipped:=0}"
    : "${assertions_incomplete:=0}"
    : "${assertions_snapshot:=0}"
    : "${test_exit_code:=0}"
    ;;
  esac

  _BASHUNIT_RUNNER_COUNTS_FAILED_OUT=$assertions_failed
  _BASHUNIT_RUNNER_COUNTS_PASSED_OUT=$assertions_passed
  _BASHUNIT_RUNNER_COUNTS_SKIPPED_OUT=$assertions_skipped
  _BASHUNIT_RUNNER_COUNTS_INCOMPLETE_OUT=$assertions_incomplete
  _BASHUNIT_RUNNER_COUNTS_SNAPSHOT_OUT=$assertions_snapshot
  _BASHUNIT_RUNNER_COUNTS_EXIT_CODE_OUT=$test_exit_code
}

function bashunit::runner::parse_result_sync() {
  local fn_name=$1
  local execution_result=$2

  bashunit::runner::extract_result_counts "$execution_result"

  bashunit::internal_log "[SYNC]" "fn_name:$fn_name" "execution_result:$execution_result"

  _BASHUNIT_ASSERTIONS_PASSED=$((_BASHUNIT_ASSERTIONS_PASSED + _BASHUNIT_RUNNER_COUNTS_PASSED_OUT))
  _BASHUNIT_ASSERTIONS_FAILED=$((_BASHUNIT_ASSERTIONS_FAILED + _BASHUNIT_RUNNER_COUNTS_FAILED_OUT))
  _BASHUNIT_ASSERTIONS_SKIPPED=$((_BASHUNIT_ASSERTIONS_SKIPPED + _BASHUNIT_RUNNER_COUNTS_SKIPPED_OUT))
  _BASHUNIT_ASSERTIONS_INCOMPLETE=$((_BASHUNIT_ASSERTIONS_INCOMPLETE + _BASHUNIT_RUNNER_COUNTS_INCOMPLETE_OUT))
  _BASHUNIT_ASSERTIONS_SNAPSHOT=$((_BASHUNIT_ASSERTIONS_SNAPSHOT + _BASHUNIT_RUNNER_COUNTS_SNAPSHOT_OUT))
  _BASHUNIT_TEST_EXIT_CODE=$((_BASHUNIT_TEST_EXIT_CODE + _BASHUNIT_RUNNER_COUNTS_EXIT_CODE_OUT))

  bashunit::internal_log "result_summary" \
    "failed:$_BASHUNIT_RUNNER_COUNTS_FAILED_OUT" \
    "passed:$_BASHUNIT_RUNNER_COUNTS_PASSED_OUT" \
    "skipped:$_BASHUNIT_RUNNER_COUNTS_SKIPPED_OUT" \
    "incomplete:$_BASHUNIT_RUNNER_COUNTS_INCOMPLETE_OUT" \
    "snapshot:$_BASHUNIT_RUNNER_COUNTS_SNAPSHOT_OUT" \
    "exit_code:$_BASHUNIT_RUNNER_COUNTS_EXIT_CODE_OUT"
}

function bashunit::runner::write_failure_result_output() {
  local test_file=$1
  local fn_name=$2
  local error_msg=$3
  local raw_output="${4:-}"

  local line_number
  line_number=$(bashunit::helper::get_function_line_number "$fn_name")

  local test_nr="*"
  if ! bashunit::parallel::is_enabled; then
    test_nr=$(bashunit::state::get_tests_failed)
  fi

  local output_section=""
  if [ -n "$raw_output" ] && bashunit::env::is_show_output_on_failure_enabled; then
    output_section="\n    Output:\n$raw_output"
  fi

  local source_context=""
  if [ -n "$line_number" ] && [ -f "$test_file" ]; then
    source_context=$(bashunit::runner::get_failure_source_context \
      "$test_file" "$line_number")
  fi

  echo -e "$test_nr) $test_file:$line_number\n$error_msg$output_section$source_context" \
    >>"$FAILURES_OUTPUT_PATH"
}

function bashunit::runner::get_failure_source_context() {
  local file=$1
  local fn_line=$2

  local end_line start_line
  end_line=$(wc -l <"$file")
  start_line=$((fn_line + 1))

  local line_text line_num assert_lines=""
  line_num=$start_line
  while [ "$line_num" -le "$end_line" ]; do
    line_text=$(sed -n "${line_num}p" "$file")
    # Stop at the closing brace of the function
    if [ "$(echo "$line_text" | "$GREP" -cE '^[[:space:]]*\}[[:space:]]*$' || true)" -gt 0 ]; then
      break
    fi
    # Collect lines containing assert calls
    case "$line_text" in
    *assert_* | *assert\ *)
      local trimmed="${line_text#"${line_text%%[![:space:]]*}"}"
      assert_lines="${assert_lines}\n    ${_BASHUNIT_COLOR_FAINT}${line_num}:${_BASHUNIT_COLOR_DEFAULT} ${trimmed}"
      ;;
    esac
    line_num=$((line_num + 1))
  done

  if [ -n "$assert_lines" ]; then
    echo -e "\n    ${_BASHUNIT_COLOR_FAINT}Source:${_BASHUNIT_COLOR_DEFAULT}${assert_lines}"
  fi
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

  echo -e "$test_nr) $test_file:$line_number\n$output_msg" >>"$SKIPPED_OUTPUT_PATH"
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

  echo -e "$test_nr) $test_file:$line_number\n$output_msg" >>"$INCOMPLETE_OUTPUT_PATH"
}

function bashunit::runner::write_risky_result_output() {
  local test_file=$1
  local fn_name=$2

  local line_number
  line_number=$(bashunit::helper::get_function_line_number "$fn_name")

  local test_nr="*"
  if ! bashunit::parallel::is_enabled; then
    test_nr=$(bashunit::state::get_tests_risky)
  fi

  echo -e "$test_nr) $test_file:$line_number\nTest has no assertions (risky)" >>"$RISKY_OUTPUT_PATH"
}

function bashunit::runner::record_file_hook_failure() {
  local hook_name="$1"
  local test_file="$2"
  local hook_output="$3"
  local status="$4"
  local render_header="${5:-false}"

  if [ "$render_header" = true ]; then
    bashunit::runner::render_running_file_header "$test_file" true
  fi

  if [ -z "$hook_output" ]; then
    hook_output="Hook '$hook_name' failed with exit code $status"
  fi

  bashunit::state::add_tests_failed
  bashunit::console_results::print_error_test "$hook_name" "$hook_output"
  local _normalized_hook
  _normalized_hook="$(bashunit::helper::normalize_test_function_name "$hook_name")"
  bashunit::reports::add_test_failed "$test_file" "$_normalized_hook" 0 0 "$hook_output"
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

  # Enable errtrace to catch any failing command in the hook.
  # Using -E (errtrace) without -e (errexit) prevents the main process from
  # exiting on source failures (Bash 3.2 doesn't trigger ERR trap with -eE).
  # The ERR trap saves the exit status to a global variable, cleans up shell
  # options, and returns from the hook function to prevent subsequent commands
  # from executing.
  # Variables set before the failure are preserved since we don't use a subshell.
  _BASHUNIT_HOOK_ERR_STATUS=0
  set -E
  if bashunit::env::is_strict_mode_enabled; then
    set -uo pipefail
  fi
  trap '_BASHUNIT_HOOK_ERR_STATUS=$?; set +Eu +o pipefail; trap - ERR; return $_BASHUNIT_HOOK_ERR_STATUS' ERR

  {
    "$hook_name"
  } >"$hook_output_file" 2>&1

  # Capture exit status from global variable and clean up
  status=$_BASHUNIT_HOOK_ERR_STATUS
  trap - ERR
  set +Eu +o pipefail

  if [ -f "$hook_output_file" ]; then
    hook_output=""
    local line
    while IFS= read -r line; do
      [ -z "$hook_output" ] && hook_output="$line" || hook_output="$hook_output"$'\n'"$line"
    done <"$hook_output_file"
    rm -f "$hook_output_file"
  fi

  if [ $status -ne 0 ]; then
    bashunit::runner::record_file_hook_failure "$hook_name" "$test_file" "$hook_output" "$status" "$render_header"
    return $status
  fi

  if [ -n "$hook_output" ] && bashunit::env::is_verbose_enabled; then
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

  # Check if hook exists first
  if ! declare -F "set_up_before_script" >/dev/null 2>&1; then
    return 0
  fi

  local start_time
  start_time=$(bashunit::clock::now)

  # Enable coverage trap to attribute lines executed during set_up_before_script
  if [ "${_BASHUNIT_COVERAGE_ON:-0}" = 1 ]; then
    bashunit::coverage::enable_trap
  fi

  # Execute the hook (render_header=false since header is already rendered)
  bashunit::runner::execute_file_hook 'set_up_before_script' "$test_file" false
  local status=$?

  # Disable coverage trap after hook execution
  if [ "${_BASHUNIT_COVERAGE_ON:-0}" = 1 ]; then
    bashunit::coverage::disable_trap
  fi

  local end_time
  end_time=$(bashunit::clock::now)
  local duration_ns=$((end_time - start_time))
  local duration_ms=$((duration_ns / 1000000))

  # Print completion message only if hook succeeded
  if [ $status -eq 0 ]; then
    bashunit::console_results::print_hook_completed "set_up_before_script" "$duration_ms"
  fi

  return $status
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

  # Enable errtrace to catch any failing command in the hook.
  # Using -E (errtrace) without -e (errexit) prevents the subshell from
  # exiting on source failures (Bash 3.2 doesn't trigger ERR trap with -eE).
  # The ERR trap saves the exit status to a global variable, cleans up shell
  # options, and returns from the hook function to prevent subsequent commands
  # from executing.
  # Variables set before the failure are preserved since we don't use a subshell.
  _BASHUNIT_HOOK_ERR_STATUS=0
  set -E
  if bashunit::env::is_strict_mode_enabled; then
    set -uo pipefail
  fi
  trap '_BASHUNIT_HOOK_ERR_STATUS=$?; set +Eu +o pipefail; trap - ERR; return $_BASHUNIT_HOOK_ERR_STATUS' ERR

  {
    "$hook_name"
  } >"$hook_output_file" 2>&1

  # Capture exit status from global variable and clean up
  status=$_BASHUNIT_HOOK_ERR_STATUS
  trap - ERR
  set +Eu +o pipefail

  if [ -f "$hook_output_file" ]; then
    hook_output=""
    local line
    while IFS= read -r line; do
      [ -z "$hook_output" ] && hook_output="$line" || hook_output="$hook_output"$'\n'"$line"
    done <"$hook_output_file"
    rm -f "$hook_output_file"
  fi

  if [ $status -ne 0 ]; then
    local message="$hook_output"
    if [ -n "$hook_output" ]; then
      printf "%s" "$hook_output"
    else
      message="Hook '$hook_name' failed with exit code $status"
      printf "%s\n" "$message" >&2
    fi
    bashunit::runner::record_test_hook_failure "$hook_name" "$message" "$status"
    return "$status"
  fi

  if [ -n "$hook_output" ]; then
    printf "%s" "$hook_output"
  fi

  return 0
}

function bashunit::runner::record_test_hook_failure() {
  local hook_name="$1"
  local hook_message="$2"
  local status="$3"

  if [ -n "$_BASHUNIT_TEST_HOOK_FAILURE" ]; then
    return "$status"
  fi

  bashunit::state::set_test_hook_failure "$hook_name"
  bashunit::state::set_test_hook_message "$hook_message"

  return "$status"
}

function bashunit::runner::clear_mocks() {
  if [ "${#_BASHUNIT_MOCKED_FUNCTIONS[@]}" -eq 0 ]; then
    return
  fi

  local i
  for i in "${!_BASHUNIT_MOCKED_FUNCTIONS[@]}"; do
    bashunit::unmock "${_BASHUNIT_MOCKED_FUNCTIONS[$i]:-}"
  done
}

function bashunit::runner::run_tear_down_after_script() {
  local test_file="$1"
  bashunit::internal_log "run_tear_down_after_script"

  # Check if hook exists first
  if ! declare -F "tear_down_after_script" >/dev/null 2>&1; then
    # Add blank line after tests if no tear_down hook
    if ! bashunit::env::is_simple_output_enabled &&
      ! bashunit::env::is_failures_only_enabled &&
      ! bashunit::env::is_no_progress_enabled &&
      ! bashunit::parallel::is_enabled; then
      echo ""
    fi
    return 0
  fi

  local start_time
  start_time=$(bashunit::clock::now)

  # Enable coverage trap to attribute lines executed during tear_down_after_script
  if [ "${_BASHUNIT_COVERAGE_ON:-0}" = 1 ]; then
    bashunit::coverage::enable_trap
  fi

  # Execute the hook
  bashunit::runner::execute_file_hook 'tear_down_after_script' "$test_file"
  local status=$?

  # Disable coverage trap after hook execution
  if [ "${_BASHUNIT_COVERAGE_ON:-0}" = 1 ]; then
    bashunit::coverage::disable_trap
  fi

  local end_time
  end_time=$(bashunit::clock::now)
  local duration_ns=$((end_time - start_time))
  local duration_ms=$((duration_ns / 1000000))

  # Print completion message only if hook succeeded
  if [ $status -eq 0 ]; then
    bashunit::console_results::print_hook_completed "tear_down_after_script" "$duration_ms"
  fi

  # Add blank line after tear_down output
  if ! bashunit::env::is_simple_output_enabled &&
    ! bashunit::env::is_failures_only_enabled &&
    ! bashunit::env::is_no_progress_enabled &&
    ! bashunit::parallel::is_enabled; then
    echo ""
  fi

  return $status
}

function bashunit::runner::clean_set_up_and_tear_down_after_script() {
  bashunit::internal_log "clean_set_up_and_tear_down_after_script"
  bashunit::helper::unset_if_exists 'set_up'
  bashunit::helper::unset_if_exists 'tear_down'
  bashunit::helper::unset_if_exists 'set_up_before_script'
  bashunit::helper::unset_if_exists 'tear_down_after_script'
}
