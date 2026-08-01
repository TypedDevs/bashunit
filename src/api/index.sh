#!/usr/bin/env bash

# Entry point for the src/api/ module. `source` lines and comments only,
# for the reason recorded in adrs/adr-011-source-layout-and-build-pipeline.md.
#
# The surface a user's test file calls: temp_file/temp_dir/current_dir/data_set,
# skip/todo, set_test_title, and the custom-assert facade (assert_that,
# assert_once, assertion_failed/passed). Assertions are the other half of that
# surface and live in src/assert/, which is large enough to be its own module.
#
# globals.sh MUST stay first: it runs `set -euo pipefail` at file scope, so every
# file sourced after it inherits strict mode. This module is sourced at the
# position globals.sh held on its own, which keeps that boundary where it was.
source "$BASHUNIT_ROOT_DIR/src/api/globals.sh"
source "$BASHUNIT_ROOT_DIR/src/api/skip_todo.sh"
source "$BASHUNIT_ROOT_DIR/src/api/test_title.sh"
source "$BASHUNIT_ROOT_DIR/src/api/bashunit.sh"
