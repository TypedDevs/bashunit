#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(bashunit::current_dir)/lib.sh"

function test_sources_a_file_next_to_the_test() {
  assert_same "hello from lib" "$(relative_dir_greeting)"
}
