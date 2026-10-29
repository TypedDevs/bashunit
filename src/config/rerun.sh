#!/usr/bin/env bash

# Shared collectors carry failure and execution identities out of parallel workers.

# Entries loaded for replay: newline-delimited "<file>:<fn>". Empty when none.
_BASHUNIT_RERUN_ENTRIES=""

##
# Path to the persisted cache file. Defaults to ".bashunit/last-failed" under
# the working directory; BASHUNIT_RERUN_CACHE_DIR overrides the directory.
##
function bashunit::rerun::cache_file() {
  echo "${BASHUNIT_RERUN_CACHE_DIR:-.bashunit}/last-failed"
}

function bashunit::rerun::is_enabled() {
  [ "${BASHUNIT_RERUN_FAILED:-false}" = true ]
}

##
# Appends a failed test's raw identity to the collection temp file.
# Arguments: $1 test file path, $2 raw function name.
##
function bashunit::rerun::record() {
  local test_file=$1
  local fn_name=$2
  [ -n "${RERUN_FAILED_OUTPUT_PATH:-}" ] || return 0
  printf '%s:%s\n' "$test_file" "$fn_name" >>"$RERUN_FAILED_OUTPUT_PATH" 2>/dev/null || true
}

function bashunit::rerun::record_ran() {
  local test_file=$1
  local fn_name=$2
  [ -n "${RERUN_RAN_OUTPUT_PATH:-}" ] || return 0
  builtin printf '%s:%s\n' "$test_file" "$fn_name" 2>/dev/null >>"$RERUN_RAN_OUTPUT_PATH" || true
}

function bashunit::rerun::persist() {
  local cache previous=""
  cache="$(bashunit::rerun::cache_file)"
  local collected="${RERUN_FAILED_OUTPUT_PATH:-}"
  local ran="${RERUN_RAN_OUTPUT_PATH:-}"

  if [ -f "$cache" ]; then
    previous=$(<"$cache")
  fi
  if [ -z "$previous" ] && [ ! -s "$collected" ]; then
    return 0
  fi
  if [ "${_BASHUNIT_RERUN_FULL_RUN:-false}" = true ] &&
    [ "${1:-1}" -eq 0 ] && [ -s "$ran" ] && [ ! -s "$collected" ]; then
    : 2>/dev/null >"$cache" || true
    return 0
  fi
  if [ ! -f "$ran" ]; then
    ran=/dev/null
  fi
  if [ ! -f "$collected" ]; then
    collected=/dev/null
  fi
  local dir="${cache%/*}"
  if [ "$dir" != "$cache" ]; then
    mkdir -p "$dir" 2>/dev/null || return 0
  fi

  _BASHUNIT_RERUN_WORKING_DIR="${BASHUNIT_WORKING_DIR:-$PWD}" awk '
    BEGIN {
      working_dir = ENVIRON["_BASHUNIT_RERUN_WORKING_DIR"]
      sub(/\/$/, "", working_dir)
    }
    function entry_key(entry) {
      while (substr(entry, 1, 2) == "./") entry = substr(entry, 3)
      if (substr(entry, 1, 1) != "/") entry = working_dir "/" entry
      return entry
    }
    FILENAME == ARGV[1] { ran[entry_key($0)] = 1; next }
    FILENAME == ARGV[2] && (entry_key($0) in ran) { next }
    NF && !seen[$0]++ { print }
  ' "$ran" - "$collected" 2>/dev/null >"$cache" <<EOF || true
$previous
EOF
}

##
# Loads the cache into _BASHUNIT_RERUN_ENTRIES (empty when the cache is absent).
##
function bashunit::rerun::load() {
  local cache
  cache="$(bashunit::rerun::cache_file)"
  _BASHUNIT_RERUN_ENTRIES=""
  [ -f "$cache" ] || return 0
  _BASHUNIT_RERUN_ENTRIES="$(cat "$cache" 2>/dev/null)"
}

function bashunit::rerun::has_entries() {
  [ -n "$_BASHUNIT_RERUN_ENTRIES" ]
}

##
# Echoes the distinct test files from the loaded entries (first-seen order).
##
function bashunit::rerun::files() {
  [ -n "$_BASHUNIT_RERUN_ENTRIES" ] || return 0
  printf '%s\n' "$_BASHUNIT_RERUN_ENTRIES" | awk '
    NF {
      file = $0
      sub(/:[^:]*$/, "", file)
      if (!seen[file]++) print file
    }'
}

##
# Returns 0 when "<file>:<fn>" is among the loaded entries.
##
function bashunit::rerun::allows() {
  local file=$1
  local fn=$2
  case "
$_BASHUNIT_RERUN_ENTRIES
" in
  *"
$file:$fn
"*) return 0 ;;
  esac
  return 1
}

##
# Echoes the given test files with the recorded ones first, in the order the
# cache holds them, then the rest in their given order.
#
# Reordering, not filtering: --order-by defects still runs the whole suite, it
# just puts the known-bad files where --stop-on-failure trips on them first.
# Arguments: $@ test file paths.
##
function bashunit::rerun::order_files() {
  local recorded_files
  recorded_files="$(bashunit::rerun::files)"
  if [ -z "$recorded_files" ]; then
    [ "$#" -gt 0 ] && printf '%s\n' "$@"
    return 0
  fi

  local file recorded
  # A recorded file the current selection does not contain is skipped, so a
  # deleted or filtered-out file cannot resurrect itself through the cache.
  while IFS= read -r recorded; do
    [ -z "$recorded" ] && continue
    for file in "$@"; do
      if [ "$file" = "$recorded" ]; then
        printf '%s\n' "$file"
        break
      fi
    done
  done <<EOF
$recorded_files
EOF

  for file in "$@"; do
    case "
$recorded_files
" in
    *"
$file
"*) ;;
    *) printf '%s\n' "$file" ;;
    esac
  done
}

##
# Echoes a space-separated function list reordered so the ones recorded for the
# file come first, in the order the cache holds them.
# Arguments: $1 test file path, $2 space-separated function names.
##
function bashunit::rerun::order_functions() {
  local file=$1
  local functions=$2
  local ordered=""
  local entry recorded_fn fn

  while IFS= read -r entry; do
    case "$entry" in
    "$file":*) recorded_fn="${entry#"$file":}" ;;
    *) continue ;;
    esac
    for fn in $functions; do
      if [ "$fn" = "$recorded_fn" ]; then
        ordered="$ordered $fn"
        break
      fi
    done
  done <<EOF
$_BASHUNIT_RERUN_ENTRIES
EOF

  for fn in $functions; do
    if ! bashunit::rerun::allows "$file" "$fn"; then
      ordered="$ordered $fn"
    fi
  done

  echo "${ordered# }"
}

##
# Filters a space-separated function list down to the ones recorded for a file.
# Arguments: $1 test file path, $2 space-separated function names.
##
function bashunit::rerun::filter_functions() {
  local file=$1
  local functions=$2
  local kept=""
  local fn
  for fn in $functions; do
    if bashunit::rerun::allows "$file" "$fn"; then
      kept="$kept $fn"
    fi
  done
  echo "${kept# }"
}
