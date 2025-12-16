#!/usr/bin/env bash

# Coverage data storage
_BASHUNIT_COVERAGE_DATA_FILE=""
_BASHUNIT_COVERAGE_TRACKED_FILES=""

# Simple file-based cache for tracked files (Bash 3.2 compatible)
# The tracked cache file stores files that have already been processed
_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE=""

function bashunit::coverage::init() {
  if ! bashunit::env::is_coverage_enabled; then
    return 0
  fi

  # Create coverage data directory
  local coverage_dir
  coverage_dir="${BASHUNIT_TEMP_DIR:-/tmp}/bashunit-coverage-$$"
  mkdir -p "$coverage_dir"

  _BASHUNIT_COVERAGE_DATA_FILE="${coverage_dir}/hits.dat"
  _BASHUNIT_COVERAGE_TRACKED_FILES="${coverage_dir}/files.dat"
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE="${coverage_dir}/cache.dat"

  # Initialize empty files
  : > "$_BASHUNIT_COVERAGE_DATA_FILE"
  : > "$_BASHUNIT_COVERAGE_TRACKED_FILES"
  : > "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"

  export _BASHUNIT_COVERAGE_DATA_FILE
  export _BASHUNIT_COVERAGE_TRACKED_FILES
  export _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE
}

function bashunit::coverage::enable_trap() {
  if ! bashunit::env::is_coverage_enabled; then
    return 0
  fi

  # Enable trap inheritance into functions
  set -T

  # Set DEBUG trap to record line execution
  # Use ${VAR:-} to handle unset variables when set -u is active (in subshells)
  # shellcheck disable=SC2154
  trap 'bashunit::coverage::record_line "${BASH_SOURCE:-}" "${LINENO:-}"' DEBUG
}

function bashunit::coverage::disable_trap() {
  trap - DEBUG
  set +T
}

# Normalize file path to absolute
function bashunit::coverage::normalize_path() {
  local file="$1"

  # Normalize path to absolute
  if [[ -f "$file" ]]; then
    echo "$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
  else
    echo "$file"
  fi
}

function bashunit::coverage::record_line() {
  local file="$1"
  local lineno="$2"

  # Skip if no file or line
  [[ -z "$file" || -z "$lineno" ]] && return 0

  # Skip if coverage data file doesn't exist (trap inherited by child process)
  [[ -z "$_BASHUNIT_COVERAGE_DATA_FILE" ]] && return 0

  # Skip if not tracking this file (uses cache internally)
  bashunit::coverage::should_track "$file" || return 0

  # Normalize file path using cache (must match tracked_files for hit counting)
  local normalized_file
  normalized_file=$(bashunit::coverage::normalize_path "$file")

  # In parallel mode, use a per-process file to avoid race conditions
  local data_file="$_BASHUNIT_COVERAGE_DATA_FILE"
  if bashunit::parallel::is_enabled; then
    data_file="${_BASHUNIT_COVERAGE_DATA_FILE}.$$"
  fi

  # Record the hit (only if parent directory exists)
  [[ -d "$(dirname "$data_file")" ]] && echo "${normalized_file}:${lineno}" >> "$data_file"
}

