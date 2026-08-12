#!/usr/bin/env bash

# The collected bench results and the table they print as.

_BASHUNIT_BENCH_NAMES=()
_BASHUNIT_BENCH_REVS=()
_BASHUNIT_BENCH_ITS=()
_BASHUNIT_BENCH_AVERAGES=()
_BASHUNIT_BENCH_MAX_MILLIS=()
# Only the reports read these two: the console table has never shown the file
# or the individual iterations, and a run without --report-* pays nothing for
# them beyond two string assignments.
_BASHUNIT_BENCH_FILES=()
_BASHUNIT_BENCH_DURATIONS=()

##
# Arguments: $1 - function, $2 - revs, $3 - its, $4 - average ms,
#            $5 - @max_ms threshold (may be empty), $6 - bench file,
#            $7 - space-separated per-iteration durations in ms
##
function bashunit::benchmark::add_result() {
  _BASHUNIT_BENCH_NAMES[${#_BASHUNIT_BENCH_NAMES[@]}]="$1"
  _BASHUNIT_BENCH_REVS[${#_BASHUNIT_BENCH_REVS[@]}]="$2"
  _BASHUNIT_BENCH_ITS[${#_BASHUNIT_BENCH_ITS[@]}]="$3"
  _BASHUNIT_BENCH_AVERAGES[${#_BASHUNIT_BENCH_AVERAGES[@]}]="$4"
  _BASHUNIT_BENCH_MAX_MILLIS[${#_BASHUNIT_BENCH_MAX_MILLIS[@]}]="$5"
  _BASHUNIT_BENCH_FILES[${#_BASHUNIT_BENCH_FILES[@]}]="${6:-}"
  _BASHUNIT_BENCH_DURATIONS[${#_BASHUNIT_BENCH_DURATIONS[@]}]="${7:-}"
}

function bashunit::benchmark::print_results() {
  if ! bashunit::env::is_bench_mode_enabled; then
    return
  fi

  if ((${#_BASHUNIT_BENCH_NAMES[@]} == 0)); then
    return
  fi

  if bashunit::env::is_simple_output_enabled; then
    printf "\n"
  fi

  printf "\nBenchmark Results (avg ms)\n"
  bashunit::print_line 80 "="
  printf "\n"

  local IFS=$' \t\n'
  local has_threshold=false
  local val
  for val in "${_BASHUNIT_BENCH_MAX_MILLIS[@]+"${_BASHUNIT_BENCH_MAX_MILLIS[@]}"}"; do
    if [ -n "$val" ]; then
      has_threshold=true
      break
    fi
  done

  if $has_threshold; then
    printf '%-40s %6s %6s %10s %12s\n' "Name" "Revs" "Its" "Avg(ms)" "Status"
  else
    printf '%-40s %6s %6s %10s\n' "Name" "Revs" "Its" "Avg(ms)"
  fi

  local i
  for i in "${!_BASHUNIT_BENCH_NAMES[@]}"; do
    local name="${_BASHUNIT_BENCH_NAMES[$i]:-}"
    local revs="${_BASHUNIT_BENCH_REVS[$i]:-}"
    local its="${_BASHUNIT_BENCH_ITS[$i]:-}"
    local avg="${_BASHUNIT_BENCH_AVERAGES[$i]:-}"
    local max_ms="${_BASHUNIT_BENCH_MAX_MILLIS[$i]:-}"

    if [ -z "$max_ms" ]; then
      printf '%-40s %6s %6s %10s\n' "$name" "$revs" "$its" "$avg"
      continue
    fi

    if bashunit::math::is_le "$avg" "$max_ms"; then
      local raw="≤ ${max_ms}"
      local padded
      padded=$(printf "%14s" "$raw")
      printf '%-40s %6s %6s %10s %12s\n' "$name" "$revs" "$its" "$avg" "$padded"
      continue
    fi

    local raw="> ${max_ms}"
    local padded
    padded=$(printf "%12s" "$raw")
    printf '%-40s %6s %6s %10s %s%s%s\n' \
      "$name" "$revs" "$its" "$avg" \
      "$_BASHUNIT_COLOR_FAILED" "$padded" "${_BASHUNIT_COLOR_DEFAULT}"
  done

  bashunit::console_results::print_execution_time
}
