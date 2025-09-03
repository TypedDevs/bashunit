#!/usr/bin/env bash

# @data_provider provider_lines
function test_with_provider() {
  return 0
}

function provider_lines() {
  data_set "alpha beta"
  data_set "gamma"
  data_set "delta epsilon zeta"
}
