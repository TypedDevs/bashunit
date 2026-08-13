#!/usr/bin/env bash

# Coverage percentages, the precomputed per-file stats cache and the threshold gate.

# Return slots for the class and colour helpers below.
_BASHUNIT_COVERAGE_CLASS_OUT=""
_BASHUNIT_COVERAGE_COLOR_OUT=""

##
# Sets _BASHUNIT_COVERAGE_CLASS_OUT to high/medium/low for a percentage.
# Arguments: $1 - percentage
##
function bashunit::coverage::class_to_slot() {
  local pct="$1"
  if [ "$pct" -ge "${BASHUNIT_COVERAGE_THRESHOLD_HIGH:-$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_HIGH}" ]; then
    _BASHUNIT_COVERAGE_CLASS_OUT="high"
  elif [ "$pct" -ge "${BASHUNIT_COVERAGE_THRESHOLD_LOW:-$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_LOW}" ]; then
    _BASHUNIT_COVERAGE_CLASS_OUT="medium"
  else
    _BASHUNIT_COVERAGE_CLASS_OUT="low"
  fi
}

##
# Sets _BASHUNIT_COVERAGE_COLOR_OUT to the colour of a class.
# Arguments: $1 - high, medium or low
##
function bashunit::coverage::color_to_slot() {
  case "$1" in
  high) _BASHUNIT_COVERAGE_COLOR_OUT="$_BASHUNIT_COLOR_PASSED" ;;
  medium) _BASHUNIT_COVERAGE_COLOR_OUT="$_BASHUNIT_COLOR_SKIPPED" ;;
  low) _BASHUNIT_COVERAGE_COLOR_OUT="$_BASHUNIT_COLOR_FAILED" ;;
  *) _BASHUNIT_COVERAGE_COLOR_OUT="" ;;
  esac
}

# The two above are the decision; these are the same thing for a caller that
# wants it on stdout. Every per-file and per-function caller uses the slots: a
# subshell to pick one of three constants cost 168ms of the 253ms the text
# report spent on 128 files (#1092).
function bashunit::coverage::get_coverage_class() {
  bashunit::coverage::class_to_slot "$1"
  echo "$_BASHUNIT_COVERAGE_CLASS_OUT"
}

function bashunit::coverage::get_color_for_class() {
  bashunit::coverage::color_to_slot "$1"
  printf '%s' "$_BASHUNIT_COVERAGE_COLOR_OUT"
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
  bashunit::coverage::_derive_file_stats "${stats%%:*}" "${stats##*:}"
}

# Fills the four slots from an executable/hit pair. Split out so the batch pass
# and the per-file path derive pct and class the same way, and so neither forks
# for them: percentage and class each used to cost a subshell per file, which
# at 128 tracked files was more than the arithmetic they wrapped (#1088).
function bashunit::coverage::_derive_file_stats() {
  local executable="$1" hit="$2"
  _BASHUNIT_COVERAGE_FILE_STATS_EXEC_OUT="$executable"
  _BASHUNIT_COVERAGE_FILE_STATS_HIT_OUT="$hit"

  local pct=0
  if [ "$executable" -gt 0 ]; then
    pct=$((hit * 100 / executable))
  fi
  _BASHUNIT_COVERAGE_FILE_STATS_PCT_OUT="$pct"

  bashunit::coverage::class_to_slot "$pct"
  _BASHUNIT_COVERAGE_FILE_STATS_CLASS_OUT="$_BASHUNIT_COVERAGE_CLASS_OUT"
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
  # The report is about the files the user asked for, not only the ones that
  # happened to run (#1053).
  bashunit::coverage::seed_tracked_files

  _BASHUNIT_COVERAGE_STATS_FILES=()
  _BASHUNIT_COVERAGE_STATS_EXEC=()
  _BASHUNIT_COVERAGE_STATS_HIT=()
  _BASHUNIT_COVERAGE_STATS_PCT=()
  _BASHUNIT_COVERAGE_STATS_CLASS=()
  _BASHUNIT_COVERAGE_STATS_COUNT=0
  bashunit::coverage::reset_lookup_namespace "_BASHUNIT_COVLOOKUP_STATS_"

  if bashunit::coverage::_precompute_batch; then
    return 0
  fi

  local file
  while IFS= read -r file; do
    { [ -z "$file" ] || [ ! -f "$file" ]; } && continue

    bashunit::coverage::_compute_file_stats "$file"
    bashunit::coverage::_record_file_stats "$file" \
      "$_BASHUNIT_COVERAGE_FILE_STATS_EXEC_OUT" "$_BASHUNIT_COVERAGE_FILE_STATS_HIT_OUT"
  done < <(bashunit::coverage::get_tracked_files)
}

