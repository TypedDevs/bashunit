#!/bin/bash

# shellcheck disable=SC2034
_OS="Unknown"
_DISTRO="Unknown"

function check_os::init() {
  if check_os::is_linux; then
    _OS="Linux"
    if check_os::is_ubuntu; then
      _DISTRO="Ubuntu"
    elif check_os::is_alpine; then
      _DISTRO="Alpine"
    else
      _DISTRO="Other"
    fi
  elif check_os::is_macos; then
    _OS="OSX"
  elif check_os::is_windows; then
    _OS="Windows"
  else
    _OS="Unknown"
    _DISTRO="Unknown"
  fi
}

function check_os::is_ubuntu() {
  command -v apt > /dev/null
}

function check_os::is_alpine() {
  command -v apk > /dev/null
}

function check_os::is_linux() {
  [[ "$(uname)" == "Linux" ]]
}

function check_os::is_macos() {
  [[ "$(uname)" == "Darwin" ]]
}

function check_os::is_windows() {
  [[ "$(uname)" == *"MINGW"* ]]
}

function check_os::is_busybox() {

  case "$_DISTRO" in

    "Alpine")
        return 0
        ;;
    *)
      return 1
      ;;
  esac
}

check_os::init

export _OS
export _DISTRO
export -f check_os::is_alpine
export -f check_os::is_busybox
export -f check_os::is_ubuntu
