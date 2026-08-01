#!/usr/bin/env bash

# Entry point for the src/system/ module. `source` lines and comments only,
# for the reason recorded in adrs/adr-011-source-layout-and-build-pipeline.md.
#
# Capability probing: what this machine is and what it has. The bottom layer --
# nothing here touches config, test state, console or the runner.
source "$BASHUNIT_ROOT_DIR/src/system/check_os.sh"
source "$BASHUNIT_ROOT_DIR/src/system/dependencies.sh"
source "$BASHUNIT_ROOT_DIR/src/system/io.sh"
