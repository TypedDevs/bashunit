#!/usr/bin/env bash

declare -r BASHUNIT_GIT_REPO="https://github.com/TypedDevs/bashunit"

#
# Walks up the call stack to find the first function that looks like a test function.
# A test function is one that starts with "test_" or "test" (camelCase).
# If no test function is found, falls back to the caller of the assertion function.
#
# @param $1 number Optional fallback depth (default: 2, i.e., the caller of the assertion)
#
# @return string The test function name, or fallback function name
#
_BASHUNIT_HELPER_TESTFN_OUT=""

#
# Return-slot variant of find_test_function_name: writes the result into
# _BASHUNIT_HELPER_TESTFN_OUT with no fork. Must be called at the SAME stack
# depth the echoing version would be captured at, so the fallback_depth default
# keeps pointing at the caller of the assertion (see the echoing wrapper below).
#
function bashunit::helper::find_test_function_name_to_slot() {
  local fallback_depth="${1:-2}"
  local i
  for ((i = 0; i < ${#FUNCNAME[@]}; i++)); do
    local fn="${FUNCNAME[$i]}"
    case "$fn" in
    test_* | test[A-Z]*)
      _BASHUNIT_HELPER_TESTFN_OUT=$fn
      return
      ;;
    esac
  done
  _BASHUNIT_HELPER_TESTFN_OUT=${FUNCNAME[$fallback_depth]:-}
}

function bashunit::helper::find_test_function_name() {
  local fallback_depth="${1:-2}"
  local i
  for ((i = 0; i < ${#FUNCNAME[@]}; i++)); do
    local fn="${FUNCNAME[$i]}"
    # Check if function starts with "test_" or "test" followed by uppercase.
    # Pure-bash globs avoid forking echo+grep on every call-stack frame (hot path).
    case "$fn" in
    test_* | test[A-Z]*)
      echo "$fn"
      return
      ;;
    esac
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
_BASHUNIT_HELPER_NORMALIZED_OUT=""

#
# Return-slot variant of normalize_test_function_name: writes the result into
# _BASHUNIT_HELPER_NORMALIZED_OUT with no fork, removing the command-substitution
# fork at the (failure-path) call sites in the assertion layer.
#
# @param $1 string Eg: "test_some_logic_camelCase"
# @param $2 string Optional interpolated name
#
function bashunit::helper::normalize_test_function_name_to_slot() {
  local original_fn_name="${1-}"
  local interpolated_fn_name="${2-}"

  # Read the reserved-namespace state globals directly (the accessors just echo
  # them) to avoid a nested subshell fork on this per-test hot path (#764).
  local custom_title="${_BASHUNIT_TEST_TITLE:-}"
  if [ -n "$custom_title" ]; then
    _BASHUNIT_HELPER_NORMALIZED_OUT=$custom_title
    return
  fi

  if [ -z "${interpolated_fn_name-}" ]; then
    case "${original_fn_name}" in
    *"::"*)
      local state_interpolated_fn_name="${_BASHUNIT_CURRENT_TEST_INTERPOLATED_NAME:-}"

      if [ -n "$state_interpolated_fn_name" ]; then
        interpolated_fn_name="$state_interpolated_fn_name"
      fi
      ;;
    esac
  fi

  if [ -n "${interpolated_fn_name-}" ]; then
    original_fn_name="$interpolated_fn_name"
  fi

  local result

  # Remove the first "test_" prefix, if present
  result="${original_fn_name#test_}"
  # If no "test_" was removed (e.g., "testFoo"), remove the "test" prefix
  if [ "$result" = "$original_fn_name" ]; then
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

  _BASHUNIT_HELPER_NORMALIZED_OUT=$result
}

#
# @param $1 string Eg: "test_some_logic_camelCase"
#
# @return string Eg: "Some logic camelCase"
#
function bashunit::helper::normalize_test_function_name() {
  bashunit::helper::normalize_test_function_name_to_slot "${1-}" "${2-}"
  echo "$_BASHUNIT_HELPER_NORMALIZED_OUT"
}

function bashunit::helper::escape_single_quotes() {
  local value="$1"
  # shellcheck disable=SC1003
  echo "${value//\'/'\'\\''\'}"
}

function bashunit::helper::interpolate_function_name() {
  local function_name="$1"
  shift

  # Placeholders look like "::N::", so a name without "::" can never interpolate.
  # Short-circuit to skip the per-arg escape_single_quotes forks in that case.
  case "$function_name" in
  *::*) ;;
  *)
    echo "$function_name"
    return
    ;;
  esac

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
  if [ -z "$value" ]; then
    printf '%s' "_BASHUNIT_EMPTY_"
    return
  fi

  if [ "$_BASHUNIT_BASE64_WRAP_FLAG" = true ]; then
    printf '%s' "$value" | base64 -w 0
  elif command -v base64 >/dev/null; then
    printf '%s' "$value" | base64 | tr -d '\n'
  else
    printf '%s' "$value" | openssl enc -base64 -A
  fi
}

function bashunit::helper::decode_base64() {
  local value="$1"

  # Empty input decodes to empty; short-circuit to skip the base64 fork (#762).
  if [ -z "$value" ] || [ "$value" = "_BASHUNIT_EMPTY_" ]; then
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
  if [ ! -f "$script" ] && [ -n "${BASHUNIT_WORKING_DIR:-}" ]; then
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
    local _fn_match=false
    case "$fn" in ${prefix}_*${filter}*) _fn_match=true ;; esac
    if [ "$_fn_match" = true ]; then
      local _dup=false
      case "$filtered_functions" in *" $fn"*) _dup=true ;; esac
      if [ "$_dup" = true ]; then
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
  local _re='\[tT\]est\.sh$'
  local _pattern_match=false
  case "$pattern" in *test.sh) _pattern_match=true ;; esac
  if [ "$_pattern_match" = true ] || [ "$(echo "$pattern" | "$GREP" -cE "$_re" || true)" -gt 0 ]; then
    alt_pattern="${pattern%.sh}.bash"
  fi

  local _has_glob=false
  case "$path" in *"*"*) _has_glob=true ;; esac
  if [ "$_has_glob" = true ]; then
    if [ -n "$alt_pattern" ]; then
      eval "find $path -type f \( -name \"$pattern\" -o -name \"$alt_pattern\" \)" | sort -u
    else
      eval "find $path -type f -name \"$pattern\"" | sort -u
    fi
  elif [ -d "$path" ]; then
    if [ -n "$alt_pattern" ]; then
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
  local normalized_string="${input_string//[^a-zA-Z0-9_]/_}"

  # First character must be alpha or underscore. Empty string also gets a `_`
  # prefix to satisfy the same identifier rule. Uses pure-bash globbing to
  # avoid a per-call grep fork (called once per test via generate_id).
  case "${normalized_string:0:1}" in
  [a-zA-Z_]) ;;
  *) normalized_string="_$normalized_string" ;;
  esac

  builtin echo "$normalized_string"
}

