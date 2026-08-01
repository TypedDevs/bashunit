#!/usr/bin/env bash

# shellcheck disable=SC2034
_BASHUNIT_OS="Unknown"
_BASHUNIT_DISTRO="Unknown"

function bashunit::check_os::init() {
  _BASHUNIT_UNAME="$(uname)"
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
  command -v apt >/dev/null 2>&1
}

function bashunit::check_os::is_alpine() {
  command -v apk >/dev/null 2>&1
}

function bashunit::check_os::is_nixos() {
  [ -f /etc/NIXOS ] && return 0
  grep -q '^ID=nixos' /etc/os-release 2>/dev/null
}

function bashunit::check_os::is_linux() {
  [ "$_BASHUNIT_UNAME" = "Linux" ]
}

function bashunit::check_os::is_macos() {
  [ "$_BASHUNIT_UNAME" = "Darwin" ]
}

function bashunit::check_os::is_windows() {
  case "$_BASHUNIT_UNAME" in
  *MINGW* | *MSYS* | *CYGWIN*)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

##
# Detects the number of online CPU cores, portably across Linux/macOS/BSD.
# Tries nproc, then sysctl, then getconf; falls back to 4 when none report a
# usable positive integer. Takes the first whitespace-delimited token so a
# stray flag or trailing text never poisons the arithmetic guard.
# Returns: prints the core count (>= 1) to stdout.
##
function bashunit::check_os::nproc() {
  local cores=""
  cores="$(nproc 2>/dev/null)" || cores=""
  if [ -z "$cores" ]; then
    cores="$(sysctl -n hw.ncpu 2>/dev/null)" || cores=""
  fi
  if [ -z "$cores" ]; then
    cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null)" || cores=""
  fi
  cores="${cores%% *}"
  case "$cores" in
  '' | *[!0-9]*) cores=4 ;;
  esac
  [ "$cores" -lt 1 ] && cores=4
  echo "$cores"
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
export -f bashunit::check_os::nproc
export -f bashunit::check_os::is_alpine
export -f bashunit::check_os::is_busybox
export -f bashunit::check_os::is_ubuntu
export -f bashunit::check_os::is_nixos
