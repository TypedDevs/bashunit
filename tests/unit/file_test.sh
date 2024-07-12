#!/bin/bash

function test_successful_assert_file_exists() {
  local a_file
  a_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

  assert_empty "$(assert_file_exists "$a_file")"
}

function test_unsuccessful_assert_file_exists() {
  local a_file="a_random_file_that_will_not_exist"

  assert_equals\
    "$(console_results::print_failed_test "Unsuccessful assert file exists" "$a_file" "to exist but" "do not exist")"\
    "$(assert_file_exists "$a_file")"
}

function test_assert_file_exists_should_not_work_with_folders() {
  local a_dir
  a_dir="$(dirname "${BASH_SOURCE[0]}")"

  assert_equals\
    "$(console_results::print_failed_test \
      "Assert file exists should not work with folders" "$a_dir" "to exist but" "do not exist")"\
    "$(assert_file_exists "$a_dir")"
}

function test_successful_assert_file_not_exists() {
  local a_file="a_random_file_that_will_not_exist"

  assert_empty "$(assert_file_not_exists "$a_file")"
}

function test_unsuccessful_assert_file_not_exists() {
  local a_file
  a_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

  assert_equals\
    "$(console_results::print_failed_test\
      "Unsuccessful assert file not exists" "$a_file" "to not exist but" "the file exists")"\
    "$(assert_file_not_exists "$a_file")"
}

function test_successful_assert_is_file() {
  local a_file
  a_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

  assert_empty "$(assert_is_file "$a_file")"
}

function test_unsuccessful_assert_is_file() {
  local a_file="a_random_file_that_will_not_exist"

  assert_equals\
    "$(console_results::print_failed_test "Unsuccessful assert is file" "$a_file" "to be a file" "but is not a file")"\
    "$(assert_is_file "$a_file")"
}

function test_unsuccessful_assert_is_file_when_a_folder_is_given() {
  local a_folder
  a_folder="$(dirname "${BASH_SOURCE[0]}")"

  assert_equals\
    "$(console_results::print_failed_test\
      "Unsuccessful assert is file when a folder is given" "$a_folder" "to be a file" "but is not a file")"\
    "$(assert_is_file "$a_folder")"
}

function test_successful_assert_is_file_empty() {
  readonly path="/tmp/a_random_file_$(date +%s)"
  touch "$path"

  assert_empty "$(assert_is_file_empty "$path")"

  rm "$path"
}

function test_unsuccessful_assert_is_file_empty() {
  local a_file
  a_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

  assert_equals\
    "$(console_results::print_failed_test\
      "Unsuccessful assert is file empty" "$a_file" "to be empty" "but is not empty")"\
    "$(assert_is_file_empty "$a_file")"
}