# Provider map for the most recently scanned script. Scanning a file once and
# caching the test-function -> provider-function pairs replaces a per-test
# grep+sed fork with a pure-bash lookup on the hot path (issue #763).
_BASHUNIT_PROVIDER_MAP_SCRIPT=""
_BASHUNIT_PROVIDER_MAP_FNS=()
_BASHUNIT_PROVIDER_MAP_PROVIDERS=()
_BASHUNIT_PROVIDER_FN_OUT=""
# Set true when the scanned file carries the "# bashunit: no-parallel-tests"
# opt-out; detected in the same awk pass to avoid a per-file grep fork (#774).
_BASHUNIT_PROVIDER_MAP_NO_PARALLEL=false

#
# Resolves a script path, applying the issue #529 working-dir fallback.
# Writes the resolved path into _BASHUNIT_PROVIDER_RESOLVED_OUT (empty if unreadable).
#
_BASHUNIT_PROVIDER_RESOLVED_OUT=""
function bashunit::helper::_resolve_provider_script() {
  local script=$1
  # Handle directory changes in set_up_before_script (issue #529)
  if [ ! -f "$script" ] && [ -n "${BASHUNIT_WORKING_DIR:-}" ]; then
    script="$BASHUNIT_WORKING_DIR/$script"
  fi
  if [ ! -f "$script" ]; then
    _BASHUNIT_PROVIDER_RESOLVED_OUT=""
    return
  fi
  _BASHUNIT_PROVIDER_RESOLVED_OUT=$script
}

