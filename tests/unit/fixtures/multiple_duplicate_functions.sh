#!/usr/bin/env bash
# shellcheck disable=SC2317
# shellcheck disable=SC2329

function test_beta() {
  echo "beta"
}

function test_alpha() {
  echo "alpha"
}

function test_beta() {
  echo "beta duplicate"
}

test_alpha() {
  echo "alpha duplicate without function keyword"
}

function test_gamma() {
  echo "gamma appears once"
}
