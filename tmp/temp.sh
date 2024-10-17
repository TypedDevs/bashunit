#!/bin/bash
# check_os.sh

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

# str.sh

function str::rpad() {
  local left_text="$1"
  local right_word="$2"
  local width_padding="${3:-$TERMINAL_WIDTH}"
  # Subtract 1 more to account for the extra space
  local padding=$((width_padding - ${#right_word} - 1))

  # Remove ANSI escape sequences (non-visible characters) for length calculation
  # shellcheck disable=SC2155
  local clean_left_text=$(echo -e "$left_text" | sed 's/\x1b\[[0-9;]*m//g')

  local is_truncated=false
  # If the visible left text exceeds the padding, truncate it and add "..."
  if [[ ${#clean_left_text} -gt $padding ]]; then
    local truncation_length=$((padding - 3))  # Subtract 3 for "..."
    clean_left_text="${clean_left_text:0:$truncation_length}"
    is_truncated=true
  fi

  # Rebuild the text with ANSI codes intact, preserving the truncation
  local result_left_text=""
  local i=0
  local j=0
  while [[ $i -lt ${#clean_left_text} && $j -lt ${#left_text} ]]; do
    local char="${clean_left_text:$i:1}"
    local original_char="${left_text:$j:1}"

    # If the current character is part of an ANSI sequence, skip it and copy it
    if [[ "$original_char" == $'\x1b' ]]; then
      while [[ "${left_text:$j:1}" != "m" && $j -lt ${#left_text} ]]; do
        result_left_text+="${left_text:$j:1}"
        ((j++))
      done
      result_left_text+="${left_text:$j:1}"  # Append the final 'm'
      ((j++))
    elif [[ "$char" == "$original_char" ]]; then
      # Match the actual character
      result_left_text+="$char"
      ((i++))
      ((j++))
    else
      ((j++))
    fi
  done

  local remaining_space
  if $is_truncated ; then
    result_left_text+="..."
    # 1: due to a blank space
    # 3: due to the appended ...
    remaining_space=$((width_padding - ${#clean_left_text} - ${#right_word} - 1 - 3))
  else
    # Copy any remaining characters after the truncation point
    result_left_text+="${left_text:$j}"
    remaining_space=$((width_padding - ${#clean_left_text} - ${#right_word} - 1))
  fi

  # Ensure the right word is placed exactly at the far right of the screen
  # filling the remaining space with padding
  if [[ $remaining_space -lt 0 ]]; then
    remaining_space=0
  fi

  printf "%s%${remaining_space}s %s\n" "$result_left_text" "" "$right_word"
}

# globals.sh
set -euo pipefail

# This file provides a set of global functions to developers.

function current_dir() {
  dirname "${BASH_SOURCE[1]}"
}

function current_filename() {
  basename "${BASH_SOURCE[1]}"
}

function caller_filename() {
  dirname "${BASH_SOURCE[2]}"
}

function caller_line() {
  echo "${BASH_LINENO[1]}"
}

function current_timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

function is_command_available() {
  command -v "$1" >/dev/null 2>&1
}

function random_str() {
  local length=${1:-6}
  local chars='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  local str=''
  for (( i=0; i<length; i++ )); do
    str+="${chars:RANDOM%${#chars}:1}"
  done
  echo "$str"
}

function temp_file() {
  local prefix=${1:-bashunit}
  mkdir -p /tmp/bashunit/tmp && chmod -R 777 /tmp/bashunit/tmp
  mktemp /tmp/bashunit/tmp/"$prefix".XXXXXXX
}

function temp_dir() {
  local prefix=${1:-bashunit}
  mkdir -p /tmp/bashunit/tmp && chmod -R 777 /tmp/bashunit/tmp
  mktemp -d /tmp/bashunit/tmp/"$prefix".XXXXXXX
}

function cleanup_temp_files() {
  rm -rf /tmp/bashunit/tmp/*
}

# shellcheck disable=SC2145
function log() {
  if ! env::is_dev_mode_enabled; then
    return
  fi

  local level="$1"
  shift

  case "$level" in
    info|INFO)          level="INFO" ;;
    debug|DEBUG)        level="DEBUG" ;;
    warning|WARNING)    level="WARNING" ;;
    critical|CRITICAL)  level="CRITICAL" ;;
    error|ERROR)        level="ERROR" ;;
    *) set -- "$level $@"; level="INFO" ;;
  esac

  echo "$(current_timestamp) [$level]: $@" >> "$BASHUNIT_DEV_LOG"
}

# dependencies.sh
set -euo pipefail

function dependencies::has_perl() {
  command -v perl >/dev/null 2>&1
}

function dependencies::has_powershell() {
  command -v powershell > /dev/null 2>&1
}

function dependencies::has_adjtimex() {
  command -v adjtimex >/dev/null 2>&1
}

function dependencies::has_bc() {
  command -v bc >/dev/null 2>&1
}

function dependencies::has_awk() {
  command -v awk >/dev/null 2>&1
}

function dependencies::has_git() {
  command -v git >/dev/null 2>&1
}

function dependencies::has_curl() {
  command -v curl >/dev/null 2>&1
}

function dependencies::has_wget() {
  command -v wget >/dev/null 2>&1
}

# io.sh

function io::download_to() {
  local url="$1"
  local output="$2"
  if dependencies::has_curl; then
    curl -L -J -o "$output" "$url" 2>/dev/null
  elif dependencies::has_wget; then
    wget -q -O "$output" "$url" 2>/dev/null
  else
    return 1
  fi
}

# math.sh
