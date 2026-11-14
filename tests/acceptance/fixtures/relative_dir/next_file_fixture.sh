#!/usr/bin/env bash

function test_next_file_starts_in_the_original_directory() {
  assert_file_exists "./tests/acceptance/fixtures/relative_dir/lib.sh"
}
