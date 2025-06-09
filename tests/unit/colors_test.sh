#!/usr/bin/env bash

function set_up() {
  ORIG_TERM="${TERM-}"
  ORIG_NO_COLOR="${NO_COLOR-}"
}

function tear_down() {
  if [[ -n "${ORIG_TERM+x}" ]]; then
    export TERM="$ORIG_TERM"
  else
    unset TERM
  fi

  if [[ -n "${ORIG_NO_COLOR+x}" ]]; then
    export NO_COLOR="$ORIG_NO_COLOR"
  else
    unset NO_COLOR
  fi
}

function test_sgr_returns_color_code_when_term_set() {
  export TERM="xterm"
  assert_same "$(printf '\e[31m')" "$(sgr 31)"
}

function test_sgr_returns_empty_string_when_term_dumb() {
  export TERM="dumb"
  assert_same "" "$(sgr 31)"
}

function test_sgr_returns_color_code_when_term_unset() {
  export TERM=""
  assert_same "$(printf '\e[31m')" "$(sgr 31)"
}

function test_sgr_returns_empty_string_when_no_color_set() {
  export TERM="xterm"
  export NO_COLOR=1
  assert_same "" "$(sgr 31)"
}
