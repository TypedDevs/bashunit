#!/usr/bin/env bash

# Coverage percentages, the precomputed per-file stats cache and the threshold gate.

# Get coverage class (high/medium/low) based on percentage
function bashunit::coverage::get_coverage_class() {
  local pct="$1"
  if [ "$pct" -ge "${BASHUNIT_COVERAGE_THRESHOLD_HIGH:-$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_HIGH}" ]; then
    echo "high"
  elif [ "$pct" -ge "${BASHUNIT_COVERAGE_THRESHOLD_LOW:-$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_LOW}" ]; then
    echo "medium"
  else
    echo "low"
  fi
}

function bashunit::coverage::get_color_for_class() {
  case "$1" in
  high) printf '%s' "$_BASHUNIT_COLOR_PASSED" ;;
  medium) printf '%s' "$_BASHUNIT_COLOR_SKIPPED" ;;
  low) printf '%s' "$_BASHUNIT_COLOR_FAILED" ;;
  esac
}

# Calculate percentage from hit and executable counts
function bashunit::coverage::calculate_percentage() {
  local hit="$1"
  local executable="$2"
  if [ "$executable" -gt 0 ]; then
    echo $((hit * 100 / executable))
  else
    echo "0"
  fi
}

# Return slots for bashunit::coverage::_compute_file_stats.
_BASHUNIT_COVERAGE_FILE_STATS_EXEC_OUT=""
_BASHUNIT_COVERAGE_FILE_STATS_HIT_OUT=""
_BASHUNIT_COVERAGE_FILE_STATS_PCT_OUT=""
_BASHUNIT_COVERAGE_FILE_STATS_CLASS_OUT=""

# Computes one file's executable/hit/pct/class into the four slots above.
# Shared by get_file_stats and precompute_file_stats so the two cannot drift
# on how compute_file_coverage's "executable:hit" string is parsed or how
# pct/class are derived from it.
function bashunit::coverage::_compute_file_stats() {
  local file="$1"
  local stats
  stats=$(bashunit::coverage::compute_file_coverage "$file")
  _BASHUNIT_COVERAGE_FILE_STATS_EXEC_OUT="${stats%%:*}"
  _BASHUNIT_COVERAGE_FILE_STATS_HIT_OUT="${stats##*:}"
  _BASHUNIT_COVERAGE_FILE_STATS_PCT_OUT=$(bashunit::coverage::calculate_percentage \
    "$_BASHUNIT_COVERAGE_FILE_STATS_HIT_OUT" "$_BASHUNIT_COVERAGE_FILE_STATS_EXEC_OUT")
  _BASHUNIT_COVERAGE_FILE_STATS_CLASS_OUT=$(bashunit::coverage::get_coverage_class \
    "$_BASHUNIT_COVERAGE_FILE_STATS_PCT_OUT")
}

# Get file coverage stats as "executable:hit:pct:class"
function bashunit::coverage::get_file_stats() {
  bashunit::coverage::_compute_file_stats "$1"
  echo "${_BASHUNIT_COVERAGE_FILE_STATS_EXEC_OUT}:${_BASHUNIT_COVERAGE_FILE_STATS_HIT_OUT}:\
${_BASHUNIT_COVERAGE_FILE_STATS_PCT_OUT}:${_BASHUNIT_COVERAGE_FILE_STATS_CLASS_OUT}"
}


# Pre-computed file stats cache (avoids redundant per-file reads across reports)
_BASHUNIT_COVERAGE_STATS_FILES=()
_BASHUNIT_COVERAGE_STATS_EXEC=()
_BASHUNIT_COVERAGE_STATS_HIT=()
_BASHUNIT_COVERAGE_STATS_PCT=()
_BASHUNIT_COVERAGE_STATS_CLASS=()
_BASHUNIT_COVERAGE_STATS_COUNT=0


# Pre-compute stats for all tracked files (call once before reports)
function bashunit::coverage::precompute_file_stats() {
  _BASHUNIT_COVERAGE_STATS_FILES=()
  _BASHUNIT_COVERAGE_STATS_EXEC=()
  _BASHUNIT_COVERAGE_STATS_HIT=()
  _BASHUNIT_COVERAGE_STATS_PCT=()
  _BASHUNIT_COVERAGE_STATS_CLASS=()
  _BASHUNIT_COVERAGE_STATS_COUNT=0
  bashunit::coverage::reset_lookup_namespace "_BASHUNIT_COVLOOKUP_STATS_"

  local file
  while IFS= read -r file; do
    { [ -z "$file" ] || [ ! -f "$file" ]; } && continue

    bashunit::coverage::_compute_file_stats "$file"

    local idx="$_BASHUNIT_COVERAGE_STATS_COUNT"
    _BASHUNIT_COVERAGE_STATS_FILES[idx]="$file"
    _BASHUNIT_COVERAGE_STATS_EXEC[idx]="$_BASHUNIT_COVERAGE_FILE_STATS_EXEC_OUT"
    _BASHUNIT_COVERAGE_STATS_HIT[idx]="$_BASHUNIT_COVERAGE_FILE_STATS_HIT_OUT"
    _BASHUNIT_COVERAGE_STATS_PCT[idx]="$_BASHUNIT_COVERAGE_FILE_STATS_PCT_OUT"
    _BASHUNIT_COVERAGE_STATS_CLASS[idx]="$_BASHUNIT_COVERAGE_FILE_STATS_CLASS_OUT"
    _BASHUNIT_COVERAGE_STATS_COUNT=$((idx + 1))
    bashunit::coverage::lookup_put "_BASHUNIT_COVLOOKUP_STATS_" "$file" "$idx"
  done < <(bashunit::coverage::get_tracked_files)
}

