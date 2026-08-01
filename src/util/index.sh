#!/usr/bin/env bash

# Entry point for the src/util/ module. `source` lines and comments only,
# for the reason recorded in adrs/adr-011-source-layout-and-build-pipeline.md.
#
# Computation: strings, arithmetic and time. math.sh and clock.sh probe for bc,
# awk and a sub-second clock through src/system/dependencies.sh, so the edge runs
# util -> system and never back.
source "$BASHUNIT_ROOT_DIR/src/util/str.sh"
source "$BASHUNIT_ROOT_DIR/src/util/math.sh"
source "$BASHUNIT_ROOT_DIR/src/util/clock.sh"
