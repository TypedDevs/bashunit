#!/bin/bash

function tear_down() {
  rm -f ./lib/bashunit
  rm -f ./deps/bashunit
}

function test_install_downloads_the_latest_version() {
  local install_dir="./lib/bashunit"
  local output

  output="$(./install.sh)"

  assert_string_starts_with "$(printf "> Downloading the latest version: '")" "$output"
  assert_string_ends_with "$(printf "\n> bashunit has been installed in the 'lib' folder")" "$output"
  assert_file_exists "$install_dir"
  assert_string_starts_with "$(printf "\e[1m\e[32mbashunit\e[0m - ")" "$("$install_dir" --version)"
}

function test_install_downloads_in_given_folder() {
  local install_dir="./deps/bashunit"
  local output

  output="$(./install.sh deps)"

  assert_string_starts_with "$(printf "> Downloading the latest version: '")" "$output"
  assert_string_ends_with "$(printf "\n> bashunit has been installed in the 'deps' folder")" "$output"
  assert_file_exists "$install_dir"
  assert_string_starts_with "$(printf "\e[1m\e[32mbashunit\e[0m - ")" "$("$install_dir" --version)"
}

function test_install_downloads_the_given_version() {
  local install_dir="./lib/bashunit"
  local output

  output="$(./install.sh lib 0.8.0)"

  assert_equals\
    "$(printf "> Downloading a concrete version: '0.8.0'\n> bashunit has been installed in the 'lib' folder")"\
    "$output"
  assert_file_exists "$install_dir"
  assert_equals "$(printf "\e[1m\e[32mbashunit\e[0m - 0.8.0")" "$("$install_dir" --version)"
}

function test_install_downloads_the_main_version() {
  mock git "cp -r .. temp"
  local install_dir="./lib/bashunit"
  local output

  output="$(./install.sh lib main)"

  assert_contains "Downloading non-stable main" "$output"
  assert_contains "bashunit has been installed in the 'lib' folder" "$output"
  assert_file_exists "$install_dir"
  assert_equals "$(printf "\e[1m\e[32mbashunit\e[0m - (non-stable) main")" "$("$install_dir" --version)"
}
