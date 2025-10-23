#!/usr/bin/env bash

declare -r BASHUNIT_GIT_REPO="https://github.com/TypedDevs/bashunit"

#
# @param $1 string Eg: "test_some_logic_camelCase"
#
# @return string Eg: "Some logic camelCase"
#
function helper::normalize_test_function_name() {
  local original_fn_name="${1-}"
  local interpolated_fn_name="${2-}"

  local custom_title
  custom_title="$(state::get_test_title)"
  if [[ -n "$custom_title" ]]; then
    echo "$custom_title"
    return
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
  # Capitalize the first letter
  result="$(echo "${result:0:1}" | tr '[:lower:]' '[:upper:]')${result:1}"

  echo "$result"
}

function helper::escape_single_quotes() {
  local value="$1"
  # shellcheck disable=SC1003
  echo "${value//\'/'\'\\''\'}"
}

function helper::interpolate_function_name() {
  local function_name="$1"
  shift
  local args=("$@")
  local result="$function_name"

  for ((i=0; i<${#args[@]}; i++)); do
    local placeholder="::$((i+1))::"
    # shellcheck disable=SC2155
    local value="$(helper::escape_single_quotes "${args[$i]}")"
    value="'$value'"
    result="${result//${placeholder}/${value}}"
  done

  echo "$result"
}

function helper::encode_base64() {
  local value="$1"

  if command -v base64 >/dev/null; then
    echo "$value" | base64 | tr -d '\n'
  else
    echo "$value" | openssl enc -base64 -A
  fi
}

function helper::decode_base64() {
  local value="$1"

  if command -v base64 >/dev/null; then
    echo "$value" | base64 -d
  else
    echo "$value" | openssl enc -d -base64
  fi
}

function helper::check_duplicate_functions() {
  local script="$1"

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
    state::set_duplicated_functions_merged "$script" "$duplicates"
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
function helper::get_functions_to_run() {
  local prefix=$1
  local filter=${2/test_/}
  local function_names=$3

  local filtered_functions=""

  for fn in $function_names; do
    if [[ $fn == ${prefix}_*${filter}* ]]; then
      if [[ $filtered_functions == *" $fn"* ]]; then
        return 1
      fi
      filtered_functions+=" $fn"
    fi
  done

  echo "${filtered_functions# }"
}

#
# @param $1 string Eg: "do_something"
#
function helper::execute_function_if_exists() {
  local fn_name="$1"

  if [[ "$(type -t "$fn_name")" == "function" ]]; then
    "$fn_name"
    return $?
  fi

  return 0
}

#
# @param $1 string Eg: "do_something"
#
function helper::unset_if_exists() {
  unset "$1" 2>/dev/null
}

function helper::find_files_recursive() {
  ## Remove trailing slash using parameter expansion
  local path="${1%%/}"
  local pattern="${2:-*[tT]est.sh}"

  local alt_pattern=""
  local test_pattern='\[tT\]est\.sh$'
  if [[ $pattern == *test.sh ]] || [[ $pattern =~ $test_pattern ]]; then
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

function helper::normalize_variable_name() {
  local input_string="$1"
  local normalized_string

  normalized_string="${input_string//[^a-zA-Z0-9_]/_}"

  local valid_start_pattern='^[a-zA-Z_]'
  if [[ ! $normalized_string =~ $valid_start_pattern ]]; then
    normalized_string="_$normalized_string"
  fi

  echo "$normalized_string"
}

function helper::get_provider_data() {
  local function_name="$1"
  local script="$2"

  if [[ ! -f "$script" ]]; then
    return
  fi

  local data_provider_function
  data_provider_function=$(
    # shellcheck disable=SC1087
    grep -B 2 -E "function[[:space:]]+$function_name[[:space:]]*\(\)" "$script" 2>/dev/null | \
    grep -E "^[[:space:]]*# *@?data_provider[[:space:]]+" | \
    sed -E 's/^[[:space:]]*# *@?data_provider[[:space:]]+//' || true
  )

  if [[ -n "$data_provider_function" ]]; then
    helper::execute_function_if_exists "$data_provider_function"
  fi
}

function helper::trim() {
  local input_string="$1"
  local trimmed_string

  trimmed_string="${input_string#"${input_string%%[![:space:]]*}"}"
  trimmed_string="${trimmed_string%"${trimmed_string##*[![:space:]]}"}"

  echo "$trimmed_string"
}

function helper::get_latest_tag() {
  if ! dependencies::has_git; then
    return 1
  fi

  git ls-remote --tags "$BASHUNIT_GIT_REPO" |
    awk '{print $2}' |
    sed 's|^refs/tags/||' |
    sort -Vr |
    head -n 1
}

function helper::find_total_tests() {
    local filter=${1:-}
    local files=("${@:2}")

    if [[ ${#files[@]} -eq 0 ]]; then
        echo 0
        return
    fi

    local total_count=0
    local file

    for file in "${files[@]}"; do
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
            filtered_functions=$(helper::get_functions_to_run "test" "$filter" "$all_fn_names") || true

            local count=0
            if [[ -n "$filtered_functions" ]]; then
                # shellcheck disable=SC2206
                # shellcheck disable=SC2207
                local functions_to_run=($filtered_functions)
                for fn_name in "${functions_to_run[@]}"; do
                    local provider_data
                    provider_data=()
                    local provider_output
                    provider_output="$(helper::get_provider_data "$fn_name" "$file")"
                    if [[ -n "$provider_output" ]]; then
                        local line
                        while IFS=" " read -r line; do
                            provider_data+=("$line")
                        done << EOF
$provider_output
EOF
                    fi

                    if [[ "${#provider_data[@]}" -eq 0 ]]; then
                        count=$((count + 1))
                    else
                        count=$((count + ${#provider_data[@]}))
                    fi
                done
            fi

            echo "$count"
        ) )

        total_count=$((total_count + file_count))
    done

    echo "$total_count"
}

function helper::load_test_files() {
  local filter=$1
  local files=("${@:2}")

  local test_files
  test_files=()

  if [[ "${#files[@]}" -eq 0 ]]; then
    if [[ -n "${BASHUNIT_DEFAULT_PATH}" ]]; then
      while IFS='' read -r line; do
        test_files+=("$line")
      done < <(helper::find_files_recursive "$BASHUNIT_DEFAULT_PATH")
    fi
  else
    test_files=("${files[@]}")
  fi

  printf "%s\n" "${test_files[@]}"
}

function helper::load_bench_files() {
  local filter=$1
  local files=("${@:2}")

  local bench_files
  bench_files=()

  if [[ "${#files[@]}" -eq 0 ]]; then
    if [[ -n "${BASHUNIT_DEFAULT_PATH}" ]]; then
      while IFS='' read -r line; do
        bench_files+=("$line")
      done < <(helper::find_files_recursive "$BASHUNIT_DEFAULT_PATH" '*[bB]ench.sh')
    fi
  else
    bench_files=("${files[@]}")
  fi

  printf "%s\n" "${bench_files[@]}"
}

#
# @param $1 string function name
# @return number line number of the function in the source file
#
function helper::get_function_line_number() {
  local fn_name=$1

  shopt -s extdebug
  local line_number
  line_number=$(declare -F "$fn_name" | awk '{print $2}')
  shopt -u extdebug

  echo "$line_number"
}

function helper::generate_id() {
  local basename="$1"
  local sanitized_basename
  sanitized_basename="$(helper::normalize_variable_name "$basename")"
  if env::is_parallel_run_enabled; then
    echo "${sanitized_basename}_$$_$(random_str 6)"
  else
    echo "${sanitized_basename}_$$"
  fi
}
