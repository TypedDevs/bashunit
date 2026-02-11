#!/usr/bin/env bash

declare -r BASHUNIT_GIT_REPO="https://github.com/TypedDevs/bashunit"

#
# Helper function for regex matching that works correctly in Bash 3.0+
# In Bash < 3.2, regex matching with literal patterns doesn't work properly,
# so we need to use this function instead of direct [[ ... =~ ... ]] checks.
#
# @param $1 string The string to match
# @param $2 string The regex pattern
#
# @return boolean True if the pattern matches, false otherwise
#
function bashunit::regex_match() {
  [[ $1 =~ $2 ]]
}

#
# Walks up the call stack to find the first function that looks like a test function.
# A test function is one that starts with "test_" or "test" (camelCase).
# If no test function is found, falls back to the caller of the assertion function.
#
# @param $1 number Optional fallback depth (default: 2, i.e., the caller of the assertion)
#
# @return string The test function name, or fallback function name
#
function bashunit::helper::find_test_function_name() {
  local fallback_depth="${1:-2}"
  local i
  for ((i = 0; i < ${#FUNCNAME[@]}; i++)); do
    local fn="${FUNCNAME[$i]}"
    # Check if function starts with "test_" or "test" followed by uppercase
    if [[ "$fn" == test_* ]] || bashunit::regex_match "$fn" '^test[A-Z]'; then
      echo "$fn"
      return
    fi
  done
  # No test function found, use fallback (caller of the assertion)
  # FUNCNAME[0] = bashunit::helper::find_test_function_name
  # FUNCNAME[1] = the assertion function (e.g., assert_same)
  # FUNCNAME[2] = caller of the assertion
  echo "${FUNCNAME[$fallback_depth]:-}"
}

#
# @param $1 string Eg: "test_some_logic_camelCase"
#
# @return string Eg: "Some logic camelCase"
#
function bashunit::helper::normalize_test_function_name() {
  local original_fn_name="${1-}"
  local interpolated_fn_name="${2-}"

  local custom_title
  custom_title="$(bashunit::state::get_test_title)"
  if [[ -n "$custom_title" ]]; then
    echo "$custom_title"
    return
  fi

  if [[ -z "${interpolated_fn_name-}" && "${original_fn_name}" == *"::"* ]]; then
    local state_interpolated_fn_name
    state_interpolated_fn_name="$(bashunit::state::get_current_test_interpolated_function_name)"

    if [[ -n "$state_interpolated_fn_name" ]]; then
      interpolated_fn_name="$state_interpolated_fn_name"
    fi
  fi

  if [[ -n "${interpolated_fn_name-}" ]]; then
    original_fn_name="$interpolated_fn_name"
  fi

  local result

  # Remove the first "test_" prefix, if present
  result="${original_fn_name#test_}"
  # If no "test_" was removed (e.g., "testFoo"), remove the "test" prefix
  if [[ "$result" == "$original_fn_name" ]]; then
    result="${original_fn_name#test}"
  fi
  # Replace underscores with spaces
  result="${result//_/ }"
  # Capitalize the first letter (bash 3.0 compatible, no subprocess)
  local first_char="${result:0:1}"
  case "$first_char" in
  a) first_char='A' ;; b) first_char='B' ;; c) first_char='C' ;; d) first_char='D' ;;
  e) first_char='E' ;; f) first_char='F' ;; g) first_char='G' ;; h) first_char='H' ;;
  i) first_char='I' ;; j) first_char='J' ;; k) first_char='K' ;; l) first_char='L' ;;
  m) first_char='M' ;; n) first_char='N' ;; o) first_char='O' ;; p) first_char='P' ;;
  q) first_char='Q' ;; r) first_char='R' ;; s) first_char='S' ;; t) first_char='T' ;;
  u) first_char='U' ;; v) first_char='V' ;; w) first_char='W' ;; x) first_char='X' ;;
  y) first_char='Y' ;; z) first_char='Z' ;;
  esac
  result="${first_char}${result:1}"

  echo "$result"
}

