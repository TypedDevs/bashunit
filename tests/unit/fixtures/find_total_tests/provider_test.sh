#!/usr/bin/env bash

# @data_provider provider_lines
function test_with_provider() {
  return 0
}

function provider_lines() {
  bashunit::data_set "alpha beta"
  bashunit::data_set "gamma"
  bashunit::data_set "delta epsilon zeta"
}
