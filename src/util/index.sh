#!/usr/bin/env bash

# Entry point for the src/util/ module: only `source` lines and comments belong
# here. build.sh emits a file's body before recursing into its `source` lines, so
# any statement here would run before its dependencies in the built binary
# (adrs/adr-010-src-module-directories.md).
#
# Computation: strings, arithmetic and time. math.sh and clock.sh probe for bc,
# awk and a sub-second clock through src/system/dependencies.sh, so the edge runs
# util -> system and never back.
source "$BASHUNIT_ROOT_DIR/src/util/str.sh"
source "$BASHUNIT_ROOT_DIR/src/util/math.sh"
source "$BASHUNIT_ROOT_DIR/src/util/clock.sh"
