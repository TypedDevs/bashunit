#!/usr/bin/env bash

function provider_values() {
  echo "1"
  echo "2"
  echo "3"
}

# @data_provider provider_values
function test_provided() {
  assert_not_empty "$1"
}
