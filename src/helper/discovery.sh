#!/usr/bin/env bash

# Finding test files, test functions and their line numbers.

function bashunit::helper::check_duplicate_functions() {
  local script="$1"

  # Handle directory changes in set_up_before_script (issue #529)
  if [ ! -f "$script" ] && [ -n "${BASHUNIT_WORKING_DIR:-}" ]; then
    script="$BASHUNIT_WORKING_DIR/$script"
  fi

  # One awk pass over the file finds each test-function definition and emits only
  # the names seen more than once, folding the former grep + awk + sort + uniq
  # chain into a single awk (#761). The END block insertion-sorts the (tiny,
  # usually empty) duplicate list itself, so no `sort` fork is needed to keep
  # the output deterministic.
  local duplicates
  duplicates=$(awk '
    /^[[:space:]]*(function[[:space:]]+)?test[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^test[a-zA-Z_][a-zA-Z0-9_]*\(\)$/) {
          name = $i
          gsub(/\(\)/, "", name)
          if (++seen[name] == 2) {
            dup[name] = 1
          }
          # Recorded for every occurrence, the first included: the report needs
          # both definitions to be worth anything.
          if (lines[name] == "") {
            lines[name] = FNR
          } else {
            lines[name] = lines[name] ", " FNR
          }
          break
        }
      }
    }
    END {
      n = 0
      for (name in dup) {
        names[++n] = name
      }
      for (i = 2; i <= n; i++) {
        v = names[i]
        j = i - 1
        while (j >= 1 && names[j] > v) {
          names[j + 1] = names[j]
          j--
        }
        names[j + 1] = v
      }
      for (i = 1; i <= n; i++) {
        print names[i] "\t" lines[names[i]]
      }
    }
  ' "$script")
  if [ -n "$duplicates" ]; then
    # Split the "<name>\t<lines>" pairs into the bare names the state has
    # always exposed and the display form the summary prints. The list is one
    # or two entries in practice, so a bash loop costs nothing here.
    local names=""
    local detail=""
    local dup_name dup_lines
    while IFS="$(printf '\t')" read -r dup_name dup_lines; do
      if [ -z "$dup_name" ]; then
        continue
      fi
      names="$names$dup_name
"
      detail="$detail$dup_name (lines $dup_lines)
"
    done <<EOF
$duplicates
EOF
    bashunit::state::set_duplicated_functions_merged \
      "$script" "${names%
}" "${detail%
}"
    return 1
  fi
  return 0
}


##
# Whether a function name matches any --exclude-filter value.
#
# The value is read from BASHUNIT_EXCLUDE_FILTER rather than passed in, so the
# header count (which reaches get_functions_to_run from a subshell) and the
# runner cannot end up applying different selections.
#
# Locals are `__bu_`-prefixed (bash-style.md, PR #672). The only caller is
# get_functions_to_run, and this runs inside its `for fn in ...` loop, so plain
# `fn`/`prefix` locals here would shadow the caller's by dynamic scoping.
#
# Arguments: $1 - function prefix ("test"/"bench"), $2 - function name
# Returns: 0 when the name is excluded, 1 otherwise
##
function bashunit::helper::name_matches_exclude_filter() {
  local __bu_prefix=$1
  local __bu_fn=$2

  if [ -z "${BASHUNIT_EXCLUDE_FILTER:-}" ]; then
    return 1
  fi

  local IFS=','
  local __bu_excl
  for __bu_excl in $BASHUNIT_EXCLUDE_FILTER; do
    __bu_excl=${__bu_excl/test_/}
    if [ -n "$__bu_excl" ]; then
      case "$__bu_fn" in ${__bu_prefix}_*${__bu_excl}*) return 0 ;; esac
    fi
  done

  return 1
}

