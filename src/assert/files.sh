#!/usr/bin/env bash

function assert_file_exists() {
  bashunit::assert::should_skip && return 0

  local expected="$1"

  if [ ! -f "$expected" ]; then
    bashunit::assert::fail_with "${3:-}" "${expected}" "to exist but" "do not exist"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_file_not_exists() {
  bashunit::assert::should_skip && return 0

  local expected="$1"

  if [ -f "$expected" ]; then
    bashunit::assert::fail_with "${3:-}" "${expected}" "to not exist but" "the file exists"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_file() {
  bashunit::assert::should_skip && return 0

  local expected="$1"

  if [ ! -f "$expected" ]; then
    bashunit::assert::fail_with "${3:-}" "${expected}" "to be a file" "but is not a file"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_file_empty() {
  bashunit::assert::should_skip && return 0

  local expected="$1"

  if [ -s "$expected" ]; then
    bashunit::assert::fail_with "${3:-}" "${expected}" "to be empty" "but is not empty"
    return
  fi

  bashunit::state::add_assertions_passed
}

##
# The permission and emptiness checks for files, mirroring the directory
# family in folders.sh.
#
# They distinguish three failures where the folder assertions collapse two: a
# path that does not exist, a path that exists but is not a file, and a file
# whose mode is wrong. "not readable" for a path that was never created sends
# the reader to check permissions on something that is not there.
#
# Arguments: $1 - path, $2 - optional label override
##
function bashunit::assert::file_state() {
  local path=$1
  if [ ! -e "$path" ]; then
    _BASHUNIT_ASSERT_FILE_STATE_OUT="missing"
  elif [ ! -f "$path" ]; then
    _BASHUNIT_ASSERT_FILE_STATE_OUT="not-a-file"
  else
    _BASHUNIT_ASSERT_FILE_STATE_OUT="file"
  fi
}
_BASHUNIT_ASSERT_FILE_STATE_OUT=""

function assert_is_file_readable() {
  bashunit::assert::should_skip && return 0

  if [ $# -lt 1 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 1 "path" "$#"
    return 2
  fi

  local expected="$1"
  bashunit::assert::file_state "$expected"
  case "$_BASHUNIT_ASSERT_FILE_STATE_OUT" in
  missing)
    bashunit::assert::fail_with "${2:-}" "${expected}" "to be readable" "but does not exist"
    return
    ;;
  not-a-file)
    bashunit::assert::fail_with "${2:-}" "${expected}" "to be readable" "but is not a file"
    return
    ;;
  esac

  if [ ! -r "$expected" ]; then
    bashunit::assert::fail_with "${2:-}" "${expected}" "to be readable" "but is not readable"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_file_not_readable() {
  bashunit::assert::should_skip && return 0

  if [ $# -lt 1 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 1 "path" "$#"
    return 2
  fi

  local expected="$1"
  bashunit::assert::file_state "$expected"
  case "$_BASHUNIT_ASSERT_FILE_STATE_OUT" in
  missing)
    bashunit::assert::fail_with "${2:-}" "${expected}" "to not be readable" "but does not exist"
    return
    ;;
  not-a-file)
    bashunit::assert::fail_with "${2:-}" "${expected}" "to not be readable" "but is not a file"
    return
    ;;
  esac

  if [ -r "$expected" ]; then
    bashunit::assert::fail_with "${2:-}" "${expected}" "to not be readable" "but is readable"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_file_writable() {
  bashunit::assert::should_skip && return 0

  if [ $# -lt 1 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 1 "path" "$#"
    return 2
  fi

  local expected="$1"
  bashunit::assert::file_state "$expected"
  case "$_BASHUNIT_ASSERT_FILE_STATE_OUT" in
  missing)
    bashunit::assert::fail_with "${2:-}" "${expected}" "to be writable" "but does not exist"
    return
    ;;
  not-a-file)
    bashunit::assert::fail_with "${2:-}" "${expected}" "to be writable" "but is not a file"
    return
    ;;
  esac

  if [ ! -w "$expected" ]; then
    bashunit::assert::fail_with "${2:-}" "${expected}" "to be writable" "but is not writable"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_file_not_writable() {
  bashunit::assert::should_skip && return 0

  if [ $# -lt 1 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 1 "path" "$#"
    return 2
  fi

  local expected="$1"
  bashunit::assert::file_state "$expected"
  case "$_BASHUNIT_ASSERT_FILE_STATE_OUT" in
  missing)
    bashunit::assert::fail_with "${2:-}" "${expected}" "to not be writable" "but does not exist"
    return
    ;;
  not-a-file)
    bashunit::assert::fail_with "${2:-}" "${expected}" "to not be writable" "but is not a file"
    return
    ;;
  esac

  if [ -w "$expected" ]; then
    bashunit::assert::fail_with "${2:-}" "${expected}" "to not be writable" "but is writable"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_file_executable() {
  bashunit::assert::should_skip && return 0

  if [ $# -lt 1 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 1 "path" "$#"
    return 2
  fi

  local expected="$1"
  bashunit::assert::file_state "$expected"
  case "$_BASHUNIT_ASSERT_FILE_STATE_OUT" in
  missing)
    bashunit::assert::fail_with "${2:-}" "${expected}" "to be executable" "but does not exist"
    return
    ;;
  not-a-file)
    bashunit::assert::fail_with "${2:-}" "${expected}" "to be executable" "but is not a file"
    return
    ;;
  esac

  if [ ! -x "$expected" ]; then
    bashunit::assert::fail_with "${2:-}" "${expected}" "to be executable" "but is not executable"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_file_not_executable() {
  bashunit::assert::should_skip && return 0

  if [ $# -lt 1 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 1 "path" "$#"
    return 2
  fi

  local expected="$1"
  bashunit::assert::file_state "$expected"
  case "$_BASHUNIT_ASSERT_FILE_STATE_OUT" in
  missing)
    bashunit::assert::fail_with "${2:-}" "${expected}" "to not be executable" "but does not exist"
    return
    ;;
  not-a-file)
    bashunit::assert::fail_with "${2:-}" "${expected}" "to not be executable" "but is not a file"
    return
    ;;
  esac

  if [ -x "$expected" ]; then
    bashunit::assert::fail_with "${2:-}" "${expected}" "to not be executable" "but is executable"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_file_not_empty() {
  bashunit::assert::should_skip && return 0

  if [ $# -lt 1 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 1 "path" "$#"
    return 2
  fi

  local expected="$1"
  bashunit::assert::file_state "$expected"
  case "$_BASHUNIT_ASSERT_FILE_STATE_OUT" in
  missing)
    bashunit::assert::fail_with "${2:-}" "${expected}" "to not be empty" "but does not exist"
    return
    ;;
  not-a-file)
    bashunit::assert::fail_with "${2:-}" "${expected}" "to not be empty" "but is not a file"
    return
    ;;
  esac

  if [ ! -s "$expected" ]; then
    bashunit::assert::fail_with "${2:-}" "${expected}" "to not be empty" "but is empty"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_files_equals() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"

  if [ "$(diff -u "$expected" "$actual")" != '' ]; then
    bashunit::assert::fail_with "" "${expected}" "Compared" "${actual}" \
      "Diff" "$(diff -u "$expected" "$actual" | sed '1,2d')"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_files_not_equals() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"

  if [ "$(diff -u "$expected" "$actual")" = '' ]; then
    bashunit::assert::fail_with "" "${expected}" "Compared" "${actual}" \
      "Diff" "Files are equals"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_file_contains() {
  bashunit::assert::should_skip && return 0

  local file="$1"
  local string="$2"

  if ! grep -F -q "$string" "$file"; then
    bashunit::assert::fail_with "" "${file}" "to contain" "${string}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_file_not_contains() {
  bashunit::assert::should_skip && return 0

  local file="$1"
  local string="$2"

  if grep -q "$string" "$file"; then
    bashunit::assert::fail_with "" "${file}" "to not contain" "${string}"
    return
  fi

  bashunit::state::add_assertions_passed
}

##
# Normalizes an octal file mode to its decimal value, dropping leading zeros
# (so "0755" and "755" compare equal). Echoes nothing on invalid octal input.
# Arguments: $1 - octal mode string
##
function bashunit::assert::_octal_to_decimal() {
  local mode="$1"
  case "$mode" in
  '' | *[!0-7]*) return 1 ;;
  esac
  printf '%d' "$((8#$mode))"
}

##
# Asserts a file has the expected octal permission mode (e.g. "644", "0755").
# Arguments: $1 - expected octal mode, $2 - file path
##
function assert_file_permissions() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local file="$2"

  if [ ! -e "$file" ]; then
    bashunit::assert::fail_with "" "${file}" \
      "to have permissions ${expected}" "but the file does not exist"
    return
  fi

  local actual
  actual="$(stat -c '%a' "$file" 2>/dev/null || stat -f '%Lp' "$file" 2>/dev/null)"

  local expected_dec actual_dec
  expected_dec="$(bashunit::assert::_octal_to_decimal "$expected")"
  actual_dec="$(bashunit::assert::_octal_to_decimal "$actual")"

  if [ "$expected_dec" != "$actual_dec" ]; then
    bashunit::assert::fail_with "" "${file}" \
      "to have permissions ${expected}" "but got ${actual}"
    return
  fi

  bashunit::state::add_assertions_passed
}

##
# Whether $1 is a symbolic link, regardless of whether its target resolves.
#
# Every other filesystem assertion here follows the link: -f and -e report on
# the target, so a link and the file it points at are indistinguishable, and a
# dangling link reads as "does not exist" -- the same answer as a path that was
# never created. This is the one that can tell them apart.
#
# Arguments: $1 - path, $2 - unused, $3 - optional label override
##
function assert_is_symlink() {
  bashunit::assert::should_skip && return 0

  local expected="$1"

  if [ ! -L "$expected" ]; then
    bashunit::assert::fail_with "${3:-}" "${expected}" "to be a symlink" "but is not a symlink"
    return
  fi

  bashunit::state::add_assertions_passed
}

##
# Whether $1 exists and is not a symbolic link.
# Arguments: $1 - path, $2 - unused, $3 - optional label override
##
function assert_is_not_symlink() {
  bashunit::assert::should_skip && return 0

  local expected="$1"

  if [ -L "$expected" ]; then
    bashunit::assert::fail_with "${3:-}" "${expected}" "not to be a symlink" "but is a symlink"
    return
  fi

  bashunit::state::add_assertions_passed
}

##
# Whether $2 is a symlink pointing at $1.
#
# Compares the target as written, via `readlink`, not the fully resolved path.
# Two reasons: it is what the test author wrote in the first place, so a failure
# names something they recognise; and `readlink -f` is GNU-only, so resolving
# would need a second implementation for BSD/macOS. A relative link therefore
# compares as the relative string it is.
#
# Arguments: $1 - expected target, $2 - path, $3 - optional label override
##
function assert_symlink_to() {
  bashunit::assert::should_skip && return 0

  if [ $# -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected_target, path" "$#"
    return 2
  fi

  local expected="$1"
  local path="$2"

  if [ ! -L "$path" ]; then
    bashunit::assert::fail_with "${3:-}" "${path}" "to be a symlink" "but is not a symlink"
    return
  fi

  local actual
  actual=$(readlink "$path")

  if [ "$actual" != "$expected" ]; then
    bashunit::assert::fail_with "${3:-}" "${expected}" \
      "to be the target of ${path}, but got " "${actual}"
    return
  fi

  bashunit::state::add_assertions_passed
}
