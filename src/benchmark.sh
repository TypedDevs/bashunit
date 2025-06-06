#!/usr/bin/env bash

_BENCH_NAMES=()
_BENCH_REVS=()
_BENCH_ITS=()
_BENCH_AVERAGES=()

function benchmark::parse_annotations() {
  local fn_name=$1
  local script=$2
  local revs=1
  local its=1

  local annotation
  annotation=$(awk "/function[[:space:]]+$fn_name[[:space:]]*\(/ {print prev; exit} {prev=\$0}" "$script")

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

  echo "$revs" "$its"
}

function benchmark::add_result() {
  _BENCH_NAMES+=("$1")
  _BENCH_REVS+=("$2")
  _BENCH_ITS+=("$3")
  _BENCH_AVERAGES+=("$4")
}

function benchmark::run_function() {
  local fn_name=$1
  local revs=$2
  local its=$3
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

    local line="bench $fn_name [$i/$its] ${dur_ms} ms"
    state::print_line "successful" "$line"
  done

  local sum=0
  for d in "${durations[@]}"; do
    sum=$(math::calculate "$sum + $d")
  done
  local avg=$(math::calculate "$sum / ${#durations[@]}")
  benchmark::add_result "$fn_name" "$revs" "$its" "$avg"
}

function benchmark::print_results() {
  if (( ${#_BENCH_NAMES[@]} == 0 )); then
    return
  fi
  if env::is_simple_output_enabled; then
    printf "\n"
  fi
  printf "\nBenchmark Results (avg ms)\n"
  printf '%-40s %8s %8s %8s\n' "Name" "Revs" "Its" "Avg(ms)"
  for i in "${!_BENCH_NAMES[@]}"; do
    printf '%-40s %8s %8s %8s\n' "${_BENCH_NAMES[$i]}" "${_BENCH_REVS[$i]}" "${_BENCH_ITS[$i]}" "${_BENCH_AVERAGES[$i]}"
  done
}
