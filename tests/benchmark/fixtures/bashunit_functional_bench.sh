#!/usr/bin/env bash

# @revs=2 @its=1
function bench_run_bashunit_functional() {
  ./bashunit tests/functional/for_bench_test.sh -s -p >/dev/null
}