function bashunit::helper::escape_single_quotes() {
  local value="$1"
  # shellcheck disable=SC1003
  echo "${value//\'/'\'\\''\'}"
}

function bashunit::helper::interpolate_function_name() {
  local function_name="$1"
  shift
  local -a args
  local args_count=$#
  args=("$@")
  local result="$function_name"

  local i
  for ((i = 0; i < args_count; i++)); do
    local placeholder="::$((i + 1))::"
    # shellcheck disable=SC2155
    local value="$(bashunit::helper::escape_single_quotes "${args[$i]}")"
    value="'$value'"
    result="${result//${placeholder}/${value}}"
  done

  echo "$result"
}

function bashunit::helper::encode_base64() {
  local value="$1"

  # Handle empty string specially - base64 of "" is "", which gets lost in line parsing
  if [[ -z "$value" ]]; then
    printf '%s' "_BASHUNIT_EMPTY_"
    return
  fi

  if command -v base64 >/dev/null; then
    printf '%s' "$value" | base64 -w 0 2>/dev/null || printf '%s' "$value" | base64 | tr -d '\n'
  else
    printf '%s' "$value" | openssl enc -base64 -A
  fi
}

function bashunit::helper::decode_base64() {
  local value="$1"

  # Handle empty string marker
  if [[ "$value" == "_BASHUNIT_EMPTY_" ]]; then
    printf ''
    return
  fi

  if command -v base64 >/dev/null; then
    printf '%s' "$value" | base64 -d
  else
    printf '%s' "$value" | openssl enc -d -base64
  fi
}

function bashunit::helper::check_duplicate_functions() {
  local script="$1"

  # Handle directory changes in set_up_before_script (issue #529)
  if [[ ! -f "$script" && -n "${BASHUNIT_WORKING_DIR:-}" ]]; then
    script="$BASHUNIT_WORKING_DIR/$script"
  fi

  local filtered_lines
  filtered_lines=$(grep -E '^[[:space:]]*(function[[:space:]]+)?test[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)\s*\{' "$script")

  local function_names
  function_names=$(echo "$filtered_lines" | awk '{
    for (i=1; i<=NF; i++) {
      if ($i ~ /^test[a-zA-Z_][a-zA-Z0-9_]*\(\)$/) {
        gsub(/\(\)/, "", $i)
        print $i
        break
      }
    }
  }')

  local duplicates
  duplicates=$(echo "$function_names" | sort | uniq -d)
  if [ -n "$duplicates" ]; then
    bashunit::state::set_duplicated_functions_merged "$script" "$duplicates"
    return 1
  fi
  return 0
}

#
# @param $1 string Eg: "prefix"
# @param $2 string Eg: "filter"
# @param $3 array Eg: "[fn1, fn2, prefix_filter_fn3, fn4, ...]"
#
# @return array Eg: "[prefix_filter_fn3, ...]" The filtered functions with prefix
#
function bashunit::helper::get_functions_to_run() {
  local prefix=$1
  local filter=${2/test_/}
  local function_names=$3

  local filtered_functions=""

  local fn
  for fn in $function_names; do
    if [[ $fn == ${prefix}_*${filter}* ]]; then
      if [[ $filtered_functions == *" $fn"* ]]; then
        return 1
      fi
      filtered_functions="$filtered_functions $fn"
    fi
  done

  echo "${filtered_functions# }"
}

#
# @param $1 string Eg: "do_something"
#
function bashunit::helper::execute_function_if_exists() {
  local fn_name="$1"

  if declare -F "$fn_name" >/dev/null 2>&1; then
    "$fn_name"
    return $?
  fi

  return 0
}

#
# @param $1 string Eg: "do_something"
#
function bashunit::helper::unset_if_exists() {
  unset "$1" 2>/dev/null
}