#
# Scans a script once and caches its test-function -> provider-function pairs.
# Memoized by resolved path, so repeated calls for the same file do not rescan.
#
# @param $1 string Path to the test script
#
function bashunit::helper::build_provider_map() {
  bashunit::helper::_resolve_provider_script "$1"
  local script=$_BASHUNIT_PROVIDER_RESOLVED_OUT

  if [ -z "$script" ]; then
    # Unreadable path: reset to an empty map keyed to this argument so a
    # follow-up lookup returns empty without rescanning.
    _BASHUNIT_PROVIDER_MAP_SCRIPT="$1"
    _BASHUNIT_PROVIDER_MAP_FNS=()
    _BASHUNIT_PROVIDER_MAP_PROVIDERS=()
    _BASHUNIT_PROVIDER_MAP_NO_PARALLEL=false
    return
  fi

  if [ "$script" = "$_BASHUNIT_PROVIDER_MAP_SCRIPT" ]; then
    return
  fi

  _BASHUNIT_PROVIDER_MAP_SCRIPT="$script"
  _BASHUNIT_PROVIDER_MAP_FNS=()
  _BASHUNIT_PROVIDER_MAP_PROVIDERS=()
  _BASHUNIT_PROVIDER_MAP_NO_PARALLEL=false

  local count=0
  local fn provider
  # Single awk pass emits "<fn>\t<provider>" for every function whose
  # definition is at most two lines below a `# @data_provider` (or
  # `# data_provider`) annotation, mirroring the previous grep -B2 + sed.
  # A reserved sentinel fn name carries the no-parallel-tests flag out of the
  # single awk pass; real fn names are identifiers so they never collide.
  while IFS=$'\t' read -r fn provider; do
    [ -z "$fn" ] && continue
    if [ "$fn" = "@@no_parallel@@" ]; then
      [ "$provider" = "1" ] && _BASHUNIT_PROVIDER_MAP_NO_PARALLEL=true
      continue
    fi
    _BASHUNIT_PROVIDER_MAP_FNS[count]="$fn"
    _BASHUNIT_PROVIDER_MAP_PROVIDERS[count]="$provider"
    count=$((count + 1))
  done < <(awk '
    /^# bashunit: no-parallel-tests/ { no_parallel = 1; next }
    /^[[:space:]]*#[[:space:]]*@?data_provider[[:space:]]+/ {
      p = $0
      sub(/^[[:space:]]*#[[:space:]]*@?data_provider[[:space:]]+/, "", p)
      sub(/[[:space:]]+$/, "", p)
      pending = p
      pending_line = NR
      next
    }
    {
      if (pending != "" && NR - pending_line <= 2) {
        if (match($0, /^[[:space:]]*(function[[:space:]]+)?[A-Za-z_][A-Za-z0-9_:]*[[:space:]]*\(\)/)) {
          fn = $0
          sub(/^[[:space:]]*(function[[:space:]]+)?/, "", fn)
          sub(/[[:space:]]*\(\).*/, "", fn)
          printf "%s\t%s\n", fn, pending
          pending = ""
        }
      } else if (pending != "" && NR - pending_line > 2) {
        pending = ""
      }
    }
    END { printf "@@no_parallel@@\t%d\n", no_parallel }
  ' "$script" 2>/dev/null)
}

#
# Pure-bash lookup against the cached provider map.
# Writes the provider-function name (or empty) into _BASHUNIT_PROVIDER_FN_OUT.
#
# @param $1 string Test-function name
#
function bashunit::helper::provider_for_function() {
  local function_name=$1
  local i=0
  local total=${#_BASHUNIT_PROVIDER_MAP_FNS[@]}
  while [ "$i" -lt "$total" ]; do
    if [ "${_BASHUNIT_PROVIDER_MAP_FNS[i]}" = "$function_name" ]; then
      _BASHUNIT_PROVIDER_FN_OUT="${_BASHUNIT_PROVIDER_MAP_PROVIDERS[i]}"
      return
    fi
    i=$((i + 1))
  done
  _BASHUNIT_PROVIDER_FN_OUT=""
}

function bashunit::helper::get_provider_data() {
  local function_name="$1"
  local script="$2"

  bashunit::helper::build_provider_map "$script"
  bashunit::helper::provider_for_function "$function_name"

  if [ -n "$_BASHUNIT_PROVIDER_FN_OUT" ]; then
    bashunit::helper::execute_function_if_exists "$_BASHUNIT_PROVIDER_FN_OUT"
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

  # Floating major tags (e.g. v0) are not releases and must not win
  git ls-remote --tags "$BASHUNIT_GIT_REPO" |
    awk '{print $2}' |
    sed 's|^refs/tags/||' |
    grep -v '\^{}' |
    grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$' |
    sort -Vr |
    head -n 1
}

function bashunit::helper::find_total_tests() {
  local filter=${1:-}
  shift || true

  if [ $# -eq 0 ]; then
    echo 0
    return
  fi

  local total_count=0
  local file

  for file in "$@"; do
    if [ ! -f "$file" ]; then
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
      if [ -n "$filtered_functions" ]; then
        local -a functions_to_run=()
        # shellcheck disable=SC2206
        functions_to_run=($filtered_functions)
        # shellcheck disable=SC2034
        local -a provider_data=()
        local provider_data_count=0
        local fn_name line
        # Scan once; functions without a provider count as 1 with no fork (#763).
        bashunit::helper::build_provider_map "$file"
        for fn_name in "${functions_to_run[@]+"${functions_to_run[@]}"}"; do
          bashunit::helper::provider_for_function "$fn_name"
          if [ -z "$_BASHUNIT_PROVIDER_FN_OUT" ]; then
            count=$((count + 1))
            continue
          fi
          provider_data_count=0
          while IFS=" " read -r line; do
            [ -z "$line" ] && continue
            provider_data_count=$((provider_data_count + 1))
          done <<<"$(bashunit::helper::execute_function_if_exists "$_BASHUNIT_PROVIDER_FN_OUT")"

          if [ "$provider_data_count" -eq 0 ]; then
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

  if [ "$has_files" -eq 0 ]; then
    if [ -n "${BASHUNIT_DEFAULT_PATH:-}" ]; then
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

  if [ "$has_files" -eq 0 ]; then
    if [ -n "${BASHUNIT_DEFAULT_PATH:-}" ]; then
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

# Writes a sanitized, process-unique id into _BASHUNIT_HELPER_ID_OUT.
# Return-slot form so the per-test caller avoids a $(...) capture fork (#764).
# Arguments: $1 basename
_BASHUNIT_HELPER_ID_OUT=""
function bashunit::helper::generate_id() {
  local basename="$1"
  # Inline normalize_variable_name + random_str to avoid two forks per call.
  # generate_id is called once per test and per file load.
  local sanitized="${basename//[^a-zA-Z0-9_]/_}"
  case "${sanitized:0:1}" in
  [a-zA-Z_]) ;;
  *) sanitized="_$sanitized" ;;
  esac
  if bashunit::env::is_parallel_run_enabled; then
    local _chars='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local _suffix=''
    local _i
    for ((_i = 0; _i < 6; _i++)); do
      _suffix="$_suffix${_chars:RANDOM%${#_chars}:1}"
    done
    _BASHUNIT_HELPER_ID_OUT="${sanitized}_$$_${_suffix}"
  else
    _BASHUNIT_HELPER_ID_OUT="${sanitized}_$$"
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
  case "$input" in *"::"*)
    file_path="${input%%::*}"
    filter="${input#*::}"
    ;;
  *)
    # Check for :number syntax (line number filter): a non-empty path, a
    # colon, then digits to the end of string. Pure-bash parameter expansion
    # avoids forking grep+sed.
    local line_number="${input##*:}"
    local maybe_path="${input%:*}"
    case "$line_number" in
    '' | *[!0-9]*)
      file_path="$input"
      ;;
    *)
      if [ -n "$maybe_path" ] && [ "$maybe_path" != "$input" ]; then
        # Line number will be resolved to function name later
        file_path="$maybe_path"
        filter="__line__:${line_number}"
      else
        file_path="$input"
      fi
      ;;
    esac
    ;;
  esac

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

  if [ ! -f "$file" ]; then
    return 1
  fi

  # Find all test function definitions and their line numbers
  local best_match=""
  local best_line=0

  local line_num content
  while IFS=: read -r line_num content; do
    # Extract function name from the line
    local fn_name=""
    local fn_pattern='^[[:space:]]*(function[[:space:]]+)?(test[a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\).*'
    fn_name=$(echo "$content" | sed -nE "s/$fn_pattern/\2/p")

    if [ -n "$fn_name" ] && [ "$line_num" -le "$target_line" ] && [ "$line_num" -gt "$best_line" ]; then
      best_match="$fn_name"
      best_line="$line_num"
    fi
  done < <(grep -n -E '^[[:space:]]*(function[[:space:]]+)?test[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)' "$file")

  echo "$best_match"
}

