#!/usr/bin/env bash

function math::calculate() {
  local expr="$*"

  if dependencies::has_bc; then
    echo "$expr" | bc
    return
  fi

  if [[ "$expr" == *.* ]]; then
    if dependencies::has_awk; then
      awk "BEGIN { print ($expr) }"
      return
    fi
    # Downgrade to integer math by stripping decimals
    expr=$(echo "$expr" | sed -E 's/([0-9]+)\.[0-9]+/\1/g')
  fi

  # Remove leading zeros from integers
  expr=$(echo "$expr" | sed -E 's/\b0*([1-9][0-9]*)/\1/g')

  local result=$(( expr ))
  echo "$result"
}
