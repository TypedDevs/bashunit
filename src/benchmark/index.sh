#!/usr/bin/env bash

# Entry point for the src/benchmark/ module: only `source` lines and comments
# belong here. build.sh emits a file's body before recursing into its `source`
# lines, so any statement here would run before its dependencies in the built
# binary (adrs/adr-010-src-module-directories.md).
#
# The bench implementation. src/runner/bench.sh is the file and function loop
# that drives it; this is what each bench function actually does.
#
# results.sh first: it declares the _BASHUNIT_BENCH_* arrays that add_result
# writes and print_results reads, and run.sh calls add_result.
source "$BASHUNIT_ROOT_DIR/src/benchmark/results.sh"
source "$BASHUNIT_ROOT_DIR/src/benchmark/annotations.sh"
source "$BASHUNIT_ROOT_DIR/src/benchmark/run.sh"
