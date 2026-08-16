#!/usr/bin/env bash

# Pass in any number of ANSI SGR codes.
#
# Code reference:
#   https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_(Select_Graphic_Rendition)_parameters
# Credit:
#   https://superuser.com/a/1119396
_BASHUNIT_SGR_OUT=""

##
# Writes the escape sequence for the given SGR codes into _BASHUNIT_SGR_OUT.
# Arguments: $@ - SGR codes (default: 0)
##
function bashunit::sgr_to_slot() {
  local codes=${1:-0}
  shift

  local c
  for c in "$@"; do
    codes="$codes;$c"
  done

  _BASHUNIT_SGR_OUT=$'\e'"[${codes}m"
}

bashunit::sgr() {
  bashunit::sgr_to_slot "$@"
  echo "$_BASHUNIT_SGR_OUT"
}

if bashunit::env::is_no_color_enabled; then
  _BASHUNIT_COLOR_BOLD=""
  _BASHUNIT_COLOR_FAINT=""
  _BASHUNIT_COLOR_BLACK=""
  _BASHUNIT_COLOR_FAILED=""
  _BASHUNIT_COLOR_PASSED=""
  _BASHUNIT_COLOR_SKIPPED=""
  _BASHUNIT_COLOR_INCOMPLETE=""
  _BASHUNIT_COLOR_SNAPSHOT=""
  _BASHUNIT_COLOR_RISKY=""
  _BASHUNIT_COLOR_RETURN_ERROR=""
  _BASHUNIT_COLOR_RETURN_SUCCESS=""
  _BASHUNIT_COLOR_RETURN_SKIPPED=""
  _BASHUNIT_COLOR_RETURN_INCOMPLETE=""
  _BASHUNIT_COLOR_RETURN_SNAPSHOT=""
  _BASHUNIT_COLOR_RETURN_RISKY=""
  _BASHUNIT_COLOR_DEFAULT=""
else
  bashunit::sgr_to_slot 1
  _BASHUNIT_COLOR_BOLD=$_BASHUNIT_SGR_OUT
  # Use SGR 90 (bright black / gray) instead of SGR 2 (faint), since
  # GitHub Actions' log renderer does not render the faint attribute.
  bashunit::sgr_to_slot 90
  _BASHUNIT_COLOR_FAINT=$_BASHUNIT_SGR_OUT
  bashunit::sgr_to_slot 30
  _BASHUNIT_COLOR_BLACK=$_BASHUNIT_SGR_OUT
  bashunit::sgr_to_slot 31
  _BASHUNIT_COLOR_FAILED=$_BASHUNIT_SGR_OUT
  bashunit::sgr_to_slot 32
  _BASHUNIT_COLOR_PASSED=$_BASHUNIT_SGR_OUT
  bashunit::sgr_to_slot 33
  _BASHUNIT_COLOR_SKIPPED=$_BASHUNIT_SGR_OUT
  bashunit::sgr_to_slot 36
  _BASHUNIT_COLOR_INCOMPLETE=$_BASHUNIT_SGR_OUT
  bashunit::sgr_to_slot 34
  _BASHUNIT_COLOR_SNAPSHOT=$_BASHUNIT_SGR_OUT
  bashunit::sgr_to_slot 35
  _BASHUNIT_COLOR_RISKY=$_BASHUNIT_SGR_OUT

  # The banner colours all end in black + bold, so they are the background code
  # concatenated with two entries set just above.
  _bashunit_banner_suffix="$_BASHUNIT_COLOR_BLACK$_BASHUNIT_COLOR_BOLD"
  bashunit::sgr_to_slot 41
  _BASHUNIT_COLOR_RETURN_ERROR="$_BASHUNIT_SGR_OUT$_bashunit_banner_suffix"
  bashunit::sgr_to_slot 42
  _BASHUNIT_COLOR_RETURN_SUCCESS="$_BASHUNIT_SGR_OUT$_bashunit_banner_suffix"
  bashunit::sgr_to_slot 43
  _BASHUNIT_COLOR_RETURN_SKIPPED="$_BASHUNIT_SGR_OUT$_bashunit_banner_suffix"
  bashunit::sgr_to_slot 46
  _BASHUNIT_COLOR_RETURN_INCOMPLETE="$_BASHUNIT_SGR_OUT$_bashunit_banner_suffix"
  bashunit::sgr_to_slot 44
  _BASHUNIT_COLOR_RETURN_SNAPSHOT="$_BASHUNIT_SGR_OUT$_bashunit_banner_suffix"
  bashunit::sgr_to_slot 45
  _BASHUNIT_COLOR_RETURN_RISKY="$_BASHUNIT_SGR_OUT$_bashunit_banner_suffix"
  unset _bashunit_banner_suffix

  bashunit::sgr_to_slot 0
  _BASHUNIT_COLOR_DEFAULT=$_BASHUNIT_SGR_OUT
fi
