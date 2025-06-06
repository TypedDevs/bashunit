#!/usr/bin/env bash

# @revs=5 @its=2
function bench_sleep() {
  sleep 0.01
}

# @revolutions=3 @iterations=2
function bench_sleep_synonym() {
  sleep 0.005
}
