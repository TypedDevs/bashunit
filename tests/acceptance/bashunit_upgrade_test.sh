#!/usr/bin/env bash
# bashunit: no-parallel-tests
set -uo pipefail
set +e

TMP_DIR="tmp"
TMP_BIN="$TMP_DIR/bashunit"
ACTIVE_INTERNET=false
HAS_DOWNLOADER=false
HAS_GIT=false

function set_up_before_script() {
  if bashunit::env::active_internet_connection; then
    ACTIVE_INTERNET=true
  fi

  if bashunit::dependencies::has_curl || bashunit::dependencies::has_wget; then
    HAS_DOWNLOADER=true
  fi

  if bashunit::dependencies::has_git; then
    HAS_GIT=true
  fi
}

function tear_down_after_script() {
  set -e
}

function set_up() {
  ./build.sh "$TMP_DIR" >/dev/null
  if [[ "$ACTIVE_INTERNET" == true ]] && [[ "$HAS_GIT" == true ]]; then
    LATEST_VERSION="$(bashunit::helper::get_latest_tag)"
  else
    LATEST_VERSION="${BASHUNIT_VERSION}"
  fi
}

function tear_down() {
  rm -rf "$TMP_DIR"
}

function test_do_not_upgrade_when_latest() {
  bashunit::skip "failing when having a new release" && return

  local output
  output="$($TMP_BIN upgrade)"

  assert_same "> You are already on latest version" "$output"
  assert_string_ends_with "$LATEST_VERSION" "$($TMP_BIN --version)"
}

function test_upgrade_when_a_new_version_found() {
  if [[ "$ACTIVE_INTERNET" == false ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_GIT" == false ]]; then
    bashunit::skip "git not installed" && return
  fi
  if [[ "$HAS_DOWNLOADER" == false ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi

  sed -i -e 's/declare -r BASHUNIT_VERSION="[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}"/'\
'declare -r BASHUNIT_VERSION="0.1.0"/' "$TMP_BIN"

  if [[ $_BASHUNIT_OS == "OSX" ]]; then
    rm -f "${TMP_BIN}-e"
  fi

  local output
  output="$($TMP_BIN upgrade)"

  assert_contains "> Upgrading bashunit to latest version" "$output"
  assert_contains "> bashunit upgraded successfully to latest version $LATEST_VERSION" "$output"
  assert_string_ends_with "$LATEST_VERSION" "$($TMP_BIN --version)"
}

function test_do_not_update_on_consecutive_calls() {
  bashunit::skip "after upgrade, binary uses old CLI syntax" && return

  if [[ "$ACTIVE_INTERNET" == false ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_GIT" == false ]]; then
    bashunit::skip "git not installed" && return
  fi
  if [[ "$HAS_DOWNLOADER" == false ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi

  sed -i -e 's/declare -r BASHUNIT_VERSION="[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}"/'\
'declare -r BASHUNIT_VERSION="0.1.0"/' "$TMP_BIN"

  if [[ $_BASHUNIT_OS == "OSX" ]]; then
    rm -f "${TMP_BIN}-e"
  fi

  $TMP_BIN upgrade
  $TMP_BIN --version

  local output
  output="$($TMP_BIN upgrade)"

  assert_same "> You are already on latest version" "$output"
  assert_string_ends_with "$LATEST_VERSION" "$($TMP_BIN --version)"
}
