#!/usr/bin/env bash

# Terminal coverage report.

##
# Say which engine ran, and never let an ignored explicit request pass silently.
#
# The warning is unconditional because an ignored BASHUNIT_COVERAGE_ENGINE is a
# misconfiguration the user cannot otherwise see: on macOS's Bash 3.2 an explicit
# `xtrace` was accepted and dropped with no output at all (#1005). The engine
# line itself is verbose-only, since `auto` resolving to trap is normal.
##
function bashunit::coverage::print_engine_notice() {
  if bashunit::coverage::engine_was_downgraded; then
    printf "%sWarning: coverage engine 'xtrace' needs Bash 4.1+ (running %s.%s); using 'trap'.%s\n" \
      "$_BASHUNIT_COLOR_INCOMPLETE" "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}" \
      "$_BASHUNIT_COLOR_DEFAULT"
  fi

  if bashunit::env::is_verbose_enabled; then
    printf "Coverage engine: %s\n" "$(bashunit::coverage::engine_in_use)"

    # Before Bash 4 the DEBUG trap does not reach a subshell even under
    # `set -T`, so lines executed inside ( ), $( ) or <( ) are never recorded
    # and the percentage comes out lower than the same project measures on
    # Bash 4+. Nothing in the numbers hints at it, so say it where the engine
    # is already being reported (#1112).
    if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
      printf "%sNote: Bash %s.%s does not report lines run inside a subshell; \
coverage may read lower than on Bash 4+.%s\n" \
        "$_BASHUNIT_COLOR_INCOMPLETE" "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}" \
        "$_BASHUNIT_COLOR_DEFAULT"
    fi
  fi
}

function bashunit::coverage::report_text() {
  if ! bashunit::env::is_coverage_enabled; then
    return 0
  fi

  local total_executable=0
  local total_hit=0
  local has_files=false

  echo ""
  bashunit::coverage::print_engine_notice
  echo "Coverage Report"
  echo "---------------"

  local file
  while IFS= read -r file; do
    { [ -z "$file" ] || [ ! -f "$file" ]; } && continue
    has_files=true

    local executable hit pct class stats
    stats=$(bashunit::coverage::get_cached_stats "$file")
    bashunit::coverage::split_stats "$stats"
    executable="$_BASHUNIT_COVERAGE_SPLIT_EXEC_OUT"
    hit="$_BASHUNIT_COVERAGE_SPLIT_HIT_OUT"
    pct="$_BASHUNIT_COVERAGE_SPLIT_PCT_OUT"
    class="$_BASHUNIT_COVERAGE_SPLIT_CLASS_OUT"

    total_executable=$((total_executable + executable))
    total_hit=$((total_hit + hit))

    local color reset="$_BASHUNIT_COLOR_DEFAULT"
    bashunit::coverage::color_to_slot "$class"
    color="$_BASHUNIT_COVERAGE_COLOR_OUT"

    # Display relative path
    local display_file="${file#"$(pwd)"/}"
    printf "%s%-40s %3d/%3d lines (%3d%%)%s\n" \
      "$color" "$display_file" "$hit" "$executable" "$pct" "$reset"
  done < <(bashunit::coverage::get_tracked_files)

  if [ "$has_files" != "true" ]; then
    echo "---------------"
    echo "Total: 0/0 (0%)"
    return 0
  fi

  echo "---------------"

  # Total
  local total_pct total_class
  total_pct=$(bashunit::coverage::calculate_percentage "$total_hit" "$total_executable")
  bashunit::coverage::class_to_slot "$total_pct"
  total_class="$_BASHUNIT_COVERAGE_CLASS_OUT"

  local color reset="$_BASHUNIT_COLOR_DEFAULT"
  bashunit::coverage::color_to_slot "$total_class"
  color="$_BASHUNIT_COVERAGE_COLOR_OUT"

  printf "%sTotal: %d/%d (%d%%)%s\n" \
    "$color" "$total_hit" "$total_executable" "$total_pct" "$reset"

  # Optional per-function summary (gated on BASHUNIT_COVERAGE_SHOW_FUNCTIONS)
  if [ "${BASHUNIT_COVERAGE_SHOW_FUNCTIONS:-false}" = "true" ]; then
    bashunit::coverage::report_text_functions
  fi

  # Optional uncovered hotspots (gated on BASHUNIT_COVERAGE_SHOW_UNCOVERED)
  if [ "${BASHUNIT_COVERAGE_SHOW_UNCOVERED:-false}" = "true" ]; then
    bashunit::coverage::report_text_uncovered
  fi

  # Optional per-line execution counts (gated on BASHUNIT_COVERAGE_SHOW_LINE_HITS)
  if [ "${BASHUNIT_COVERAGE_SHOW_LINE_HITS:-false}" = "true" ]; then
    bashunit::coverage::report_text_line_hits
  fi

  # Show report location if generated
  if [ -n "$BASHUNIT_COVERAGE_REPORT" ]; then
    echo ""
    echo "Coverage report written to: $BASHUNIT_COVERAGE_REPORT"
  fi
}


