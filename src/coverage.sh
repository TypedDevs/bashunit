#!/usr/bin/env bash

# Coverage data storage
_BASHUNIT_COVERAGE_DATA_FILE=""
_BASHUNIT_COVERAGE_TRACKED_FILES=""

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

  # Initialize empty files
  : > "$_BASHUNIT_COVERAGE_DATA_FILE"
  : > "$_BASHUNIT_COVERAGE_TRACKED_FILES"

  export _BASHUNIT_COVERAGE_DATA_FILE
  export _BASHUNIT_COVERAGE_TRACKED_FILES
}

function bashunit::coverage::enable_trap() {
  if ! bashunit::env::is_coverage_enabled; then
    return 0
  fi

  # Enable trap inheritance into functions
  set -T

  # Set DEBUG trap to record line execution
  # shellcheck disable=SC2154
  trap 'bashunit::coverage::record_line "$BASH_SOURCE" "$LINENO"' DEBUG
}

function bashunit::coverage::disable_trap() {
  trap - DEBUG
  set +T
}

function bashunit::coverage::record_line() {
  local file="$1"
  local lineno="$2"

  # Skip if no file or line
  [[ -z "$file" || -z "$lineno" ]] && return 0

  # Skip if not tracking this file
  bashunit::coverage::should_track "$file" || return 0

  # Record the hit
  echo "${file}:${lineno}" >> "$_BASHUNIT_COVERAGE_DATA_FILE"
}

function bashunit::coverage::should_track() {
  local file="$1"

  # Skip empty paths
  [[ -z "$file" ]] && return 1

  # Normalize path
  local normalized_file
  if [[ -f "$file" ]]; then
    normalized_file=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")
  else
    normalized_file="$file"
  fi

  # Skip bashunit's own source files
  if [[ "$normalized_file" == *"/bashunit/src/"* ]]; then
    return 1
  fi

  # Check exclusion patterns
  local IFS=','
  for pattern in $BASHUNIT_COVERAGE_EXCLUDE; do
    # shellcheck disable=SC2254
    case "$normalized_file" in
      *$pattern*) return 1 ;;
    esac
  done

  # Check inclusion paths
  local matched=false
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

  if [[ "$matched" == "false" ]]; then
    return 1
  fi

  # Track this file for later reporting
  if ! grep -q "^${normalized_file}$" "$_BASHUNIT_COVERAGE_TRACKED_FILES" 2>/dev/null; then
    echo "$normalized_file" >> "$_BASHUNIT_COVERAGE_TRACKED_FILES"
  fi

  return 0
}

function bashunit::coverage::aggregate() {
  local parallel_dir="${1:-}"

  if [[ -n "$parallel_dir" && -d "$parallel_dir" ]]; then
    # Merge all coverage data from parallel runs
    find "$parallel_dir" -name "hits.dat" -exec cat {} \; >> "$_BASHUNIT_COVERAGE_DATA_FILE"
    find "$parallel_dir" -name "files.dat" -exec cat {} \; | sort -u >> "$_BASHUNIT_COVERAGE_TRACKED_FILES"
  fi
}

function bashunit::coverage::get_executable_lines() {
  local file="$1"
  local count=0
  local lineno=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    ((lineno++))

    # Skip empty lines
    [[ -z "${line// }" ]] && continue

    # Skip comment-only lines (but not shebang on line 1)
    if [[ "$line" =~ ^[[:space:]]*# ]] && [[ $lineno -ne 1 ]]; then
      continue
    fi

    # Skip function declaration lines
    [[ "$line" =~ ^[[:space:]]*(function[[:space:]]+)?[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\) ]] && continue

    # Skip lines with only braces
    [[ "$line" =~ ^[[:space:]]*[\{\}][[:space:]]*$ ]] && continue

    ((count++))
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
  grep "^${file}:" "$_BASHUNIT_COVERAGE_DATA_FILE" 2>/dev/null | \
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
    display_file="${file#$(pwd)/}"

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

  # Generate LCOV format
  {
    echo "TN:"

    while IFS= read -r file; do
      [[ -z "$file" || ! -f "$file" ]] && continue

      echo "SF:$file"

      local lineno=0
      while IFS= read -r line || [[ -n "$line" ]]; do
        ((lineno++))

        # Skip non-executable lines
        [[ -z "${line// }" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && [[ $lineno -ne 1 ]] && continue
        [[ "$line" =~ ^[[:space:]]*(function[[:space:]]+)?[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\) ]] && continue
        [[ "$line" =~ ^[[:space:]]*[\{\}][[:space:]]*$ ]] && continue

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
