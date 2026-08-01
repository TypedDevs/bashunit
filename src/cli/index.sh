#!/usr/bin/env bash

# Entry point for the src/cli/ module. `source` lines and comments only,
# for the reason recorded in adrs/adr-011-source-layout-and-build-pipeline.md.
#
# The `bashunit <subcommand>` implementations. main.sh is their only caller; it
# stays flat as the dispatcher. benchmark.sh is deliberately not here: the runner
# calls it too (src/runner/bench.sh), so it is a shared implementation rather
# than purely a subcommand.
#
# Order matches the entrypoint's before this module existed.
source "$BASHUNIT_ROOT_DIR/src/cli/upgrade.sh"
source "$BASHUNIT_ROOT_DIR/src/cli/watch.sh"
source "$BASHUNIT_ROOT_DIR/src/cli/doc.sh"
source "$BASHUNIT_ROOT_DIR/src/cli/init.sh"