# Compress a sorted list of integers into a comma-separated range
# string (e.g. "3 4 5 7 9 10" -> "3-5,7,9-10"). Result on
# _BASHUNIT_RANGES_OUT to avoid a subshell on each call.
_BASHUNIT_RANGES_OUT=""

function bashunit::coverage::_compress_ranges() {
  local out="" start="" end="" n
  for n in "$@"; do
    if [ -z "$start" ]; then
      start="$n"
      end="$n"
    elif [ "$n" -eq $((end + 1)) ]; then
      end="$n"
    else
      if [ "$start" = "$end" ]; then
        out="${out}${start},"
      else
        out="${out}${start}-${end},"
      fi
      start="$n"
      end="$n"
    fi
  done
  if [ -n "$start" ]; then
    if [ "$start" = "$end" ]; then
      out="${out}${start}"
    else
      out="${out}${start}-${end}"
    fi
  fi
  _BASHUNIT_RANGES_OUT="${out%,}"
}

# List executable lines that were never hit, grouped by file.
# Gated on BASHUNIT_COVERAGE_SHOW_UNCOVERED=true. Output is suppressed
# when no uncovered lines exist so a fully-covered run stays quiet.
function bashunit::coverage::report_text_uncovered() {
  local file
  local printed_header=false
  while IFS= read -r file; do
    { [ -z "$file" ] || [ ! -f "$file" ]; } && continue

    bashunit::coverage::load_hits_by_line "$file"

    local -a uncovered_lines=()
    local _ucount=0
    local lineno=0 line
    while IFS= read -r line || [ -n "$line" ]; do
      lineno=$((lineno + 1))
      bashunit::coverage::is_executable_line "$line" "$lineno" || continue
      local lh="${_BASHUNIT_COVERAGE_HITS_BY_LINE[$lineno]:-0}"
      if [ "$lh" -eq 0 ]; then
        uncovered_lines[_ucount]="$lineno"
        _ucount=$((_ucount + 1))
      fi
    done <"$file"

    [ "$_ucount" -eq 0 ] && continue

    if [ "$printed_header" != "true" ]; then
      echo ""
      echo "Uncovered Lines"
      echo "---------------"
      printed_header=true
    fi

    local display_file="${file#"$(pwd)"/}"
    local color="$_BASHUNIT_COLOR_FAILED" reset="$_BASHUNIT_COLOR_DEFAULT"
    local out
    bashunit::coverage::_compress_ranges "${uncovered_lines[@]}"
    out="$_BASHUNIT_RANGES_OUT"

    printf "%s%s:%s%s\n" "$color" "$display_file" "$out" "$reset"
  done < <(bashunit::coverage::get_tracked_files)
}

