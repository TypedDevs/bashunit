#!/usr/bin/env bash

# Aggregator for the src/coverage/ module: only `source` lines and comments
# belong here. build.sh emits a file's body before recursing into its `source`
# lines, so any statement here would run before its dependencies in the built
# binary (adrs/adr-010-src-module-directories.md).
#
# Sourced in dependency layers, leaves first:
#   config · paths · lines · functions → engine · stats · branches
#     → report_text · report_lcov · report_html → html_index · html_file
source "$BASHUNIT_ROOT_DIR/src/coverage/config.sh"
source "$BASHUNIT_ROOT_DIR/src/coverage/paths.sh"
source "$BASHUNIT_ROOT_DIR/src/coverage/lines.sh"
source "$BASHUNIT_ROOT_DIR/src/coverage/functions.sh"
source "$BASHUNIT_ROOT_DIR/src/coverage/engine.sh"
source "$BASHUNIT_ROOT_DIR/src/coverage/stats.sh"
source "$BASHUNIT_ROOT_DIR/src/coverage/branches.sh"
source "$BASHUNIT_ROOT_DIR/src/coverage/report_text.sh"
source "$BASHUNIT_ROOT_DIR/src/coverage/report_lcov.sh"
source "$BASHUNIT_ROOT_DIR/src/coverage/report_html.sh"
source "$BASHUNIT_ROOT_DIR/src/coverage/html_index.sh"
source "$BASHUNIT_ROOT_DIR/src/coverage/html_file.sh"
