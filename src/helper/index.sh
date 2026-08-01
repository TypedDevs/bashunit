#!/usr/bin/env bash

# Entry point for the src/helper/ module: only `source` lines and comments
# belong here. build.sh emits a file's body before recursing into its `source`
# lines, so any statement here would run before its dependencies in the built
# binary (adrs/adr-010-src-module-directories.md).
#
# Sourced leaves first; only discovery.sh has cross-file callees (provider.sh
# and functions.sh).
source "$BASHUNIT_ROOT_DIR/src/helper/naming.sh"
source "$BASHUNIT_ROOT_DIR/src/helper/encoding.sh"
source "$BASHUNIT_ROOT_DIR/src/helper/functions.sh"
source "$BASHUNIT_ROOT_DIR/src/helper/git.sh"
source "$BASHUNIT_ROOT_DIR/src/helper/provider.sh"
source "$BASHUNIT_ROOT_DIR/src/helper/tags.sh"
source "$BASHUNIT_ROOT_DIR/src/helper/discovery.sh"
