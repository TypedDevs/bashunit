#!/usr/bin/env bash

# shellcheck disable=SC2155

function set_up() {
  export BASHUNIT_SIMPLE_OUTPUT=false
}

function test_successful_assert_file_exists() {
  local a_file="$(bashunit::current_dir)/$(bashunit::current_filename)"

  assert_empty "$(assert_file_exists "$a_file")"
}

function test_unsuccessful_assert_file_exists() {
  local a_file="a_random_file_that_will_not_exist"

  local expected
  expected="$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert file exists" "$a_file" "to exist but" "do not exist")"
  assert_same "$expected" "$(assert_file_exists "$a_file")"
}

function test_assert_file_exists_should_not_work_with_folders() {
  local a_dir="$(bashunit::current_dir)"

  assert_same "$(bashunit::console_results::print_failed_test \
    "Assert file exists should not work with folders" "$a_dir" "to exist but" "do not exist")" \
    "$(assert_file_exists "$a_dir")"
}

function test_successful_assert_file_not_exists() {
  local a_file="a_random_file_that_will_not_exist"

  assert_empty "$(assert_file_not_exists "$a_file")"
}

function test_unsuccessful_assert_file_not_exists() {
  local a_file="$(bashunit::current_dir)/$(bashunit::current_filename)"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert file not exists" "$a_file" "to not exist but" "the file exists")" \
    "$(assert_file_not_exists "$a_file")"
}

function test_successful_assert_is_file() {
  local a_file="$(bashunit::current_dir)/$(bashunit::current_filename)"

  assert_empty "$(assert_is_file "$a_file")"
}

function test_unsuccessful_assert_is_file() {
  local a_file="a_random_file_that_will_not_exist"

  local expected
  expected="$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert is file" "$a_file" "to be a file" "but is not a file")"
  assert_same "$expected" "$(assert_is_file "$a_file")"
}

function test_unsuccessful_assert_is_file_when_a_folder_is_given() {
  local a_folder="$(bashunit::current_dir)"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert is file when a folder is given" "$a_folder" "to be a file" "but is not a file")" \
    "$(assert_is_file "$a_folder")"
}

function test_successful_assert_is_file_empty() {
  local path="/tmp/a_random_file_$(date +%s)"
  touch "$path"

  assert_empty "$(assert_is_file_empty "$path")"

  rm "$path"
}

function test_unsuccessful_assert_is_file_empty() {
  local a_file="$(bashunit::current_dir)/$(bashunit::current_filename)"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert is file empty" "$a_file" "to be empty" "but is not empty")" \
    "$(assert_is_file_empty "$a_file")"
}

# shellcheck disable=SC2155
function test_successful_assert_files_equals() {
  local expected="/tmp/test_successful_assert_files_equals_1"
  local actual="/tmp/test_successful_assert_files_equals_2"

  local file_content="My multiline file
  Special char: \$, \*, and \\

  another extra line"

  echo "$file_content" >"$expected"
  echo "$file_content" >"$actual"

  assert_empty "$(assert_files_equals "$expected" "$actual")"

  rm "$expected"
  rm "$actual"
}

# shellcheck disable=SC2155
function test_fails_assert_files_equals() {
  local expected="/tmp/test_fails_assert_files_equals_1"
  local actual="/tmp/test_fails_assert_files_equals_2"

  echo -e "same\noriginal content" >"$expected"
  echo -e "same\ndifferent content" >"$actual"

  assert_contains "Fails assert files equals" \
    "$(assert_files_equals "$expected" "$actual")"

  rm "$expected"
  rm "$actual"
}

# shellcheck disable=SC2155
function test_successful_assert_files_not_equals() {
  local expected="/tmp/test_successful_assert_files_not_equals_1"
  local actual="/tmp/test_successful_assert_files_not_equals_2"

  echo -e "same\noriginal content" >"$expected"
  echo -e "same\ndifferent content" >"$actual"

  assert_empty "$(assert_files_not_equals "$expected" "$actual")"

  rm "$expected"
  rm "$actual"
}

# shellcheck disable=SC2155
function test_fails_assert_files_not_equals() {
  local expected="/tmp/test_fails_assert_files_not_equals_1"
  local actual="/tmp/test_fails_assert_files_not_equals_2"

  echo "same content" >"$expected"
  echo "same content" >"$actual"

  assert_contains "Files are equals" \
    "$(assert_files_not_equals "$expected" "$actual")"

  rm "$expected"
  rm "$actual"
}

function test_successful_assert_file_contains() {
  local file="/tmp/test_successful_assert_file_contains"
  echo -e "original content" >"$file"

  assert_successful_code "$(assert_file_contains "$file" "original content")"

  rm "$file"
}

function test_fails_assert_file_contains() {
  local file="/tmp/test_fail_assert_file_contains"
  echo -e "original content" >"$file"

  assert_contains \
    "$(bashunit::console_results::print_failed_test "Fails assert file contains" \
    "${file}" "to contain" "non-existing-str")" \
    "$(assert_file_contains "$file" "non-existing-str")"

  rm "$file"
}

function test_successful_assert_file_not_contains() {
  local file="/tmp/test_successful_assert_file_not_contains"
  echo -e "original content" >"$file"

  assert_successful_code "$(assert_file_not_contains "$file" "non-existing-str")"

  rm "$file"
}

