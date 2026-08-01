#!/usr/bin/env bash

# Running one bench function for its configured revolutions and iterations.

function bashunit::benchmark::run_function() {
  local fn_name=$1
  local revs=$2
  local its=$3
  local max_ms=$4
  local IFS=$' \t\n'
  local -a durations=()
  local durations_count=0
  local i r

  for ((i = 1; i <= its; i++)); do
    local start_time=$(bashunit::clock::now)
    (
      for ((r = 1; r <= revs; r++)); do
        "$fn_name" >/dev/null 2>&1
      done
    )
    local end_time=$(bashunit::clock::now)
    local dur_ns=$(bashunit::math::calculate "($end_time - $start_time)")
    local dur_ms=$(bashunit::math::calculate "$dur_ns / 1000000")
    durations[durations_count]="$dur_ms"
    durations_count=$((durations_count + 1))

    if bashunit::env::is_bench_mode_enabled; then
      local label="$(bashunit::helper::normalize_test_function_name "$fn_name")"
      local line="$label [$i/$its] ${dur_ms} ms"
      bashunit::console_results::print_line "successful" "$line"
    fi
  done

  local sum=0
  local d
  for d in "${durations[@]+"${durations[@]}"}"; do
    sum=$(bashunit::math::calculate "$sum + $d")
  done
  local avg=$(bashunit::math::calculate "$sum / ${#durations[@]}")
  bashunit::benchmark::add_result "$fn_name" "$revs" "$its" "$avg" "$max_ms"
}

