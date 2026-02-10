#!/usr/bin/env bash

# Pass in any number of ANSI SGR codes.
#
# Code reference:
#   https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_(Select_Graphic_Rendition)_parameters
# Credit:
#   https://superuser.com/a/1119396
bashunit::sgr() {
  local codes=${1:-0}
  shift

  local c=""
  for c in "$@"; do
    codes="$codes;$c"
  done

  echo $'\e'"[${codes}m"
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
  _BASHUNIT_COLOR_RETURN_ERROR=""
  _BASHUNIT_COLOR_RETURN_SUCCESS=""
  _BASHUNIT_COLOR_RETURN_SKIPPED=""
  _BASHUNIT_COLOR_RETURN_INCOMPLETE=""
  _BASHUNIT_COLOR_RETURN_SNAPSHOT=""
  _BASHUNIT_COLOR_DEFAULT=""
else
  _BASHUNIT_COLOR_BOLD="$(bashunit::sgr 1)"
  _BASHUNIT_COLOR_FAINT="$(bashunit::sgr 2)"
  _BASHUNIT_COLOR_BLACK="$(bashunit::sgr 30)"
  _BASHUNIT_COLOR_FAILED="$(bashunit::sgr 31)"
  _BASHUNIT_COLOR_PASSED="$(bashunit::sgr 32)"
  _BASHUNIT_COLOR_SKIPPED="$(bashunit::sgr 33)"
  _BASHUNIT_COLOR_INCOMPLETE="$(bashunit::sgr 36)"
  _BASHUNIT_COLOR_SNAPSHOT="$(bashunit::sgr 34)"
  _BASHUNIT_COLOR_RETURN_ERROR="$(bashunit::sgr 41)$_BASHUNIT_COLOR_BLACK$_BASHUNIT_COLOR_BOLD"
  _BASHUNIT_COLOR_RETURN_SUCCESS="$(bashunit::sgr 42)$_BASHUNIT_COLOR_BLACK$_BASHUNIT_COLOR_BOLD"
  _BASHUNIT_COLOR_RETURN_SKIPPED="$(bashunit::sgr 43)$_BASHUNIT_COLOR_BLACK$_BASHUNIT_COLOR_BOLD"
  _BASHUNIT_COLOR_RETURN_INCOMPLETE="$(bashunit::sgr 46)$_BASHUNIT_COLOR_BLACK$_BASHUNIT_COLOR_BOLD"
  _BASHUNIT_COLOR_RETURN_SNAPSHOT="$(bashunit::sgr 44)$_BASHUNIT_COLOR_BLACK$_BASHUNIT_COLOR_BOLD"
  _BASHUNIT_COLOR_DEFAULT="$(bashunit::sgr 0)"
fi
