#!/usr/bin/env bash

_BASHUNIT_METADATA_KEY_OUT=""
_BASHUNIT_METADATA_INDEX_OUT=""
_BASHUNIT_METADATA_INDEX_LIMIT=64
_BASHUNIT_PROVIDER_MAP_INDEXED=false
_BASHUNIT_ANNOT_MAP_INDEXED=false

function bashunit::helper::metadata_key() {
  _BASHUNIT_METADATA_KEY_OUT=""
  case "$2" in
  '' | *[!a-zA-Z0-9_:]*) return ;;
  esac
  local escaped="${2//_/__}"
  # Escape underscores first so a colon cannot collide with a literal _c.
  _BASHUNIT_METADATA_KEY_OUT="_BASHUNIT_METADATA_${1}_${escaped//:/_c}"
}

function bashunit::helper::metadata_index_reset() {
  local group=$1 name
  shift
  [ "$#" -gt "$_BASHUNIT_METADATA_INDEX_LIMIT" ] || return 0
  for name in "$@"; do
    bashunit::helper::metadata_key "$group" "$name"
    [ -z "$_BASHUNIT_METADATA_KEY_OUT" ] || unset "$_BASHUNIT_METADATA_KEY_OUT"
  done
}

function bashunit::helper::metadata_index_record() {
  bashunit::helper::metadata_key "$1" "$2"
  [ -n "$_BASHUNIT_METADATA_KEY_OUT" ] || return 0
  local key=$_BASHUNIT_METADATA_KEY_OUT
  [ -z "${!key-}" ] || return 0
  if ! IFS= read -r "${key?}" <<<"$3"; then
    unset -v "${key?}"
    return 1
  fi
  export -n "${key?}"
}

function bashunit::helper::metadata_index_lookup() {
  _BASHUNIT_METADATA_INDEX_OUT=""
  bashunit::helper::metadata_key "$1" "$2"
  [ -n "$_BASHUNIT_METADATA_KEY_OUT" ] || return 0
  local key=$_BASHUNIT_METADATA_KEY_OUT
  _BASHUNIT_METADATA_INDEX_OUT="${!key-}"
}

function bashunit::helper::metadata_index_build() {
  local group=$1 name index=0
  shift
  [ "$#" -gt "$_BASHUNIT_METADATA_INDEX_LIMIT" ] || return 1
  for name in "$@"; do
    bashunit::helper::metadata_index_record "$group" "$name" "$index" || return 1
    index=$((index + 1))
  done
  return 0
}
