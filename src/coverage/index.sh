#!/usr/bin/env bash

# Entry point for the src/coverage/ module. `source` lines and comments only,
# for the reason recorded in adrs/adr-011-source-layout-and-build-pipeline.md.
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
source "$BASHUNIT_ROOT_DIR/src/coverage/diff.sh"
source "$BASHUNIT_ROOT_DIR/src/coverage/report_lcov.sh"
source "$BASHUNIT_ROOT_DIR/src/coverage/report_html.sh"
source "$BASHUNIT_ROOT_DIR/src/coverage/html_index.sh"
source "$BASHUNIT_ROOT_DIR/src/coverage/html_file.sh"
