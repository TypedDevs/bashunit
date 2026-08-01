#!/usr/bin/env bash

# Entry point for the src/main/ module. `source` lines and comments only,
# for the reason recorded in adrs/adr-011-source-layout-and-build-pipeline.md.
#
# The CLI layer: flag parsing per subcommand, plus the run lifecycle it drives.
# The `cmd_*` parsers stay together rather than moving next to their src/cli/
# implementations -- that would put two namespaces in one file, and renaming is
# not on the table. Parsing is its own concern, and it owns the shared *_or_exit
# validators.
#
# Sourced leaves first: validate <- run <- watch, with test and bench on top.
source "$BASHUNIT_ROOT_DIR/src/main/validate.sh"
source "$BASHUNIT_ROOT_DIR/src/main/run.sh"
source "$BASHUNIT_ROOT_DIR/src/main/watch.sh"
source "$BASHUNIT_ROOT_DIR/src/main/assert.sh"
source "$BASHUNIT_ROOT_DIR/src/main/subcommands.sh"
source "$BASHUNIT_ROOT_DIR/src/main/bench.sh"
source "$BASHUNIT_ROOT_DIR/src/main/test.sh"