function bashunit::coverage::should_track() {
  local file="$1"

  # Skip empty paths
  [[ -z "$file" ]] && return 1

  # Skip if tracked files list doesn't exist (trap inherited by child process)
  [[ -z "$_BASHUNIT_COVERAGE_TRACKED_FILES" ]] && return 1

  # Check file-based cache for previous decision (Bash 3.2 compatible)
  # Cache format: "file:0" for excluded, "file:1" for tracked
  if [[ -n "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE" && -f "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE" ]]; then
    local cached_decision
    # Use || true to prevent exit in strict mode when grep finds no match
    cached_decision=$(grep "^${file}:" "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE" 2>/dev/null | head -1) || true
    if [[ -n "$cached_decision" ]]; then
      [[ "${cached_decision##*:}" == "1" ]] && return 0 || return 1
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
        # Cache exclusion decision
        [[ -n "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE" ]] && \
          echo "${file}:0" >> "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
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
    if [[ "$path" == /* ]]; then
      resolved_path="$path"
    else
      resolved_path="$(pwd)/$path"
    fi

    if [[ "$normalized_file" == "$resolved_path"* ]]; then
      matched=true
      break
    fi
  done
  IFS="$old_ifs"

  if [[ "$matched" == "false" ]]; then
    # Cache exclusion decision
    [[ -n "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE" ]] && \
      echo "${file}:0" >> "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
    return 1
  fi

  # Cache tracking decision
  [[ -n "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE" ]] && \
    echo "${file}:1" >> "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"

  # Track this file for later reporting
  # In parallel mode, use a per-process file to avoid race conditions
  local tracked_file="$_BASHUNIT_COVERAGE_TRACKED_FILES"
  if bashunit::parallel::is_enabled; then
    tracked_file="${_BASHUNIT_COVERAGE_TRACKED_FILES}.$$"
  fi

  # Only write if parent directory exists
  if [[ -d "$(dirname "$tracked_file")" ]]; then
    # Check if not already written to avoid duplicates
    if ! grep -q "^${normalized_file}$" "$tracked_file" 2>/dev/null; then
      echo "$normalized_file" >> "$tracked_file"
    fi
  fi

  return 0
}

function bashunit::coverage::aggregate_parallel() {
  # Aggregate per-process coverage files created during parallel execution
  local base_file="$_BASHUNIT_COVERAGE_DATA_FILE"
  local tracked_base="$_BASHUNIT_COVERAGE_TRACKED_FILES"

  # Find and merge all per-process coverage data files
  # Use nullglob to handle case when no files match
  local pid_files
  pid_files=$(ls -1 "${base_file}."* 2>/dev/null) || true
  if [[ -n "$pid_files" ]]; then
    while IFS= read -r pid_file; do
      [[ -f "$pid_file" ]] || continue
      cat "$pid_file" >> "$base_file"
      rm -f "$pid_file"
    done <<< "$pid_files"
  fi

  # Find and merge all per-process tracked files lists
  pid_files=$(ls -1 "${tracked_base}."* 2>/dev/null) || true
  if [[ -n "$pid_files" ]]; then
    while IFS= read -r pid_file; do
      [[ -f "$pid_file" ]] || continue
      cat "$pid_file" >> "$tracked_base"
      rm -f "$pid_file"
    done <<< "$pid_files"
  fi

  # Deduplicate tracked files
  if [[ -f "$tracked_base" ]]; then
    sort -u "$tracked_base" -o "$tracked_base"
  fi
}

# Pre-compiled regex pattern for function declarations (performance optimization)
# Matches: function foo() { OR foo() { OR function foo() OR foo()
# Does NOT match single-line functions with body: function foo() { echo "hi"; }
_BASHUNIT_COVERAGE_FUNC_PATTERN='^[[:space:]]*(function[[:space:]]+)?'
_BASHUNIT_COVERAGE_FUNC_PATTERN+='[a-zA-Z_][a-zA-Z0-9_:]*[[:space:]]*\(\)[[:space:]]*\{?[[:space:]]*$'

# Check if a line is executable (used by get_executable_lines and report_lcov)
# Arguments: line content, line number
# Returns: 0 if executable, 1 if not
function bashunit::coverage::is_executable_line() {
  local line="$1"
  local lineno="$2"

  # Skip empty lines (line with only whitespace)
  [[ -z "${line// }" ]] && return 1

  # Skip comment-only lines (but not shebang on line 1)
  if [[ "$line" =~ ^[[:space:]]*# ]] && [[ $lineno -ne 1 ]]; then
    return 1
  fi

  # Skip function declaration lines (but not single-line functions with body)
  [[ "$line" =~ $_BASHUNIT_COVERAGE_FUNC_PATTERN ]] && return 1

  # Skip lines with only braces
  [[ "$line" =~ ^[[:space:]]*[\{\}][[:space:]]*$ ]] && return 1

  return 0
}

function bashunit::coverage::get_executable_lines() {
  local file="$1"
  local count=0
  local lineno=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    ((lineno++))
    bashunit::coverage::is_executable_line "$line" "$lineno" && ((count++))
  done < "$file"

  echo "$count"
}

function bashunit::coverage::get_hit_lines() {
  local file="$1"

  if [[ ! -f "$_BASHUNIT_COVERAGE_DATA_FILE" ]]; then
    echo "0"
    return
  fi

  # Count unique lines hit for this file
  # Use subshell with || echo 0 to handle no matches gracefully in strict mode
  (grep "^${file}:" "$_BASHUNIT_COVERAGE_DATA_FILE" 2>/dev/null || true) | \
    cut -d: -f2 | sort -u | wc -l | tr -d ' '
}

function bashunit::coverage::get_line_hits() {
  local file="$1"
  local lineno="$2"

  if [[ ! -f "$_BASHUNIT_COVERAGE_DATA_FILE" ]]; then
    echo "0"
    return
  fi

  local count
  count=$(grep -c "^${file}:${lineno}$" "$_BASHUNIT_COVERAGE_DATA_FILE" 2>/dev/null) || count=0
  echo "$count"
}

function bashunit::coverage::get_percentage() {
  local total_executable=0
  local total_hit=0

  # Check if tracked files exist
  if [[ ! -f "$_BASHUNIT_COVERAGE_TRACKED_FILES" ]]; then
    echo "0"
    return
  fi

  while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue

    local executable
    executable=$(bashunit::coverage::get_executable_lines "$file")
    local hit
    hit=$(bashunit::coverage::get_hit_lines "$file")

    ((total_executable += executable))
    ((total_hit += hit))
  done < "$_BASHUNIT_COVERAGE_TRACKED_FILES"

  if [[ $total_executable -eq 0 ]]; then
    echo "0"
    return
  fi

  # Calculate percentage (integer)
  echo $((total_hit * 100 / total_executable))
}

function bashunit::coverage::report_text() {
  if ! bashunit::env::is_coverage_enabled; then
    return 0
  fi

  local total_executable=0
  local total_hit=0

  echo ""
  echo "Coverage Report"
  echo "---------------"

  # Check if tracked files exist
  if [[ ! -f "$_BASHUNIT_COVERAGE_TRACKED_FILES" ]]; then
    echo "---------------"
    echo "Total: 0/0 (0%)"
    return 0
  fi

  while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue

    local executable
    executable=$(bashunit::coverage::get_executable_lines "$file")
    local hit
    hit=$(bashunit::coverage::get_hit_lines "$file")

    ((total_executable += executable))
    ((total_hit += hit))

    # Calculate percentage
    local pct=0
    if [[ $executable -gt 0 ]]; then
      pct=$((hit * 100 / executable))
    fi

    # Determine color based on thresholds
    local color=""
    local reset=""
    if [[ "${BASHUNIT_NO_COLOR:-false}" != "true" ]]; then
      reset=$'\033[0m'
      if [[ $pct -lt ${BASHUNIT_COVERAGE_THRESHOLD_LOW:-50} ]]; then
        color=$'\033[31m'  # Red
      elif [[ $pct -lt ${BASHUNIT_COVERAGE_THRESHOLD_HIGH:-80} ]]; then
        color=$'\033[33m'  # Yellow
      else
        color=$'\033[32m'  # Green
      fi
    fi

    # Display relative path
    local display_file
    display_file="${file#"$(pwd)"/}"

    printf "%s%-40s %3d/%3d lines (%3d%%)%s\n" \
      "$color" "$display_file" "$hit" "$executable" "$pct" "$reset"
  done < "$_BASHUNIT_COVERAGE_TRACKED_FILES"

  echo "---------------"

  # Total
  local total_pct=0
  if [[ $total_executable -gt 0 ]]; then
    total_pct=$((total_hit * 100 / total_executable))
  fi

  local color=""
  local reset=""
  if [[ "${BASHUNIT_NO_COLOR:-false}" != "true" ]]; then
    reset=$'\033[0m'
    if [[ $total_pct -lt ${BASHUNIT_COVERAGE_THRESHOLD_LOW:-50} ]]; then
      color=$'\033[31m'
    elif [[ $total_pct -lt ${BASHUNIT_COVERAGE_THRESHOLD_HIGH:-80} ]]; then
      color=$'\033[33m'
    else
      color=$'\033[32m'
    fi
  fi

  printf "%sTotal: %d/%d (%d%%)%s\n" \
    "$color" "$total_hit" "$total_executable" "$total_pct" "$reset"

  # Show report location if generated
  if [[ -n "$BASHUNIT_COVERAGE_REPORT" ]]; then
    echo ""
    echo "Coverage report written to: $BASHUNIT_COVERAGE_REPORT"
  fi
}

function bashunit::coverage::report_lcov() {
  local output_file="${1:-$BASHUNIT_COVERAGE_REPORT}"

  if [[ -z "$output_file" ]]; then
    return 0
  fi

  # Create output directory if needed
  local output_dir
  output_dir=$(dirname "$output_file")
  mkdir -p "$output_dir"

  # Check if tracked files exist - if not, write empty LCOV file
  if [[ ! -f "$_BASHUNIT_COVERAGE_TRACKED_FILES" ]]; then
    echo "TN:" > "$output_file"
    return 0
  fi

  # Generate LCOV format
  {
    echo "TN:"

    while IFS= read -r file; do
      [[ -z "$file" || ! -f "$file" ]] && continue

      echo "SF:$file"

      local lineno=0
      # shellcheck disable=SC2094
      while IFS= read -r line || [[ -n "$line" ]]; do
        ((lineno++))

        # Skip non-executable lines (use shared helper)
        bashunit::coverage::is_executable_line "$line" "$lineno" || continue

        # Get hit count for this line
        local hits
        hits=$(bashunit::coverage::get_line_hits "$file" "$lineno")

        echo "DA:${lineno},${hits}"
      done < "$file"

      local executable
      executable=$(bashunit::coverage::get_executable_lines "$file")
      local hit
      hit=$(bashunit::coverage::get_hit_lines "$file")

      echo "LF:$executable"
      echo "LH:$hit"
      echo "end_of_record"
    done < "$_BASHUNIT_COVERAGE_TRACKED_FILES"
  } > "$output_file"
}

function bashunit::coverage::check_threshold() {
  if [[ -z "$BASHUNIT_COVERAGE_MIN" ]]; then
    return 0
  fi

  local pct
  pct=$(bashunit::coverage::get_percentage)

  if [[ $pct -lt $BASHUNIT_COVERAGE_MIN ]]; then
    local color=""
    local reset=""
    if [[ "${BASHUNIT_NO_COLOR:-false}" != "true" ]]; then
      color=$'\033[31m'
      reset=$'\033[0m'
    fi
    printf "%sCoverage %d%% is below minimum %d%%%s\n" \
      "$color" "$pct" "$BASHUNIT_COVERAGE_MIN" "$reset"
    return 1
  fi

  return 0
}

function bashunit::coverage::cleanup() {
  if [[ -n "$_BASHUNIT_COVERAGE_DATA_FILE" ]]; then
    local coverage_dir
    coverage_dir=$(dirname "$_BASHUNIT_COVERAGE_DATA_FILE")
    rm -rf "$coverage_dir"
  fi
}
