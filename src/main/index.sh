#!/usr/bin/env bash

# Entry point for the src/main/ module: only `source` lines and comments belong
# here. build.sh emits a file's body before recursing into its `source` lines, so
# any statement here would run before its dependencies in the built binary
# (adrs/adr-010-src-module-directories.md).
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
