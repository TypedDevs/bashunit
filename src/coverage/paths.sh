#!/usr/bin/env bash

# Which files coverage tracks, and the hot-path caches behind that decision.

# In-memory lookups for the hot paths.
#
# These used to be one long string per cache, scanned with a leading-`*` glob.
# That scan is quadratic in the number of entries on Bash 3.2: measured at
# 0.38ms per lookup at 11 entries, 3.4ms at 40 and 26.7ms at 121 -- the cache
# cost more than the work it replaced (#1056).
#
# Bash's own variable table is the associative array this repo cannot declare,
# the same trick the spy state uses (_BASHUNIT_SPY_${variable}_TIMES_FILE).
# The key is the path with everything but [a-zA-Z0-9] collapsed to `_`, so two
# different paths can produce the same key; the original path is stored beside
# the value and compared on read, which makes a collision a miss rather than a
# wrong answer.
_BASHUNIT_COVERAGE_LOOKUP_OUT=""

_BASHUNIT_COVERAGE_LOOKUP_KEY_OUT=""

##
# The variable-name-safe key for a path, into
# _BASHUNIT_COVERAGE_LOOKUP_KEY_OUT.
#
# A return slot, not a `$(...)`: lookup_get runs once per traced line on the
# capture path, and a command substitution there would be a fork per line --
# exactly what the fork budget forbids.
# Arguments: $1 - namespace prefix, $2 - path
##
function bashunit::coverage::lookup_key_to_slot() {
  _BASHUNIT_COVERAGE_LOOKUP_KEY_OUT="$1${2//[^a-zA-Z0-9]/_}"
}

##
# Stores a value under a path key.
# Arguments: $1 - namespace prefix, $2 - path, $3 - value
##
function bashunit::coverage::lookup_put() {
  bashunit::coverage::lookup_key_to_slot "$1" "$2"
  local key=$_BASHUNIT_COVERAGE_LOOKUP_KEY_OUT
  eval "${key}_PATH=\$2"
  eval "${key}_VALUE=\$3"
}

##
# Reads the value stored for a path into _BASHUNIT_COVERAGE_LOOKUP_OUT.
# Returns 1 when absent, or when the slot holds a different path (a key
# collision, which must read as a miss).
# Arguments: $1 - namespace prefix, $2 - path
##
function bashunit::coverage::lookup_get() {
  bashunit::coverage::lookup_key_to_slot "$1" "$2"
  local path_var="${_BASHUNIT_COVERAGE_LOOKUP_KEY_OUT}_PATH"
  local value_var="${_BASHUNIT_COVERAGE_LOOKUP_KEY_OUT}_VALUE"

  _BASHUNIT_COVERAGE_LOOKUP_OUT=""
  if [ "${!path_var:-}" != "$2" ]; then
    return 1
  fi
  _BASHUNIT_COVERAGE_LOOKUP_OUT="${!value_var:-}"
  return 0
}

##
# Drops every entry of one namespace, so a second run in the same shell cannot
# inherit a stale decision.
# Arguments: $1 - namespace prefix
##
function bashunit::coverage::reset_lookup_namespace() {
  local name
  for name in $(compgen -v "$1" 2>/dev/null || true); do
    unset "$name"
  done
}

# Normalize file path to absolute
function bashunit::coverage::normalize_path() {
  local file="$1"

  # Normalize path to absolute
  if [ -f "$file" ]; then
    echo "$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
  else
    echo "$file"
  fi
}

# Get deduplicated list of tracked files
function bashunit::coverage::get_tracked_files() {
  if [ ! -f "$_BASHUNIT_COVERAGE_TRACKED_FILES" ]; then
    return
  fi
  sort -u "$_BASHUNIT_COVERAGE_TRACKED_FILES"
}

function bashunit::coverage::should_track() {
  local file="$1"

  # Skip empty paths
  [ -z "$file" ] && return 1

  # Skip if tracked files list doesn't exist (trap inherited by child process)
  [ -z "$_BASHUNIT_COVERAGE_TRACKED_FILES" ] && return 1

  # Check file-based cache for previous decision (Bash 3.0 compatible)
  # Cache format: "file:0" for excluded, "file:1" for tracked
  # In parallel mode, use per-process cache to avoid race conditions
  local cache_file="$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
  if bashunit::parallel::is_enabled && [ -n "$cache_file" ]; then
    cache_file="${cache_file}.$$"
    # Initialize per-process cache if needed
    [ ! -f "$cache_file" ] && [ -d "$(dirname "$cache_file")" ] && : >"$cache_file"
  fi
  if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
    local cached_decision
    # Use || true to prevent exit in strict mode when grep finds no match
    cached_decision=$(grep "^${file}:" "$cache_file" 2>/dev/null | head -1) || true
    if [ -n "$cached_decision" ]; then
      [ "${cached_decision##*:}" = "1" ] && return 0 || return 1
    fi
  fi

  # Normalize path
  local normalized_file
  normalized_file=$(bashunit::coverage::normalize_path "$file")

  # Check exclusion patterns
  # Save and restore IFS to avoid corrupting caller's environment
  local old_ifs="$IFS"
  IFS=','
  local pattern
  for pattern in $BASHUNIT_COVERAGE_EXCLUDE; do
    case "$normalized_file" in
    *$pattern*)
      IFS="$old_ifs"
      # Cache exclusion decision (use per-process cache in parallel mode)
      { [ -n "$cache_file" ] && [ -f "$cache_file" ]; } && echo "${file}:0" >>"$cache_file"
      return 1
      ;;
    esac
  done

  # Check inclusion paths
  local matched=false
  local path
  for path in $BASHUNIT_COVERAGE_PATHS; do
    # Resolve relative paths
    local resolved_path
    case "$path" in
    /*)
      resolved_path="$path"
      ;;
    *)
      resolved_path="$(pwd)/$path"
      ;;
    esac

    case "$normalized_file" in
    "$resolved_path"*)
      matched=true
      break
      ;;
    esac
  done
  IFS="$old_ifs"

  if [ "$matched" = "false" ]; then
    # Cache exclusion decision (use per-process cache in parallel mode)
    { [ -n "$cache_file" ] && [ -f "$cache_file" ]; } && echo "${file}:0" >>"$cache_file"
    return 1
  fi

  # Cache tracking decision (use per-process cache in parallel mode)
  { [ -n "$cache_file" ] && [ -f "$cache_file" ]; } && echo "${file}:1" >>"$cache_file"

  # Track this file for later reporting
  # In parallel mode, use a per-process file to avoid race conditions
  local tracked_file="$_BASHUNIT_COVERAGE_TRACKED_FILES"
  if bashunit::parallel::is_enabled; then
    tracked_file="${_BASHUNIT_COVERAGE_TRACKED_FILES}.$$"
  fi

  # Only write if parent directory exists
  if [ -d "$(dirname "$tracked_file")" ]; then
    # Check if not already written to avoid duplicates
    if ! grep -q "^${normalized_file}$" "$tracked_file" 2>/dev/null; then
      echo "$normalized_file" >>"$tracked_file"
    fi
  fi

  return 0
}

# Convert file path to safe filename for HTML
function bashunit::coverage::path_to_filename() {
  local file="$1"
  local display_file="${file#"$(pwd)"/}"
  # Replace / with _ and . with _
  local safe_name="${display_file//\//_}"
  echo "${safe_name//./_}"
}