function test_fails_assert_file_not_contains() {
  local file="/tmp/test_fails_assert_file_not_contains"
  echo -e "original content" >"$file"

  assert_contains \
    "$(bashunit::console_results::print_failed_test "Fails assert file not contains" \
    "${file}" "to not contain" "original content")" \
    "$(assert_file_not_contains "$file" "original content")"

  rm "$file"
}

# shellcheck disable=SC2155
function test_successful_assert_file_permissions() {
  bashunit::skip_on windows "Git Bash fakes POSIX permissions"

  local file="/tmp/test_successful_assert_file_permissions_$$"
  touch "$file"
  chmod 600 "$file"

  assert_empty "$(assert_file_permissions "600" "$file")"

  rm "$file"
}

# shellcheck disable=SC2155
function test_successful_assert_file_permissions_accepts_leading_zero() {
  bashunit::skip_on windows "Git Bash fakes POSIX permissions"

  local file="/tmp/test_assert_file_permissions_leading_zero_$$"
  touch "$file"
  chmod 755 "$file"

  assert_empty "$(assert_file_permissions "0755" "$file")"

  rm "$file"
}

# shellcheck disable=SC2155
function test_unsuccessful_assert_file_permissions() {
  bashunit::skip_on windows "Git Bash fakes POSIX permissions"

  local file="/tmp/test_unsuccessful_assert_file_permissions_$$"
  touch "$file"
  chmod 600 "$file"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert file permissions" "$file" "to have permissions 644" "but got 600")" \
    "$(assert_file_permissions "644" "$file")"

  rm "$file"
}

function test_unsuccessful_assert_file_permissions_when_file_does_not_exist() {
  local file="a_random_file_that_will_not_exist"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert file permissions when file does not exist" \
    "$file" "to have permissions 644" "but the file does not exist")" \
    "$(assert_file_permissions "644" "$file")"
}

# Symlinks are invisible to every other filesystem assertion: -f and -e follow
# the link, so a link and its target look identical, and a dangling link reads
# as "does not exist" -- the same as a path that was never created.
function symlink_fixture_dir() {
  bashunit::temp_dir
}

function test_successful_assert_is_symlink() {
  bashunit::skip_on windows "Git Bash does not create real symlinks"
  local dir
  dir=$(symlink_fixture_dir)
  : >"$dir/target"
  ln -s "$dir/target" "$dir/link"

  assert_empty "$(assert_is_symlink "$dir/link")"
}

# The case nothing covers today: a link whose target is gone is still a link.
function test_successful_assert_is_symlink_when_the_target_is_missing() {
  bashunit::skip_on windows "Git Bash does not create real symlinks"
  local dir
  dir=$(symlink_fixture_dir)
  ln -s "$dir/never_created" "$dir/dangling"

  assert_empty "$(assert_is_symlink "$dir/dangling")"
}

function test_unsuccessful_assert_is_symlink_on_a_regular_file() {
  bashunit::skip_on windows "Git Bash does not create real symlinks"
  local dir
  dir=$(symlink_fixture_dir)
  : >"$dir/plain"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert is symlink on a regular file" \
      "$dir/plain" "to be a symlink" "but is not a symlink")" \
    "$(assert_is_symlink "$dir/plain")"
}

function test_successful_assert_is_not_symlink() {
  bashunit::skip_on windows "Git Bash does not create real symlinks"
  local dir
  dir=$(symlink_fixture_dir)
  : >"$dir/plain"

  assert_empty "$(assert_is_not_symlink "$dir/plain")"
}

function test_unsuccessful_assert_is_not_symlink() {
  bashunit::skip_on windows "Git Bash does not create real symlinks"
  local dir
  dir=$(symlink_fixture_dir)
  : >"$dir/target"
  ln -s "$dir/target" "$dir/link"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert is not symlink" \
      "$dir/link" "not to be a symlink" "but is a symlink")" \
    "$(assert_is_not_symlink "$dir/link")"
}

function test_successful_assert_symlink_to() {
  bashunit::skip_on windows "Git Bash does not create real symlinks"
  local dir
  dir=$(symlink_fixture_dir)
  : >"$dir/target"
  ln -s "$dir/target" "$dir/link"

  assert_empty "$(assert_symlink_to "$dir/target" "$dir/link")"
}

function test_unsuccessful_assert_symlink_to_reports_both_targets() {
  bashunit::skip_on windows "Git Bash does not create real symlinks"
  local dir
  dir=$(symlink_fixture_dir)
  : >"$dir/target"
  ln -s "$dir/target" "$dir/link"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert symlink to reports both targets" \
      "$dir/other" "to be the target of ${dir}/link, but got " "$dir/target")" \
    "$(assert_symlink_to "$dir/other" "$dir/link")"
}

function test_unsuccessful_assert_symlink_to_on_a_regular_file() {
  bashunit::skip_on windows "Git Bash does not create real symlinks"
  local dir
  dir=$(symlink_fixture_dir)
  : >"$dir/plain"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert symlink to on a regular file" \
      "$dir/plain" "to be a symlink" "but is not a symlink")" \
    "$(assert_symlink_to "$dir/whatever" "$dir/plain")"
}
