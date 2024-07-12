#!/bin/bash

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

_COLOR_BOLD="$(sgr 1)"
_COLOR_FAINT="$(sgr 2)"
_COLOR_BLACK="$(sgr 30)"
_COLOR_FAILED="$(sgr 31)"
_COLOR_PASSED="$(sgr 32)"
_COLOR_SKIPPED="$(sgr 33)"
_COLOR_INCOMPLETE="$(sgr 36)"
_COLOR_SNAPSHOT="$(sgr 34)"
_COLOR_RETURN_ERROR="$(sgr 41)$_COLOR_BLACK$_COLOR_BOLD"
_COLOR_RETURN_SUCCESS="$(sgr 42)$_COLOR_BLACK$_COLOR_BOLD"
_COLOR_RETURN_SKIPPED="$(sgr 43)$_COLOR_BLACK$_COLOR_BOLD"
_COLOR_RETURN_INCOMPLETE="$(sgr 46)$_COLOR_BLACK$_COLOR_BOLD"
_COLOR_RETURN_SNAPSHOT="$(sgr 44)$_COLOR_BLACK$_COLOR_BOLD"
_COLOR_DEFAULT="$(sgr 0)"
