#!/usr/bin/env bash
# shellcheck disable=SC2155

function test_successful_assert_directory_exists() {
  local a_directory="$(current_dir)"

  assert_empty "$(assert_directory_exists "$a_directory")"
}

function test_unsuccessful_assert_directory_exists() {
  local a_directory="a_random_directory_that_will_not_exist"

  assert_same\
    "$(console_results::print_failed_test\
      "Unsuccessful assert directory exists" "$a_directory" "to exist but" "do not exist")"\
    "$(assert_directory_exists "$a_directory")"
}

function test_assert_directory_exists_should_not_work_with_files() {
  local a_file="$(current_dir)/$(current_filename)"

  assert_same\
    "$(console_results::print_failed_test \
      "Assert directory exists should not work with files" "$a_file" "to exist but" "do not exist")"\
    "$(assert_directory_exists "$a_file")"
}

function test_successful_assert_directory_not_exists() {
  local a_directory="a_random_directory_that_will_not_exist"

  assert_empty "$(assert_directory_not_exists "$a_directory")"
}

function test_unsuccessful_assert_directory_not_exists() {
  local a_directory="$(current_dir)"

  assert_same\
    "$(console_results::print_failed_test \
      "Unsuccessful assert directory not exists" "$a_directory" "to not exist but" "the directory exists")"\
    "$(assert_directory_not_exists "$a_directory")"
}

function test_successful_assert_is_directory() {
  local a_directory="$(current_dir)"

  assert_empty "$(assert_is_directory "$a_directory")"
}

function test_unsuccessful_assert_is_directory() {
  local a_directory="a_random_directory_that_will_not_exist"

  assert_same\
    "$(console_results::print_failed_test \
      "Unsuccessful assert is directory" "$a_directory" "to be a directory" "but is not a directory")"\
    "$(assert_is_directory "$a_directory")"
}

function test_unsuccessful_assert_is_directory_when_a_file_is_given() {
  local a_file="$(current_dir)/$(current_filename)"

  assert_same\
    "$(console_results::print_failed_test\
      "Unsuccessful assert is directory when a file is given" "$a_file" "to be a directory" "but is not a directory")"\
    "$(assert_is_directory "$a_file")"
}

function test_successful_assert_is_directory_empty() {
  local a_directory=$(mktemp -d)

  assert_empty "$(assert_is_directory_empty "$a_directory")"
}

function test_unsuccessful_assert_is_directory_empty() {
  local a_directory="$(current_dir)"

  assert_same\
    "$(console_results::print_failed_test \
      "Unsuccessful assert is directory empty" "$a_directory" "to be empty" "but is not empty")"\
    "$(assert_is_directory_empty "$a_directory")"
}

function test_successful_assert_is_directory_not_empty() {
  local a_directory="$(current_dir)"

  assert_empty "$(assert_is_directory_not_empty "$a_directory")"
}

function test_unsuccessful_assert_is_directory_not_empty() {
  local a_directory=$(mktemp -d)

  assert_same\
    "$(console_results::print_failed_test \
      "Unsuccessful assert is directory not empty" "$a_directory" "to not be empty" "but is empty")"\
    "$(assert_is_directory_not_empty "$a_directory")"
}

function test_successful_assert_is_directory_readable() {
  local a_directory=$(mktemp -d)

  assert_empty "$(assert_is_directory_readable "$a_directory")"
}

function test_unsuccessful_assert_is_directory_readable_when_a_file_is_given() {
  local a_file="$(current_dir)/$(current_filename)"

  assert_same\
    "$(console_results::print_failed_test\
      "Unsuccessful assert is directory readable when a file is given" \
      "$a_file" "to be readable" "but is not readable")"\
    "$(assert_is_directory_readable "$a_file")"
}

function test_unsuccessful_assert_is_directory_readable_without_execution_permission() {
  if [[ "$_OS" == "Windows" || $_DISTRO = "Alpine" || $(id -u) -eq 0 ]]; then
    return
  fi

  local a_directory=$(mktemp -d)
  chmod a-x "$a_directory"

  assert_same\
    "$(console_results::print_failed_test \
      "Unsuccessful assert is directory readable without execution permission" \
      "$a_directory" "to be readable" "but is not readable")"\
    "$(assert_is_directory_readable "$a_directory")"
}

function test_unsuccessful_assert_is_directory_readable_without_read_permission() {
  if [[ "$_OS" == "Windows" || $_DISTRO = "Alpine" || $(id -u) -eq 0 ]]; then
      return
  fi

  local a_directory=$(mktemp -d)
  chmod a-r "$a_directory"

  assert_same\
    "$(console_results::print_failed_test \
      "Unsuccessful assert is directory readable without read permission" \
      "$a_directory" "to be readable" "but is not readable")"\
    "$(assert_is_directory_readable "$a_directory")"
}

function test_successful_assert_is_directory_not_readable_without_read_permission() {
  if [[ "$_OS" == "Windows" || $_DISTRO = "Alpine" || $(id -u) -eq 0 ]]; then
      return
  fi

  local a_directory=$(mktemp -d)
  chmod a-r "$a_directory"

  assert_empty "$(assert_is_directory_not_readable "$a_directory")"
}

function test_successful_assert_is_directory_not_readable_without_execution_permission() {
  if [[ "$_OS" == "Windows" || $_DISTRO = "Alpine" || $(id -u) -eq 0 ]]; then
      return
  fi

  local a_directory=$(mktemp -d)
  chmod a-x "$a_directory"

  assert_empty "$(assert_is_directory_not_readable "$a_directory")"
}

function test_unsuccessful_assert_is_directory_not_readable() {
  local a_directory=$(mktemp -d)

  assert_same\
    "$(console_results::print_failed_test \
      "Unsuccessful assert is directory not readable" "$a_directory" "to be not readable" "but is readable")"\
    "$(assert_is_directory_not_readable "$a_directory")"
}

function test_successful_assert_is_directory_writable() {
  local a_directory=$(mktemp -d)

  assert_empty "$(assert_is_directory_writable "$a_directory")"
}

function test_unsuccessful_assert_is_directory_writable() {
  if [[ "$_OS" == "Windows" || $_DISTRO = "Alpine" || $(id -u) -eq 0 ]]; then
      return
  fi

  local a_directory=$(mktemp -d)
  chmod a-w "$a_directory"

  assert_same\
    "$(console_results::print_failed_test \
      "Unsuccessful assert is directory writable" "$a_directory" "to be writable" "but is not writable")"\
    "$(assert_is_directory_writable "$a_directory")"
}

function test_unsuccessful_assert_is_directory_writable_when_a_file_is_given() {
  local a_file="$(current_dir)/$(current_filename)"

  assert_same\
    "$(console_results::print_failed_test\
      "Unsuccessful assert is directory writable when a file is given" \
      "$a_file" "to be writable" "but is not writable")"\
    "$(assert_is_directory_writable "$a_file")"
}

function test_successful_assert_is_directory_not_writable() {
  if [[ "$_OS" == "Windows" || $_DISTRO = "Alpine" || $(id -u) -eq 0 ]]; then
      return
  fi

  local a_directory=$(mktemp -d)
  chmod a-w "$a_directory"

  assert_empty "$(assert_is_directory_not_writable "$a_directory")"
}

function test_unsuccessful_assert_is_directory_not_writable() {
  local a_directory=$(mktemp -d)

  assert_same\
    "$(console_results::print_failed_test\
      "Unsuccessful assert is directory not writable" \
      "$a_directory" "to be not writable" "but is writable")"\
    "$(assert_is_directory_not_writable "$a_directory")"
}
