#!/usr/bin/env bash

_BASHUNIT_BENCH_NAMES=()
_BASHUNIT_BENCH_REVS=()
_BASHUNIT_BENCH_ITS=()
_BASHUNIT_BENCH_AVERAGES=()
_BASHUNIT_BENCH_MAX_MILLIS=()

function bashunit::benchmark::parse_annotations() {
  local fn_name=$1
  local script=$2
  local revs=1
  local its=1
  local max_ms=""

  local annotation
  annotation=$(awk "/function[[:space:]]+${fn_name}[[:space:]]*\(/ {print prev; exit} {prev=\$0}" "$script")

  # Patterns stored in variables for Bash 3.0 compatibility
  local _revs_pattern='@revs=([0-9]+)'
  local _revolutions_pattern='@revolutions=([0-9]+)'
  local _its_pattern='@its=([0-9]+)'
  local _iterations_pattern='@iterations=([0-9]+)'
  local _max_ms_pattern='@max_ms=([0-9.]+)'

  if [[ $annotation =~ $_revs_pattern ]]; then
    revs="${BASH_REMATCH[1]}"
  elif [[ $annotation =~ $_revolutions_pattern ]]; then
    revs="${BASH_REMATCH[1]}"
  fi

  if [[ $annotation =~ $_its_pattern ]]; then
    its="${BASH_REMATCH[1]}"
  elif [[ $annotation =~ $_iterations_pattern ]]; then
    its="${BASH_REMATCH[1]}"
  fi

  if [[ $annotation =~ $_max_ms_pattern ]]; then
    max_ms="${BASH_REMATCH[1]}"
  elif [[ $annotation =~ $_max_ms_pattern ]]; then
    max_ms="${BASH_REMATCH[1]}"
  fi

  if [[ -n "$max_ms" ]]; then
    echo "$revs" "$its" "$max_ms"
  else
    echo "$revs" "$its"
  fi
}

function bashunit::benchmark::add_result() {
  _BASHUNIT_BENCH_NAMES[${#_BASHUNIT_BENCH_NAMES[@]}]="$1"
  _BASHUNIT_BENCH_REVS[${#_BASHUNIT_BENCH_REVS[@]}]="$2"
  _BASHUNIT_BENCH_ITS[${#_BASHUNIT_BENCH_ITS[@]}]="$3"
  _BASHUNIT_BENCH_AVERAGES[${#_BASHUNIT_BENCH_AVERAGES[@]}]="$4"
  _BASHUNIT_BENCH_MAX_MILLIS[${#_BASHUNIT_BENCH_MAX_MILLIS[@]}]="$5"
}

# shellcheck disable=SC2155
function bashunit::benchmark::run_function() {
  local fn_name=$1
  local revs=$2
  local its=$3
  local max_ms=$4
  local -a durations=()
  local durations_count=0
  local i r

  for ((i=1; i<=its; i++)); do
    local start_time=$(bashunit::clock::now)
    (
      for ((r=1; r<=revs; r++)); do
        "$fn_name" >/dev/null 2>&1
      done
    )
    local end_time=$(bashunit::clock::now)
    local dur_ns=$(bashunit::math::calculate "($end_time - $start_time)")
    local dur_ms=$(bashunit::math::calculate "$dur_ns / 1000000")
    durations[durations_count]="$dur_ms"; durations_count=$((durations_count + 1))

    if bashunit::env::is_bench_mode_enabled; then
      local label="$(bashunit::helper::normalize_test_function_name "$fn_name")"
      local line="$label [$i/$its] ${dur_ms} ms"
      bashunit::state::print_line "successful" "$line"
    fi
  done

  local sum=0
  local d
  for d in "${durations[@]}"; do
    sum=$(bashunit::math::calculate "$sum + $d")
  done
  local avg=$(bashunit::math::calculate "$sum / ${#durations[@]}")
  bashunit::benchmark::add_result "$fn_name" "$revs" "$its" "$avg" "$max_ms"
}

function bashunit::benchmark::print_results() {
  if ! bashunit::env::is_bench_mode_enabled; then
    return
  fi

  if (( ${#_BASHUNIT_BENCH_NAMES[@]} == 0 )); then
    return
  fi

  if bashunit::env::is_simple_output_enabled; then
    printf "\n"
  fi

  printf "\nBenchmark Results (avg ms)\n"
  bashunit::print_line 80 "="
  printf "\n"

  local has_threshold=false
  local val
  for val in "${_BASHUNIT_BENCH_MAX_MILLIS[@]}"; do
    if [[ -n "$val" ]]; then
      has_threshold=true
      break
    fi
  done

  if $has_threshold; then
    printf '%-40s %6s %6s %10s %12s\n' "Name" "Revs" "Its" "Avg(ms)" "Status"
  else
    printf '%-40s %6s %6s %10s\n' "Name" "Revs" "Its" "Avg(ms)"
  fi

  local i=0
  for i in "${!_BASHUNIT_BENCH_NAMES[@]}"; do
    local name="${_BASHUNIT_BENCH_NAMES[$i]}"
    local revs="${_BASHUNIT_BENCH_REVS[$i]}"
    local its="${_BASHUNIT_BENCH_ITS[$i]}"
    local avg="${_BASHUNIT_BENCH_AVERAGES[$i]}"
    local max_ms="${_BASHUNIT_BENCH_MAX_MILLIS[$i]}"

    if [[ -z "$max_ms" ]]; then
      printf '%-40s %6s %6s %10s\n' "$name" "$revs" "$its" "$avg"
      continue
    fi

    if [[ "$avg" -le "$max_ms" ]]; then
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
