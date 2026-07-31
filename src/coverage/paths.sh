#!/usr/bin/env bash

# Which files coverage tracks, and the hot-path caches behind that decision.

# In-memory caches for hot-path lookups (avoids grep + subshells)
_BASHUNIT_COVERAGE_TRACK_CACHE=""
_BASHUNIT_COVERAGE_PATH_CACHE=""

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
    # shellcheck disable=SC2254
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
