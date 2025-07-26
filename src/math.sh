#!/usr/bin/env bash

function math::calculate() {
  if dependencies::has_bc; then
    echo "$*" | bc
  elif [[ "$*" == *.* ]] && dependencies::has_awk; then
    # Use awk for floating point calculations when bc is unavailable
    awk "BEGIN { print ($*) }"
  else
    # Fallback to shell arithmetic which has good integer precision
    local result=$(( $* ))
    echo "$result"
  fi
}
