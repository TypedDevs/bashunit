#!/usr/bin/env bash

# shellcheck disable=SC2034
_BASHUNIT_OS="Unknown"
_BASHUNIT_DISTRO="Unknown"

function bashunit::check_os::init() {
  if bashunit::check_os::is_linux; then
    _BASHUNIT_OS="Linux"
    if bashunit::check_os::is_ubuntu; then
      _BASHUNIT_DISTRO="Ubuntu"
    elif bashunit::check_os::is_alpine; then
      _BASHUNIT_DISTRO="Alpine"
    elif bashunit::check_os::is_nixos; then
      _BASHUNIT_DISTRO="NixOS"
    else
      _BASHUNIT_DISTRO="Other"
    fi
  elif bashunit::check_os::is_macos; then
    _BASHUNIT_OS="OSX"
  elif bashunit::check_os::is_windows; then
    _BASHUNIT_OS="Windows"
  else
    _BASHUNIT_OS="Unknown"
    _BASHUNIT_DISTRO="Unknown"
  fi
}

function bashunit::check_os::is_ubuntu() {
  command -v apt >/dev/null
}

function bashunit::check_os::is_alpine() {
  command -v apk >/dev/null
}

function bashunit::check_os::is_nixos() {
  [[ -f /etc/NIXOS ]] && return 0
  grep -q '^ID=nixos' /etc/os-release 2>/dev/null
}

function bashunit::check_os::is_linux() {
  [[ "$(uname)" == "Linux" ]]
}

function bashunit::check_os::is_macos() {
  [[ "$(uname)" == "Darwin" ]]
}

function bashunit::check_os::is_windows() {
  case "$(uname)" in
  *MINGW* | *MSYS* | *CYGWIN*)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

function bashunit::check_os::is_busybox() {

  case "$_BASHUNIT_DISTRO" in

  "Alpine")
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

bashunit::check_os::init

export _BASHUNIT_OS
export _BASHUNIT_DISTRO
export -f bashunit::check_os::is_alpine
export -f bashunit::check_os::is_busybox
export -f bashunit::check_os::is_ubuntu
export -f bashunit::check_os::is_nixos
