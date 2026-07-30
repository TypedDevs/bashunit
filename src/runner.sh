#!/usr/bin/env bash

# Aggregator for the src/runner/ module: only `source` lines and comments belong
# here. build.sh emits a file's body before recursing into its `source` lines, so
# any statement here would run before its dependencies in the built binary.
#
# Sourced in dependency layers, leaves first:
#   context · payload · diagnostics → parallel · hooks · result → provider · exec → discovery · bench
source "$BASHUNIT_ROOT_DIR/src/runner/context.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/payload.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/diagnostics.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/parallel.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/hooks.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/result.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/provider.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/exec.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/discovery.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/bench.sh"
