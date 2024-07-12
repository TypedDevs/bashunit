#!/bin/bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="./tests/acceptance/fixtures/.env.default"
}

function tear_down() {
  rm -f ./lib/bashunit
  rm -f ./deps/bashunit
}

function test_install_downloads_the_latest_version() {
  local installed_bashunit="./lib/bashunit"
  local output

  output="$(./install.sh)"

  assert_string_starts_with "$(printf "> Downloading the latest version: '")" "$output"
  assert_string_ends_with "$(printf "\n> bashunit has been installed in the 'lib' folder")" "$output"
  assert_file_exists "$installed_bashunit"
  assert_string_starts_with\
    "$(printf "\e[1m\e[32mbashunit\e[0m - ")"\
    "$("$installed_bashunit" --env "$TEST_ENV_FILE" --version)"
}

function test_install_downloads_in_given_folder() {
  local installed_bashunit="./deps/bashunit"
  local output

  output="$(./install.sh deps)"

  assert_string_starts_with "$(printf "> Downloading the latest version: '")" "$output"
  assert_string_ends_with "$(printf "\n> bashunit has been installed in the 'deps' folder")" "$output"
  assert_file_exists "$installed_bashunit"
  assert_string_starts_with\
    "$(printf "\e[1m\e[32mbashunit\e[0m - ")"\
    "$("$installed_bashunit" --env "$TEST_ENV_FILE" --version)"
}

function test_install_downloads_the_given_version() {
  local installed_bashunit="./lib/bashunit"
  local output

  output="$(./install.sh lib 0.9.0)"

  assert_equals\
    "$(printf "> Downloading a concrete version: '0.9.0'\n> bashunit has been installed in the 'lib' folder")"\
    "$output"
  assert_file_exists "$installed_bashunit"

  assert_equals\
    "$(printf "\e[1m\e[32mbashunit\e[0m - 0.9.0")"\
    "$("$installed_bashunit" --env "$TEST_ENV_FILE" --version)"
}

function test_install_downloads_the_non_stable_beta_version() {
  mock date echo "2023-11-13"
  local installed_bashunit="./deps/bashunit"
  local output

  output="$(./install.sh deps beta)"

  assert_contains\
    "$(printf "> Downloading non-stable version: 'beta'\n> bashunit has been installed in the 'deps' folder")"\
    "$output"
  assert_file_exists "$installed_bashunit"
  assert_matches\
    "$(printf "\(non-stable\) beta after ([0-9]+\.[0-9]+\.[0-9]+) \[2023-11-13\] 🐍 \#[a-fA-F0-9]{8}")"\
    "$("$installed_bashunit" --env "$TEST_ENV_FILE" --version)"
  assert_directory_not_exists "./deps/temp_bashunit"
  file_count_of_deps_directory=$(find ./deps -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')
  assert_equals "$file_count_of_deps_directory" "1"
  assert_equals "$(find ./deps -name 'bashunit')" "./deps/bashunit"
}
