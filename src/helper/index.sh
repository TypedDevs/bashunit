#!/usr/bin/env bash

# Entry point for the src/helper/ module. `source` lines and comments only,
# for the reason recorded in adrs/adr-011-source-layout-and-build-pipeline.md.
#
# Sourced leaves first; only discovery.sh has cross-file callees (provider.sh
# and functions.sh).
source "$BASHUNIT_ROOT_DIR/src/helper/naming.sh"
source "$BASHUNIT_ROOT_DIR/src/helper/encoding.sh"
source "$BASHUNIT_ROOT_DIR/src/helper/functions.sh"
source "$BASHUNIT_ROOT_DIR/src/helper/git.sh"
source "$BASHUNIT_ROOT_DIR/src/helper/annotations.sh"
source "$BASHUNIT_ROOT_DIR/src/helper/provider.sh"
source "$BASHUNIT_ROOT_DIR/src/helper/tags.sh"
source "$BASHUNIT_ROOT_DIR/src/helper/discovery.sh"
