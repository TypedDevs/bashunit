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
  result="$(tr '[:lower:]' '[:upper:]' <<< "${result:0:1}")${result:1}"

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
  if [[ "$(type -t "$1")" == "function" ]]; then
    "$1" 2>/dev/null
  fi
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

  if [[ "$path" == *"*"* ]]; then
    eval find "$path" -type f -name "$pattern" | sort -u
  elif [[ -d "$path" ]]; then
    find "$path" -type f -name "$pattern" | sort -u
  else
    echo "$path"
  fi
}

function helper::normalize_variable_name() {
  local input_string="$1"
  local normalized_string

  normalized_string="${input_string//[^a-zA-Z0-9_]/_}"

  if [[ ! $normalized_string =~ ^[a-zA-Z_] ]]; then
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

function helpers::get_latest_tag() {
  git ls-remote --tags "$BASHUNIT_GIT_REPO" |
    awk '{print $2}' |
    sed 's|^refs/tags/||' |
    sort -Vr |
    head -n 1
}

function helpers::find_total_tests() {
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
                    local provider_data=()
                    while IFS=" " read -r line; do
                        provider_data+=("$line")
                    done <<< "$(helper::get_provider_data "$fn_name" "$file")"

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

  local test_files=()

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

  local bench_files=()

  if [[ "${#files[@]}" -eq 0 ]]; then
    if [[ -n "${BASHUNIT_DEFAULT_PATH}" ]]; then
      while IFS='' read -r line; do
        bench_files+=("$line")
      done < <(helper::find_files_recursive "$BASHUNIT_DEFAULT_PATH" '*bench.sh')
    fi
  else
    bench_files=("${files[@]}")
  fi

  printf "%s\n" "${bench_files[@]}"
}