# Tags map for the most recently scanned script. Mirrors the provider map
# (build_provider_map): scanning a file once and caching each test-function ->
# comma-separated tags pair replaces a per-test grep/sed backward walk with a
# pure-bash lookup on the hot path when `--tag`/`--exclude-tag` is used (#773).
_BASHUNIT_TAGS_MAP_SCRIPT=""
_BASHUNIT_TAGS_MAP_FNS=()
_BASHUNIT_TAGS_MAP_TAGS=()
_BASHUNIT_TAGS_OUT=""

#
# Scans a script once and caches its test-function -> tags pairs.
# Memoized by resolved path, so repeated calls for the same file do not rescan.
#
# @param $1 string Path to the test script
#
function bashunit::helper::build_tags_map() {
  local script=$1
  # Handle directory changes in set_up_before_script (issue #529)
  if [ ! -f "$script" ] && [ -n "${BASHUNIT_WORKING_DIR:-}" ]; then
    script="$BASHUNIT_WORKING_DIR/$script"
  fi

  if [ ! -f "$script" ]; then
    # Unreadable path: reset to an empty map keyed to this argument so a
    # follow-up lookup returns empty without rescanning.
    _BASHUNIT_TAGS_MAP_SCRIPT="$1"
    _BASHUNIT_TAGS_MAP_FNS=()
    _BASHUNIT_TAGS_MAP_TAGS=()
    return
  fi

  if [ "$script" = "$_BASHUNIT_TAGS_MAP_SCRIPT" ]; then
    return
  fi

  _BASHUNIT_TAGS_MAP_SCRIPT="$script"
  _BASHUNIT_TAGS_MAP_FNS=()
  _BASHUNIT_TAGS_MAP_TAGS=()

  local count=0
  local fn tags
  # Single awk pass emits "<fn>\t<tags>" for every function that carries at
  # least one `# @tag <name>` comment in the contiguous comment block directly
  # above its definition, mirroring the previous per-function backward walk.
  # Tags accumulate nearest-to-the-function first (same order the old walk
  # produced). A blank or non-comment line breaks the association; other
  # comment lines keep the block open. Both `function test_x` and `test_x()`
  # definition styles are recognised.
  while IFS=$'\t' read -r fn tags; do
    [ -z "$fn" ] && continue
    _BASHUNIT_TAGS_MAP_FNS[count]="$fn"
    _BASHUNIT_TAGS_MAP_TAGS[count]="$tags"
    count=$((count + 1))
  done < <(awk '
    /^[[:space:]]*#[[:space:]]*@tag[[:space:]]/ {
      t = $0
      sub(/^[[:space:]]*#[[:space:]]*@tag[[:space:]]+/, "", t)
      tags = (tags == "" ? t : t "," tags)
      next
    }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*(function[[:space:]]+)?[A-Za-z_][A-Za-z0-9_:]*[[:space:]]*\(\)/ {
      fn = $0
      sub(/^[[:space:]]*(function[[:space:]]+)?/, "", fn)
      sub(/[[:space:]]*\(\).*/, "", fn)
      if (tags != "") printf "%s\t%s\n", fn, tags
      tags = ""
      next
    }
    { tags = "" }
  ' "$script" 2>/dev/null)
}

#
# Pure-bash lookup against the cached tags map.
# Writes the comma-separated tags (or empty) into _BASHUNIT_TAGS_OUT.
#
# @param $1 string Test-function name
#
function bashunit::helper::tags_for_function() {
  local function_name=$1
  local i=0
  local total=${#_BASHUNIT_TAGS_MAP_FNS[@]}
  while [ "$i" -lt "$total" ]; do
    if [ "${_BASHUNIT_TAGS_MAP_FNS[i]}" = "$function_name" ]; then
      _BASHUNIT_TAGS_OUT="${_BASHUNIT_TAGS_MAP_TAGS[i]}"
      return
    fi
    i=$((i + 1))
  done
  _BASHUNIT_TAGS_OUT=""
}

#
# Extracts @tag annotations for a specific function from a test file.
# Thin wrapper over the cached tags map, kept for callers that want the tags
# on stdout. Hot-path call sites use build_tags_map + tags_for_function to
# avoid the subshell fork.
#
# @param $1 string Function name
# @param $2 string Script file path
#
# @return string Comma-separated list of tags, or empty if none
#
function bashunit::helper::get_tags_for_function() {
  bashunit::helper::build_tags_map "$2"
  bashunit::helper::tags_for_function "$1"
  echo "$_BASHUNIT_TAGS_OUT"
}

#
# Checks if a function's tags match the include/exclude filters.
# Include uses OR logic (any match passes).
# Exclude uses OR logic (any match fails).
# Exclude takes precedence over include.
#
# @param $1 string Comma-separated tags for the function
# @param $2 string Comma-separated include tags (empty = no filter)
# @param $3 string Comma-separated exclude tags (empty = no filter)
#
# @return 0 if function should run, 1 if it should be skipped
#
function bashunit::helper::function_matches_tags() {
  local fn_tags="$1"
  local include_tags="$2"
  local exclude_tags="$3"

  # Check exclude tags first (exclude wins over include)
  if [ -n "$exclude_tags" ]; then
    local IFS=','
    local etag
    for etag in $exclude_tags; do
      local check_tag
      for check_tag in $fn_tags; do
        if [ "$check_tag" = "$etag" ]; then
          return 1
        fi
      done
    done
  fi

  # Check include tags (OR logic: any match passes)
  if [ -n "$include_tags" ]; then
    if [ -z "$fn_tags" ]; then
      return 1
    fi
    local IFS=','
    local itag
    for itag in $include_tags; do
      local check_tag
      for check_tag in $fn_tags; do
        if [ "$check_tag" = "$itag" ]; then
          return 0
        fi
      done
    done
    return 1
  fi

  return 0
}
