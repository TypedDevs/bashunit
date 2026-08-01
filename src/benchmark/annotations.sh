#!/usr/bin/env bash

# Parsing the @revs/@its/@max_ms markers above a bench function.

function bashunit::benchmark::reject_malformed_marker() {
  local annotation=$1
  local marker=$2
  local extracted=$3

  [ -n "$extracted" ] && return 0
  case "$annotation" in
  *"@$marker="*) ;;
  *) return 0 ;;
  esac

  printf "%sError: @%s in '%s' is not a valid value.%s\n" \
    "${_BASHUNIT_COLOR_FAILED}" "$marker" "$annotation" "${_BASHUNIT_COLOR_DEFAULT}" >&2
  return 1
}


function bashunit::benchmark::parse_annotations() {
  local fn_name=$1
  local script=$2
  local revs=1
  local its=1
  local max_ms=""

  local annotation
  annotation=$(awk "/function[[:space:]]+${fn_name}[[:space:]]*\(/ {print prev; exit} {prev=\$0}" "$script")

  local _extracted
  _extracted=$(echo "$annotation" | sed -n 's/.*@revs=\([0-9][0-9]*\).*/\1/p')
  if [ -n "$_extracted" ]; then
    revs="$_extracted"
  else
    _extracted=$(echo "$annotation" | sed -n 's/.*@revolutions=\([0-9][0-9]*\).*/\1/p')
    if [ -n "$_extracted" ]; then
      revs="$_extracted"
    fi
  fi
  bashunit::benchmark::reject_malformed_marker "$annotation" "revs" "$_extracted" || return 1
  bashunit::benchmark::reject_malformed_marker "$annotation" "revolutions" "$_extracted" || return 1

  _extracted=$(echo "$annotation" | sed -n 's/.*@its=\([0-9][0-9]*\).*/\1/p')
  if [ -n "$_extracted" ]; then
    its="$_extracted"
  else
    _extracted=$(echo "$annotation" | sed -n 's/.*@iterations=\([0-9][0-9]*\).*/\1/p')
    if [ -n "$_extracted" ]; then
      its="$_extracted"
    fi
  fi
  bashunit::benchmark::reject_malformed_marker "$annotation" "its" "$_extracted" || return 1
  bashunit::benchmark::reject_malformed_marker "$annotation" "iterations" "$_extracted" || return 1

  _extracted=$(echo "$annotation" | sed -n 's/.*@max_ms=\([0-9.][0-9.]*\).*/\1/p')
  if [ -n "$_extracted" ]; then
    max_ms="$_extracted"
  fi
  bashunit::benchmark::reject_malformed_marker "$annotation" "max_ms" "$max_ms" || return 1

  if [ -n "$max_ms" ]; then
    echo "$revs" "$its" "$max_ms"
  else
    echo "$revs" "$its"
  fi
}

