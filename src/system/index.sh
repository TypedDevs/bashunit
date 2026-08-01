#!/usr/bin/env bash

# Entry point for the src/system/ module: only `source` lines and comments belong
# here. build.sh emits a file's body before recursing into its `source` lines, so
# any statement here would run before its dependencies in the built binary
# (adrs/adr-010-src-module-directories.md).
#
# Capability probing: what this machine is and what it has. The bottom layer --
# nothing here touches config, test state, console or the runner.
source "$BASHUNIT_ROOT_DIR/src/system/check_os.sh"
source "$BASHUNIT_ROOT_DIR/src/system/dependencies.sh"
source "$BASHUNIT_ROOT_DIR/src/system/io.sh"
