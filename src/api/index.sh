#!/usr/bin/env bash

# Entry point for the src/api/ module: only `source` lines and comments belong
# here. build.sh emits a file's body before recursing into its `source` lines, so
# any statement here would run before its dependencies in the built binary
# (adrs/adr-010-src-module-directories.md).
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