# Per-line execution hit counts, gated on BASHUNIT_COVERAGE_SHOW_LINE_HITS=true.
# Lists each covered executable line as "<lineno>:<count>", where count is the
# number of times the line ran (the same value LCOV emits in its DA records).
function bashunit::coverage::report_text_line_hits() {
  local IFS=$' \t\n'
  local file
  local printed_header=false
  while IFS= read -r file; do
    { [ -z "$file" ] || [ ! -f "$file" ]; } && continue

    bashunit::coverage::load_hits_by_line "$file"

    local -a hit_specs=()
    local _hc=0
    local lineno=0 line
    while IFS= read -r line || [ -n "$line" ]; do
      lineno=$((lineno + 1))
      bashunit::coverage::is_executable_line "$line" "$lineno" || continue
      local lh="${_BASHUNIT_COVERAGE_HITS_BY_LINE[$lineno]:-0}"
      if [ "$lh" -gt 0 ]; then
        hit_specs[_hc]="${lineno}:${lh}"
        _hc=$((_hc + 1))
      fi
    done <"$file"

    [ "$_hc" -eq 0 ] && continue

    if [ "$printed_header" != "true" ]; then
      echo ""
      echo "Line Hits"
      echo "---------"
      printed_header=true
    fi

    local display_file="${file#"$(pwd)"/}"
    printf "%s: %s\n" "$display_file" "${hit_specs[*]}"
  done < <(bashunit::coverage::get_tracked_files)
}

# Per-function coverage summary printed after the file table.
# Gated on BASHUNIT_COVERAGE_SHOW_FUNCTIONS=true to keep default output compact.
function bashunit::coverage::report_text_functions() {
  local file
  local printed_header=false
  while IFS= read -r file; do
    { [ -z "$file" ] || [ ! -f "$file" ]; } && continue

    local functions_data
    functions_data=$(bashunit::coverage::extract_functions "$file")
    [ -z "$functions_data" ] && continue

    bashunit::coverage::load_hits_by_line "$file"

    local -a file_lines=()
    local _fli=0 _fl
    while IFS= read -r _fl || [ -n "$_fl" ]; do
      file_lines[_fli]="$_fl"
      ((++_fli))
    done <"$file"

    local display_file="${file#"$(pwd)"/}"

    if [ "$printed_header" != "true" ]; then
      echo ""
      echo "Functions"
      echo "---------"
      printed_header=true
    fi
    echo "${display_file}"

    local fn_name fn_start fn_end ln fn_executable fn_hit
    local fn_pct fn_class color reset="$_BASHUNIT_COLOR_DEFAULT"
    while IFS='|' read -r fn_name fn_start fn_end; do
      [ -z "$fn_name" ] && continue

      fn_executable=0
      fn_hit=0
      for ((ln = fn_start; ln <= fn_end; ln++)); do
        bashunit::coverage::is_executable_line \
          "${file_lines[$((ln - 1))]:-}" "$ln" || continue
        fn_executable=$((fn_executable + 1))
        [ "${_BASHUNIT_COVERAGE_HITS_BY_LINE[$ln]:-0}" -gt 0 ] && fn_hit=$((fn_hit + 1))
      done

      fn_pct=0
      if [ "$fn_executable" -gt 0 ]; then
        fn_pct=$((fn_hit * 100 / fn_executable))
      fi
      bashunit::coverage::class_to_slot "$fn_pct"
      fn_class="$_BASHUNIT_COVERAGE_CLASS_OUT"
      bashunit::coverage::color_to_slot "$fn_class"
      color="$_BASHUNIT_COVERAGE_COLOR_OUT"

      printf "  %s%-38s %3d/%3d lines (%3d%%)%s\n" \
        "$color" "$fn_name" "$fn_hit" "$fn_executable" "$fn_pct" "$reset"
    done <<<"$functions_data"
  done < <(bashunit::coverage::get_tracked_files)
}
