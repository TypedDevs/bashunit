#!/usr/bin/env bash

# base64 payload encoding and run-unique id generation.

function bashunit::helper::encode_base64() {
  local value="$1"

  # Handle empty string specially - base64 of "" is "", which gets lost in line parsing
  if [ -z "$value" ]; then
    printf '%s' "$_BASHUNIT_BASE64_EMPTY_SENTINEL"
    return
  fi

  if [ "$_BASHUNIT_BASE64_WRAP_FLAG" = true ]; then
    printf '%s' "$value" | base64 -w 0
  elif command -v base64 >/dev/null; then
    printf '%s' "$value" | base64 | tr -d '\n'
  else
    printf '%s' "$value" | openssl enc -base64 -A
  fi
}


function bashunit::helper::decode_base64() {
  local value="$1"

  # Empty input decodes to empty; short-circuit to skip the base64 fork (#762).
  if [ -z "$value" ] || [ "$value" = "$_BASHUNIT_BASE64_EMPTY_SENTINEL" ]; then
    printf ''
    return
  fi

  if command -v base64 >/dev/null; then
    printf '%s' "$value" | base64 -d
  else
    printf '%s' "$value" | openssl enc -d -base64
  fi
}


# Writes a sanitized, process-unique id into _BASHUNIT_HELPER_ID_OUT.
# Return-slot form so the per-test caller avoids a $(...) capture fork (#764).
# Arguments: $1 basename
_BASHUNIT_HELPER_ID_OUT=""
function bashunit::helper::generate_id() {
  local basename="$1"
  # Inline normalize_variable_name + random_str to avoid two forks per call.
  # generate_id is called once per test and per file load.
  local sanitized="${basename//[^a-zA-Z0-9_]/_}"
  case "${sanitized:0:1}" in
  [a-zA-Z_]) ;;
  *) sanitized="_$sanitized" ;;
  esac
  if bashunit::env::is_parallel_run_enabled; then
    local _chars='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local _suffix=''
    local _i
    for ((_i = 0; _i < 6; _i++)); do
      _suffix="$_suffix${_chars:RANDOM%${#_chars}:1}"
    done
    _BASHUNIT_HELPER_ID_OUT="${sanitized}_$$_${_suffix}"
  else
    _BASHUNIT_HELPER_ID_OUT="${sanitized}_$$"
  fi
}

