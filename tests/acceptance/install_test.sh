#!/usr/bin/env bash
# bashunit: no-parallel-tests
# shellcheck disable=SC2317
set -uo pipefail
set +e

ACTIVE_INTERNET=0
HAS_DOWNLOADER=0
HAS_GIT=0

function set_up_before_script() {
  if bashunit::env::active_internet_connection; then
    ACTIVE_INTERNET=0
  else
    ACTIVE_INTERNET=1
  fi
  if bashunit::dependencies::has_curl || bashunit::dependencies::has_wget; then
    HAS_DOWNLOADER=1
  fi
  if bashunit::dependencies::has_git; then
    HAS_GIT=1
  fi
}

function tear_down_after_script() {
  set -e
}

function set_up() {
  rm -f ./lib/bashunit
  rm -f ./deps/bashunit
}

function tear_down() {
  rm -f ./lib/bashunit
  rm -f ./deps/bashunit
}

function test_install_downloads_the_latest_version() {
  if [[ "$ACTIVE_INTERNET" -eq 1 ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_DOWNLOADER" -eq 0 ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi

  local installed_bashunit="./lib/bashunit"
  local output

  output="$(./install.sh)"

  assert_string_starts_with "$(printf "> Downloading the latest version: '")" "$output"
  assert_string_ends_with "$(printf "\n> bashunit has been installed in the 'lib' folder")" "$output"
  assert_file_exists "$installed_bashunit"

  assert_string_starts_with "$(printf "\e[1m\e[32mbashunit\e[0m - ")" \
    "$("$installed_bashunit" --version)"
}

function test_install_downloads_in_given_folder() {
  if [[ "$ACTIVE_INTERNET" -eq 1 ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_DOWNLOADER" -eq 0 ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi

  local installed_bashunit="./deps/bashunit"
  local output

  output="$(./install.sh deps)"

  assert_string_starts_with "$(printf "> Downloading the latest version: '")" "$output"
  assert_string_ends_with "$(printf "\n> bashunit has been installed in the 'deps' folder")" "$output"
  assert_file_exists "$installed_bashunit"

  assert_string_starts_with "$(printf "\e[1m\e[32mbashunit\e[0m - ")" \
    "$("$installed_bashunit" --version)"
}

function test_install_downloads_the_given_version() {
  if [[ "$ACTIVE_INTERNET" -eq 1 ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_DOWNLOADER" -eq 0 ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi

  local installed_bashunit="./lib/bashunit"
  local output

  output="$(./install.sh lib 0.9.0)"

  local expected
  expected="> Downloading a concrete version: '0.9.0'
> bashunit has been installed in the 'lib' folder"

  assert_same "$expected" "$output"

  assert_file_exists "$installed_bashunit"

  assert_same "$(printf "\e[1m\e[32mbashunit\e[0m - 0.9.0")" \
    "$("$installed_bashunit" --version)"
}

function test_install_downloads_the_given_version_without_dir() {
  if [[ "$ACTIVE_INTERNET" -eq 1 ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_DOWNLOADER" -eq 0 ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi

  local installed_bashunit="./lib/bashunit"
  local output
  output="$(./install.sh 0.19.0)"

  assert_same \
    "$(
      printf "%s\n" \
        "> Downloading a concrete version: '0.19.0'" \
        "> bashunit has been installed in the 'lib' folder"
    )" \
    "$output"

  assert_file_exists "$installed_bashunit"

  assert_same \
    "$(printf "\e[1m\e[32mbashunit\e[0m - 0.19.0")" \
    "$("$installed_bashunit" --version)"
}

function test_install_downloads_the_non_stable_beta_version() {
  # Skip on Bash 3.0 - mocks don't work for external scripts
  if [[ "${BASH_VERSINFO[0]}" -eq 3 ]] && [[ "${BASH_VERSINFO[1]}" -lt 1 ]]; then
    bashunit::skip "Mocks don't work for external scripts in Bash 3.0"
    return
  fi
  if [[ "$ACTIVE_INTERNET" -eq 1 ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_GIT" -eq 0 ]]; then
    bashunit::skip "git not installed" && return
  fi
  if [[ "$HAS_DOWNLOADER" -eq 0 ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi

  bashunit::mock date <<<"2023-11-13"
  bashunit::mock tput <<<""
  local installed_bashunit="./deps/bashunit"
  local output

  output="$(./install.sh deps beta)"

  local expected
  expected="> Downloading non-stable version: 'beta'
> bashunit has been installed in the 'deps' folder"

  assert_contains "$expected" "$output"

  assert_file_exists "$installed_bashunit"

  assert_matches \
    "$(printf "\(non-stable\) beta after ([0-9]+\.[0-9]+\.[0-9]+) \[2023-11-13\] 🐍 \#[a-fA-F0-9]{7}")" \
    "$("$installed_bashunit" --version)"

  assert_directory_not_exists "./deps/temp_bashunit"

  file_count_of_deps_directory=$(find ./deps -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')
  assert_same "$file_count_of_deps_directory" "1"
  assert_same "$(find ./deps -name 'bashunit')" "./deps/bashunit"
}
