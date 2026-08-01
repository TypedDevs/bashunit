#!/usr/bin/env bash

# Generic shell-function utilities.

#
# @param $1 string Eg: "do_something"
#
function bashunit::helper::execute_function_if_exists() {
  local fn_name="$1"

  if declare -F "$fn_name" >/dev/null 2>&1; then
    "$fn_name"
    return $?
  fi

  return 0
}


#
# @param $1 string Eg: "do_something"
#
function bashunit::helper::unset_if_exists() {
  unset "$1" 2>/dev/null
}