function bashunit::helper::find_files_recursive() {
  ## Remove trailing slash using parameter expansion
  local path="${1%%/}"
  local pattern="${2:-*[tT]est.sh}"

  local alt_pattern=""
  if [[ $pattern == *test.sh ]] || bashunit::regex_match "$pattern" '\[tT\]est\.sh$'; then
    alt_pattern="${pattern%.sh}.bash"
  fi

  if [[ "$path" == *"*"* ]]; then
    if [[ -n $alt_pattern ]]; then
      eval "find $path -type f \( -name \"$pattern\" -o -name \"$alt_pattern\" \)" | sort -u
    else
      eval "find $path -type f -name \"$pattern\"" | sort -u
    fi
  elif [[ -d "$path" ]]; then
    if [[ -n $alt_pattern ]]; then
      find "$path" -type f \( -name "$pattern" -o -name "$alt_pattern" \) | sort -u
    else
      find "$path" -type f -name "$pattern" | sort -u
    fi
  else
    echo "$path"
  fi
}

function bashunit::helper::normalize_variable_name() {
  local input_string="$1"
  local normalized_string

  normalized_string="${input_string//[^a-zA-Z0-9_]/_}"

  if ! bashunit::regex_match "$normalized_string" '^[a-zA-Z_]'; then
    normalized_string="_$normalized_string"
  fi

  echo "$normalized_string"
}

function bashunit::helper::get_provider_data() {
  local function_name="$1"
  local script="$2"

  # Handle directory changes in set_up_before_script (issue #529)
  # If relative path doesn't exist, try with BASHUNIT_WORKING_DIR
  if [[ ! -f "$script" && -n "${BASHUNIT_WORKING_DIR:-}" ]]; then
    script="$BASHUNIT_WORKING_DIR/$script"
  fi

  if [[ ! -f "$script" ]]; then
    return
  fi

  local data_provider_function
  data_provider_function=$(
    # shellcheck disable=SC1087
    grep -B 2 -E "(function[[:space:]]+)?$function_name[[:space:]]*\(\)" "$script" 2>/dev/null |
      sed -nE 's/^[[:space:]]*# *@?data_provider[[:space:]]+//p'
  )

  if [[ -n "$data_provider_function" ]]; then
    bashunit::helper::execute_function_if_exists "$data_provider_function"
  fi
}

