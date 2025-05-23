#!/usr/bin/env bash

if dependencies::has_bc; then
  # bc is better than awk because bc has no integer limits.
  function math::calculate() {
    echo "$*" | bc
  }
elif dependencies::has_awk; then
  function math::calculate() {
    awk "BEGIN { print ""$*"" }"
  }
fi
