#!/usr/bin/env bash

# Entry point for the src/runner/ module. `source` lines and comments only,
# for the reason recorded in adrs/adr-011-source-layout-and-build-pipeline.md.
#
# Sourced in dependency layers, leaves first:
#   context · payload · diagnostics → parallel · hooks · result → provider · exec
#   → list → discovery · bench
source "$BASHUNIT_ROOT_DIR/src/runner/context.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/payload.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/diagnostics.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/parallel.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/hooks.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/result.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/provider.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/exec.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/list.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/discovery.sh"
source "$BASHUNIT_ROOT_DIR/src/runner/bench.sh"