# Look up cached stats for a file, returns "executable:hit:pct:class"
function bashunit::coverage::get_cached_stats() {
  local file="$1"

  if bashunit::coverage::lookup_get "_BASHUNIT_COVLOOKUP_STATS_" "$file"; then
    local idx="$_BASHUNIT_COVERAGE_LOOKUP_OUT"
    echo "${_BASHUNIT_COVERAGE_STATS_EXEC[idx]}:${_BASHUNIT_COVERAGE_STATS_HIT[idx]}\
:${_BASHUNIT_COVERAGE_STATS_PCT[idx]}:${_BASHUNIT_COVERAGE_STATS_CLASS[idx]}"
    return 0
  fi

  bashunit::coverage::get_file_stats "$file"
}

# Return slots for bashunit::coverage::split_stats.
_BASHUNIT_COVERAGE_SPLIT_EXEC_OUT=""
_BASHUNIT_COVERAGE_SPLIT_HIT_OUT=""
_BASHUNIT_COVERAGE_SPLIT_PCT_OUT=""
_BASHUNIT_COVERAGE_SPLIT_CLASS_OUT=""

# Splits a "executable:hit:pct:class" string (as returned by get_cached_stats/
# get_file_stats) into the four slots above. No fork. The report writers that
# consume this format (report_text, report_html, generate_file_html) share
# this parser so they cannot drift from each other on field order or count.
function bashunit::coverage::split_stats() {
  local stats="$1" rest
  _BASHUNIT_COVERAGE_SPLIT_EXEC_OUT="${stats%%:*}"
  rest="${stats#*:}"
  _BASHUNIT_COVERAGE_SPLIT_HIT_OUT="${rest%%:*}"
  rest="${rest#*:}"
  _BASHUNIT_COVERAGE_SPLIT_PCT_OUT="${rest%%:*}"
  _BASHUNIT_COVERAGE_SPLIT_CLASS_OUT="${rest#*:}"
}

function bashunit::coverage::get_percentage() {
  local total_executable=0
  local total_hit=0

  if [ "$_BASHUNIT_COVERAGE_STATS_COUNT" -gt 0 ]; then
    local i
    for ((i = 0; i < _BASHUNIT_COVERAGE_STATS_COUNT; i++)); do
      total_executable=$((total_executable + _BASHUNIT_COVERAGE_STATS_EXEC[i]))
      total_hit=$((total_hit + _BASHUNIT_COVERAGE_STATS_HIT[i]))
    done
  else
    while IFS= read -r file; do
      { [ -z "$file" ] || [ ! -f "$file" ]; } && continue

      local executable hit
      executable=$(bashunit::coverage::get_executable_lines "$file")
      hit=$(bashunit::coverage::get_hit_lines "$file")

      total_executable=$((total_executable + executable))
      total_hit=$((total_hit + hit))
    done < <(bashunit::coverage::get_tracked_files)
  fi

  bashunit::coverage::calculate_percentage "$total_hit" "$total_executable"
}

function bashunit::coverage::check_threshold() {
  if [ -z "$BASHUNIT_COVERAGE_MIN" ]; then
    return 0
  fi

  local pct
  # Under --coverage-diff the report is about the changed lines, so the gate
  # must be too: keeping the whole-file percentage here would fail a PR for
  # untouched code it did not write.
  if bashunit::coverage::is_diff_enabled && [ -n "$_BASHUNIT_COVERAGE_DIFF_PCT_OUT" ]; then
    pct="$_BASHUNIT_COVERAGE_DIFF_PCT_OUT"
  else
    pct=$(bashunit::coverage::get_percentage)
  fi

  if [ "$pct" -lt "$BASHUNIT_COVERAGE_MIN" ]; then
    local message
    message=$(printf "%sCoverage %d%% is below minimum %d%%%s" \
      "$_BASHUNIT_COLOR_FAILED" "$pct" "$BASHUNIT_COVERAGE_MIN" "$_BASHUNIT_COLOR_DEFAULT")
    # Under a machine --output the gate still speaks, but on stderr: on stdout
    # it would sit next to the JSON or XML document and break the parser.
    if bashunit::env::is_machine_output_enabled; then
      printf "%s\n" "$message" >&2
    else
      printf "%s\n" "$message"
    fi
    return 1
  fi

  return 0
}
