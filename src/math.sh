#!/usr/bin/env bash

function math::calculate() {
  if dependencies::has_bc; then
    echo "$*" | bc
  elif dependencies::has_awk; then
    awk "BEGIN { print ($*) }"
  else
    local result=$(( $* ))
    echo "$result"
  fi
}
