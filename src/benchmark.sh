#!/usr/bin/env bash

_BENCH_NAMES=()
_BENCH_REVS=()
_BENCH_ITS=()
_BENCH_AVERAGES=()
_BENCH_MAX_MILLIS=()

function benchmark::parse_annotations() {
  local fn_name=$1
  local script=$2
  local revs=1
  local its=1
  local max_ms=""

  local annotation
  annotation=$(awk "/function[[:space:]]+${fn_name}[[:space:]]*\(/ {print prev; exit} {prev=\$0}" "$script")

  if [[ $annotation =~ @revs=([0-9]+) ]]; then
    revs="${BASH_REMATCH[1]}"
  elif [[ $annotation =~ @revolutions=([0-9]+) ]]; then
    revs="${BASH_REMATCH[1]}"
  fi

  if [[ $annotation =~ @its=([0-9]+) ]]; then
    its="${BASH_REMATCH[1]}"
  elif [[ $annotation =~ @iterations=([0-9]+) ]]; then
    its="${BASH_REMATCH[1]}"
  fi

  if [[ $annotation =~ @max_ms=([0-9.]+) ]]; then
    max_ms="${BASH_REMATCH[1]}"
  elif [[ $annotation =~ @max_ms=([0-9.]+) ]]; then
    max_ms="${BASH_REMATCH[1]}"
  fi

  if [[ -n "$max_ms" ]]; then
    echo "$revs" "$its" "$max_ms"
  else
    echo "$revs" "$its"
  fi
}

function benchmark::add_result() {
  _BENCH_NAMES+=("$1")
  _BENCH_REVS+=("$2")
  _BENCH_ITS+=("$3")
  _BENCH_AVERAGES+=("$4")
  _BENCH_MAX_MILLIS+=("$5")
}

# shellcheck disable=SC2155
function benchmark::run_function() {
  local fn_name=$1
  local revs=$2
  local its=$3
  local max_ms=$4
  local durations=()

  for ((i=1; i<=its; i++)); do
    local start_time=$(clock::now)
    (
      for ((r=1; r<=revs; r++)); do
        "$fn_name" >/dev/null 2>&1
      done
    )
    local end_time=$(clock::now)
    local dur_ns=$(math::calculate "($end_time - $start_time)")
    local dur_ms=$(math::calculate "$dur_ns / 1000000")
    durations+=("$dur_ms")

    if env::is_bench_mode_enabled; then
      local label="$(helper::normalize_test_function_name "$fn_name")"
      local line="$label [$i/$its] ${dur_ms} ms"
      state::print_line "successful" "$line"
    fi
  done

  local sum=0
  for d in "${durations[@]}"; do
    sum=$(math::calculate "$sum + $d")
  done
  local avg=$(math::calculate "$sum / ${#durations[@]}")
  benchmark::add_result "$fn_name" "$revs" "$its" "$avg" "$max_ms"
}

function benchmark::print_results() {
  if ! env::is_bench_mode_enabled; then
    return
  fi

  if (( ${#_BENCH_NAMES[@]} == 0 )); then
    return
  fi

  if env::is_simple_output_enabled; then
    printf "\n"
  fi

  printf "\nBenchmark Results (avg ms)\n"
  bashunit::print_line 80 "="
  printf "\n"

  local has_threshold=false
  for val in "${_BENCH_MAX_MILLIS[@]}"; do
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

  for i in "${!_BENCH_NAMES[@]}"; do
    local name="${_BENCH_NAMES[$i]}"
    local revs="${_BENCH_REVS[$i]}"
    local its="${_BENCH_ITS[$i]}"
    local avg="${_BENCH_AVERAGES[$i]}"
    local max_ms="${_BENCH_MAX_MILLIS[$i]}"

    if [[ -z "$max_ms" ]]; then
      printf '%-40s %6s %6s %10s\n' "$name" "$revs" "$its" "$avg"
      continue
    fi

    if (( $(echo "$avg <= $max_ms" | bc -l) )); then
      local raw="≤ ${max_ms}"
      printf -v padded "%14s" "$raw"
      printf '%-40s %6s %6s %10s %12s\n' "$name" "$revs" "$its" "$avg" "$padded"
      continue
    fi

    local raw="> ${max_ms}"
    printf -v padded "%12s" "$raw"
    printf '%-40s %6s %6s %10s %s%s%s\n' \
      "$name" "$revs" "$its" "$avg" \
      "$_COLOR_FAILED" "$padded" "${_COLOR_DEFAULT}"
  done

  console_results::print_execution_time
}