function bashunit::helper::trim() {
  local input_string="$1"
  local trimmed_string

  trimmed_string="${input_string#"${input_string%%[![:space:]]*}"}"
  trimmed_string="${trimmed_string%"${trimmed_string##*[![:space:]]}"}"

  echo "$trimmed_string"
}

function bashunit::helper::get_latest_tag() {
  if ! bashunit::dependencies::has_git; then
    return 1
  fi

  git ls-remote --tags "$BASHUNIT_GIT_REPO" |
    awk '{print $2}' |
    sed 's|^refs/tags/||' |
    grep -v '\^{}' |
    sort -Vr |
    head -n 1
}

function bashunit::helper::find_total_tests() {
  local filter=${1:-}
  shift || true

  if [[ $# -eq 0 ]]; then
    echo 0
    return
  fi

  local total_count=0
  local file

  for file in "$@"; do
    if [[ ! -f "$file" ]]; then
      continue
    fi

    local file_count
    file_count=$( (
      # shellcheck source=/dev/null
      source "$file"
      local all_fn_names
      all_fn_names=$(declare -F | awk '{print $3}')
      local filtered_functions
      filtered_functions=$(bashunit::helper::get_functions_to_run "test" "$filter" "$all_fn_names") || true

      local count=0
      local IFS=$' \t\n'
      if [[ -n "$filtered_functions" ]]; then
        local -a functions_to_run=()
        # shellcheck disable=SC2206
        functions_to_run=($filtered_functions)
        # shellcheck disable=SC2034
        local -a provider_data=()
        local provider_data_count=0
        local fn_name line
        for fn_name in "${functions_to_run[@]+"${functions_to_run[@]}"}"; do
          provider_data=()
          provider_data_count=0
          while IFS=" " read -r line; do
            [[ -z "$line" ]] && continue
            # shellcheck disable=SC2034
            provider_data[provider_data_count]="$line"
            provider_data_count=$((provider_data_count + 1))
          done <<<"$(bashunit::helper::get_provider_data "$fn_name" "$file")"

          if [[ "$provider_data_count" -eq 0 ]]; then
            count=$((count + 1))
          else
            count=$((count + provider_data_count))
          fi
        done
      fi

      echo "$count"
    ))

    total_count=$((total_count + file_count))
  done

  echo "$total_count"
}

function bashunit::helper::load_test_files() {
  local filter="${1:-}"
  shift || true
  # Bash 3.0 compatible: use $# after shift to check for files
  local has_files=$#

  if [[ "$has_files" -eq 0 ]]; then
    if [[ -n "${BASHUNIT_DEFAULT_PATH:-}" ]]; then
      bashunit::helper::find_files_recursive "$BASHUNIT_DEFAULT_PATH"
    fi
  else
    printf "%s\n" "$@"
  fi
}

function bashunit::helper::load_bench_files() {
  local filter="${1:-}"
  shift || true
  # Bash 3.0 compatible: use $# after shift to check for files
  local has_files=$#

  if [[ "$has_files" -eq 0 ]]; then
    if [[ -n "${BASHUNIT_DEFAULT_PATH:-}" ]]; then
      bashunit::helper::find_files_recursive "$BASHUNIT_DEFAULT_PATH" '*[bB]ench.sh'
    fi
  else
    printf "%s\n" "$@"
  fi
}

#
# @param $1 string function name
# @return number line number of the function in the source file
#
function bashunit::helper::get_function_line_number() {
  local fn_name=$1

  shopt -s extdebug
  local line_number
  line_number=$(declare -F "$fn_name" | awk '{print $2}')
  shopt -u extdebug

  echo "$line_number"
}

function bashunit::helper::generate_id() {
  local basename="$1"
  local sanitized_basename
  sanitized_basename="$(bashunit::helper::normalize_variable_name "$basename")"
  if bashunit::env::is_parallel_run_enabled; then
    echo "${sanitized_basename}_$$_$(bashunit::random_str 6)"
  else
    echo "${sanitized_basename}_$$"
  fi
}

#
# Parses a file path that may contain a filter suffix.
# Supports two syntaxes:
#   - path::function_name (filter by function name)
#   - path:line_number (filter by line number)
#
# @param $1 string Eg: "tests/test.sh::test_foo" or "tests/test.sh:123"
#
# @return string Two lines: first is file path, second is filter (or empty)
#
function bashunit::helper::parse_file_path_filter() {
  local input="$1"
  local file_path=""
  local filter=""

  # Check for :: syntax (function name filter)
  if [[ "$input" == *"::"* ]]; then
    file_path="${input%%::*}"
    filter="${input#*::}"
  # Check for :number syntax (line number filter)
  else
    if bashunit::regex_match "$input" '^(.+):([0-9]+)$'; then
      file_path="${BASH_REMATCH[1]}"
      local line_number="${BASH_REMATCH[2]}"
      # Line number will be resolved to function name later
      filter="__line__:${line_number}"
    else
      file_path="$input"
    fi
  fi

  echo "$file_path"
  echo "$filter"
}

#
# Finds the test function that contains a given line number in a file.
#
# @param $1 string File path
# @param $2 number Line number
#
# @return string The function name, or empty if not found
#
function bashunit::helper::find_function_at_line() {
  local file="$1"
  local target_line="$2"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  # Find all test function definitions and their line numbers
  local best_match=""
  local best_line=0

  local line_num content
  while IFS=: read -r line_num content; do
    # Extract function name from the line
    local fn_name=""
    local fn_pattern='^[[:space:]]*(function[[:space:]]+)?(test[a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)'
    if bashunit::regex_match "$content" "$fn_pattern"; then
      fn_name="${BASH_REMATCH[2]}"
    fi

    if [[ -n "$fn_name" && "$line_num" -le "$target_line" && "$line_num" -gt "$best_line" ]]; then
      best_match="$fn_name"
      best_line="$line_num"
    fi
  done < <(grep -n -E '^[[:space:]]*(function[[:space:]]+)?test[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)' "$file")

  echo "$best_match"
}
