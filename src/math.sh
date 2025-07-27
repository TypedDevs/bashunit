#!/usr/bin/env bash
# shellcheck disable=SC2155

function math::calculate() {
  if dependencies::has_bc; then
    echo "$*" | bc
  elif [[ "$*" == *.* ]] && dependencies::has_awk; then
    awk "BEGIN { print ($*) }"
  elif [[ "$*" == *.* ]]; then
    # Strip decimal parts and leading zeros
    local expression=$(echo "$*" | sed -E 's/([0-9]+)\.[0-9]+/\1/g' | sed -E 's/\b0*([1-9][0-9]*)/\1/g')
    local result=$(( expression ))
    echo "$result"
  else
    # Strip leading zeros even for purely integer math
    local expression=$(echo "$*" | sed -E 's/\b0*([1-9][0-9]*)/\1/g')
    local result=$(( expression ))
    echo "$result"
  fi
}
