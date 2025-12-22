#!/usr/bin/env bash

# @revs=5 @its=2 @max_ms=25
function bench_sleep() {
  sleep 0.001
}

# @revolutions=3 @iterations=2
function bench_sleep_synonym() {
  sleep 0.005
}

# No annotations - should use defaults (revs=1, its=1)
function bench_no_annotations() {
  sleep 0.001
}

# Only revs annotation
# @revs=10
function bench_only_revs() {
  sleep 0.001
}

# Only its annotation
# @its=5
function bench_only_its() {
  sleep 0.001
}

# Only max_ms annotation
# @max_ms=100
function bench_only_max_ms() {
  sleep 0.001
}

# Slow function that will exceed threshold
# @max_ms=1
function bench_slow_for_threshold() {
  sleep 0.02
}