# Arguments: $1 - eg: "prefix", $2 - eg: "filter", $3 - eg: "[fn1, fn2, prefix_filter_fn3, fn4, ...]"
# Returns: eg: "[prefix_filter_fn3, ...]" The filtered functions with prefix
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
    # --exclude-filter wins over the include filter, mirroring how
    # --exclude-tag beats --tag.
    if [ "$_fn_match" = true ] && bashunit::helper::name_matches_exclude_filter "$prefix" "$fn"; then
      _fn_match=false
    fi
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


function bashunit::helper::find_files_recursive() {
  ## Remove trailing slash using parameter expansion
  local path="${1%%/}"
  local pattern="${2:-*[tT]est.sh}"

  # When the pattern targets *.sh test files, also match the .bash variant. Both
  # the plain `*test.sh` and the default glob `*[tT]est.sh` end in `.sh`; a case
  # match on either (no grep fork) is enough to decide.
  local alt_pattern=""
  case "$pattern" in
  *test.sh | *'[tT]est.sh') alt_pattern="${pattern%.sh}.bash" ;;
  esac

  local _has_glob=false
  case "$path" in *"*"*) _has_glob=true ;; esac
  if [ "$_has_glob" = true ]; then
    # Expand the glob into an array WITHOUT `eval`: setting IFS to the empty
    # string disables field splitting, so the unquoted expansion below performs
    # pathname expansion only. `eval "find $path ..."` also word-split on spaces,
    # which turned "my dir/*" into the two roots "my" and "dir/*". A non-matching
    # glob stays literal (nullglob is off), matching the previous behaviour of
    # handing the unexpanded pattern to find.
    local _old_ifs=$IFS
    IFS=''
    local _roots
    # shellcheck disable=SC2206 # pathname expansion is the point; IFS='' blocks splitting
    _roots=($path)
    IFS=$_old_ifs
    if [ -n "$alt_pattern" ]; then
      find "${_roots[@]}" -type f \( -name "$pattern" -o -name "$alt_pattern" \) | sort -u
    else
      find "${_roots[@]}" -type f -name "$pattern" | sort -u
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

_BASHUNIT_HELPER_VARNAME_OUT=""


function bashunit::helper::find_total_tests() {
  local filter=${1:-}
  shift || true

  _BASHUNIT_HELPER_TOTAL_TESTS_OUT=0
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

    # Build the provider map in THIS shell before the counting subshell: the
    # subshell inherits it (its own build call becomes a cache hit), and when
    # the caller runs in the main shell the runner's later build for the same
    # file is a cache hit too — one awk scan per file instead of two.
    bashunit::helper::build_provider_map "$file"

    local file_count
    file_count=$( (
      # shellcheck source=/dev/null
      source "$file"
      local all_fn_names
      all_fn_names=$(compgen -A function)
      local filtered_functions
      filtered_functions=$(bashunit::helper::get_functions_to_run "test" "$filter" "$all_fn_names") || true

      local count=0
      local IFS=$' \t\n'
      if [ -n "$filtered_functions" ]; then
        local -a functions_to_run=()
        # shellcheck disable=SC2206
        functions_to_run=($filtered_functions)
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

  _BASHUNIT_HELPER_TOTAL_TESTS_OUT=$total_count
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


# Arguments: $1 - function name
# Returns: line number of the function in the source file
#
function bashunit::helper::get_function_line_number() {
  local fn_name=$1

  # Enable extdebug only inside the subshell so the caller's setting is not
  # clobbered. With extdebug, `declare -F` prints "<name> <line> <file>"; parse
  # the line number with shell word-splitting instead of forking awk.
  local declaration
  declaration=$(
    shopt -s extdebug
    declare -F "$fn_name"
  )
  declaration="${declaration#* }"
  echo "${declaration%% *}"
}


#
# Parses a file path that may contain a filter suffix.
# Supports two syntaxes:
#   - path::function_name (filter by function name)
#   - path:line_number (filter by line number)
# Arguments: $1 - eg: "tests/test.sh::test_foo" or "tests/test.sh:123"
# Returns: two lines: first is file path, second is filter (or empty)
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
# Arguments: $1 - file path, $2 - line number
# Returns: the function name, or empty if not found
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

