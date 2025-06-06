#!/usr/bin/env bash

# @revs=3 @its=2
function bench_run_bashunit_functional() {
  ./bashunit tests/functional -s -p >/dev/null
}