# Appends one file to the stats cache.
function bashunit::coverage::_record_file_stats() {
  local file="$1"
  bashunit::coverage::_derive_file_stats "$2" "$3"

  local idx="$_BASHUNIT_COVERAGE_STATS_COUNT"
  _BASHUNIT_COVERAGE_STATS_FILES[idx]="$file"
  _BASHUNIT_COVERAGE_STATS_EXEC[idx]="$_BASHUNIT_COVERAGE_FILE_STATS_EXEC_OUT"
  _BASHUNIT_COVERAGE_STATS_HIT[idx]="$_BASHUNIT_COVERAGE_FILE_STATS_HIT_OUT"
  _BASHUNIT_COVERAGE_STATS_PCT[idx]="$_BASHUNIT_COVERAGE_FILE_STATS_PCT_OUT"
  _BASHUNIT_COVERAGE_STATS_CLASS[idx]="$_BASHUNIT_COVERAGE_FILE_STATS_CLASS_OUT"
  _BASHUNIT_COVERAGE_STATS_COUNT=$((idx + 1))
  bashunit::coverage::lookup_put "_BASHUNIT_COVLOOKUP_STATS_" "$file" "$idx"
}

# Fills the whole cache with one awk invocation, and reports whether it could.
#
# Returns 1 without touching the cache when there is nowhere to write the
# manifest or the pass produced nothing for a non-empty tracked list, so the
# caller falls back to the per-file path and a report is never silently empty.
function bashunit::coverage::_precompute_batch() {
  bashunit::coverage::write_batch_manifest "stats-manifest" || return 1
  local manifest="$_BASHUNIT_COVERAGE_MANIFEST_OUT"

  if [ -z "$manifest" ]; then
    # Nothing tracked is a valid, empty report -- not a reason to fall back.
    return 0
  fi

  local executable hit file
  while IFS="$(printf '\t')" read -r executable hit file; do
    [ -n "$file" ] || continue
    bashunit::coverage::_record_file_stats "$file" "$executable" "$hit"
  done < <(bashunit::coverage::awk_file_stats "$manifest" 2>/dev/null)

  [ "$_BASHUNIT_COVERAGE_STATS_COUNT" -gt 0 ]
}

# Look up cached stats for a file, returns "executable:hit:pct:class"
##
# Fills the four split slots for a file, without the command substitution
# get_cached_stats costs its callers (#1117).
# Arguments: $1 - source file
##
function bashunit::coverage::cached_stats_to_slots() {
  local file="$1"

  if bashunit::coverage::lookup_get "_BASHUNIT_COVLOOKUP_STATS_" "$file"; then
    local idx="$_BASHUNIT_COVERAGE_LOOKUP_OUT"
    _BASHUNIT_COVERAGE_SPLIT_EXEC_OUT="${_BASHUNIT_COVERAGE_STATS_EXEC[idx]}"
    _BASHUNIT_COVERAGE_SPLIT_HIT_OUT="${_BASHUNIT_COVERAGE_STATS_HIT[idx]}"
    _BASHUNIT_COVERAGE_SPLIT_PCT_OUT="${_BASHUNIT_COVERAGE_STATS_PCT[idx]}"
    _BASHUNIT_COVERAGE_SPLIT_CLASS_OUT="${_BASHUNIT_COVERAGE_STATS_CLASS[idx]}"
    return 0
  fi

  bashunit::coverage::_compute_file_stats "$file"
  _BASHUNIT_COVERAGE_SPLIT_EXEC_OUT="$_BASHUNIT_COVERAGE_FILE_STATS_EXEC_OUT"
  _BASHUNIT_COVERAGE_SPLIT_HIT_OUT="$_BASHUNIT_COVERAGE_FILE_STATS_HIT_OUT"
  _BASHUNIT_COVERAGE_SPLIT_PCT_OUT="$_BASHUNIT_COVERAGE_FILE_STATS_PCT_OUT"
  _BASHUNIT_COVERAGE_SPLIT_CLASS_OUT="$_BASHUNIT_COVERAGE_FILE_STATS_CLASS_OUT"
}

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
