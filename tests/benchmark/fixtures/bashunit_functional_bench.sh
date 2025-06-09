#!/usr/bin/env bash

# @revs=2 @its=1 @max_ms=300
function bench_run_bashunit_functional() {
  ./bashunit tests/functional/for_bench_test.sh -s -p >/dev/null
}
