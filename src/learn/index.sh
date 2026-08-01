#!/usr/bin/env bash

# Interactive learning module for bashunit: guided tutorials and exercises.
#
# Entry point for the src/learn/ module. `source` lines and comments only,
# for the reason recorded in adrs/adr-011-source-layout-and-build-pipeline.md.
#
# Sourced in dependency layers, leaves first:
#   progress -> session -> lessons -> menu
# Every lesson calls only session's create_example_file and run_lesson_test; no
# lesson calls another, so the ten are mutually independent.
source "$BASHUNIT_ROOT_DIR/src/learn/progress.sh"
source "$BASHUNIT_ROOT_DIR/src/learn/session.sh"
source "$BASHUNIT_ROOT_DIR/src/learn/lessons/basics.sh"
source "$BASHUNIT_ROOT_DIR/src/learn/lessons/assertions.sh"
source "$BASHUNIT_ROOT_DIR/src/learn/lessons/lifecycle.sh"
source "$BASHUNIT_ROOT_DIR/src/learn/lessons/functions.sh"
source "$BASHUNIT_ROOT_DIR/src/learn/lessons/scripts.sh"
source "$BASHUNIT_ROOT_DIR/src/learn/lessons/mocking.sh"
source "$BASHUNIT_ROOT_DIR/src/learn/lessons/spies.sh"
source "$BASHUNIT_ROOT_DIR/src/learn/lessons/data_providers.sh"
source "$BASHUNIT_ROOT_DIR/src/learn/lessons/exit_codes.sh"
source "$BASHUNIT_ROOT_DIR/src/learn/lessons/challenge.sh"
source "$BASHUNIT_ROOT_DIR/src/learn/menu.sh"
