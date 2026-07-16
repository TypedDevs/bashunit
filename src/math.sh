#!/usr/bin/env bash

function bashunit::math::calculate() {
  local expr="$*"

  if bashunit::dependencies::has_bc; then
    echo "$expr" | bc
    return
  fi

  case "$expr" in
  *.*)
    if bashunit::dependencies::has_awk; then
      awk "BEGIN { print ($expr) }"
      return
    fi
    # Downgrade to integer math by stripping decimals
    expr=$(echo "$expr" | sed -E 's/([0-9]+)\.[0-9]+/\1/g')
    ;;
  esac

  # Remove leading zeros from integers so $((...)) does not read them as octal.
  # Only fork sed when a leading zero is actually present — the common callers
  # (clock durations) never produce one, so the no-bc path stays fork-free.
  case "$expr" in
  0[0-9]* | *[!0-9.]0[0-9]*)
    expr=$(echo "$expr" | sed -E 's/\b0*([1-9][0-9]*)/\1/g')
    ;;
  esac

  local result=$((expr))
  echo "$result"
}

##
# Deterministically shuffles stdin lines (one item per line) with a Fisher-Yates
# driven by a seeded LCG (glibc constants). Same seed + same input always yields
# the same permutation, so a randomized run can be replayed via its seed.
# Self-contained (seeds a local state), so it is safe inside subshells/pipes and
# in --parallel where each test file shuffles in its own forked shell.
# Arguments: $1 - integer seed (non-numeric treated as 0)
##
function bashunit::math::shuffle() {
  local seed=$1
  case "$seed" in '' | *[!0-9]*) seed=0 ;; esac
  local state=$((seed & 2147483647))

  local -a items=()
  local n=0
  local line
  # `|| [ -n "$line" ]` keeps the final item when stdin has no trailing newline.
  while IFS= read -r line || [ -n "$line" ]; do
    items[n]=$line
    n=$((n + 1))
  done

  local i j tmp
  i=$((n - 1))
  while [ "$i" -gt 0 ]; do
    state=$(((1103515245 * state + 12345) & 2147483647))
    j=$((state % (i + 1)))
    tmp=${items[i]}
    items[i]=${items[j]}
    items[j]=$tmp
    i=$((i - 1))
  done

  local k=0
  while [ "$k" -lt "$n" ]; do
    printf '%s\n' "${items[k]}"
    k=$((k + 1))
  done
}
