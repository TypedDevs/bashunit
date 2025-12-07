#!/usr/bin/env bash

# Pass in any number of ANSI SGR codes.
#
# Code reference:
#   https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_(Select_Graphic_Rendition)_parameters
# Credit:
#   https://superuser.com/a/1119396
sgr() {
  local codes=${1:-0}
  shift

  for c in "$@"; do
    codes="$codes;$c"
  done

  echo $'\e'"[${codes}m"
}

_BASHUNIT_COLOR_BOLD="$(sgr 1)"
_BASHUNIT_COLOR_FAINT="$(sgr 2)"
_BASHUNIT_COLOR_BLACK="$(sgr 30)"
_BASHUNIT_COLOR_FAILED="$(sgr 31)"
_BASHUNIT_COLOR_PASSED="$(sgr 32)"
_BASHUNIT_COLOR_SKIPPED="$(sgr 33)"
_BASHUNIT_COLOR_INCOMPLETE="$(sgr 36)"
_BASHUNIT_COLOR_SNAPSHOT="$(sgr 34)"
_BASHUNIT_COLOR_RETURN_ERROR="$(sgr 41)$_BASHUNIT_COLOR_BLACK$_BASHUNIT_COLOR_BOLD"
_BASHUNIT_COLOR_RETURN_SUCCESS="$(sgr 42)$_BASHUNIT_COLOR_BLACK$_BASHUNIT_COLOR_BOLD"
_BASHUNIT_COLOR_RETURN_SKIPPED="$(sgr 43)$_BASHUNIT_COLOR_BLACK$_BASHUNIT_COLOR_BOLD"
_BASHUNIT_COLOR_RETURN_INCOMPLETE="$(sgr 46)$_BASHUNIT_COLOR_BLACK$_BASHUNIT_COLOR_BOLD"
_BASHUNIT_COLOR_RETURN_SNAPSHOT="$(sgr 44)$_BASHUNIT_COLOR_BLACK$_BASHUNIT_COLOR_BOLD"
_BASHUNIT_COLOR_DEFAULT="$(sgr 0)"
