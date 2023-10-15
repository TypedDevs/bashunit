#!/bin/bash

function tear_down() {
  rm -f ./lib/bashunit
  rm -f ./deps/bashunit
}

function test_install_downloads_the_latest_version() {
  local install_dir="./lib/bashunit"
  local output

  output="$(./install.sh 2>/dev/null)"

  assert_file_exists "$install_dir"
  assert_string_starts_with "$(printf "\e[1m\e[32mbashunit\e[0m - ")" "$("$install_dir" --version)"
  todo "the output message folder is wrong"
  assert_equals\
    "$(printf "> Using latest version\nBuild complete. bashunit has been generated in the bin folder.")"\
    "$output"
}

function test_install_downloads_in_given_folder() {
  local install_dir="./deps/bashunit"
  local output

  output="$(./install.sh deps 2>/dev/null)"

  assert_file_exists "$install_dir"
  assert_string_starts_with "$(printf "\e[1m\e[32mbashunit\e[0m - ")" "$("$install_dir" --version)"
  todo "the output message folder is wrong"
  assert_equals\
    "$(printf "> Using latest version\nBuild complete. bashunit has been generated in the bin folder.")"\
    "$output"
}

function test_install_downloads_the_given_version() {
  local install_dir="./lib/bashunit"
  local output

  output="$(./install.sh lib 0.8.0 2>/dev/null)"

  assert_file_exists "$install_dir"
  assert_equals "$(printf "\e[1m\e[32mbashunit\e[0m - 0.8.0")" "$("$install_dir" --version)"
  assert_equals\
    "$(printf "> Using a concrete version: '0.8.0'")"\
    "$output"
}
