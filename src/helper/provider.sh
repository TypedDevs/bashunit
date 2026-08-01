#!/usr/bin/env bash

# @data_provider resolution and the per-script provider map.

#
# Resolves a script path, applying the issue #529 working-dir fallback.
# Writes the resolved path into _BASHUNIT_PROVIDER_RESOLVED_OUT (empty if unreadable).
#
_BASHUNIT_PROVIDER_RESOLVED_OUT=""
function bashunit::helper::_resolve_provider_script() {
  local script=$1
  # Handle directory changes in set_up_before_script (issue #529)
  if [ ! -f "$script" ] && [ -n "${BASHUNIT_WORKING_DIR:-}" ]; then
    script="$BASHUNIT_WORKING_DIR/$script"
  fi
  if [ ! -f "$script" ]; then
    _BASHUNIT_PROVIDER_RESOLVED_OUT=""
    return
  fi
  _BASHUNIT_PROVIDER_RESOLVED_OUT=$script
}


#
# Scans a script once and caches its test-function -> provider-function pairs.
# Memoized by resolved path, so repeated calls for the same file do not rescan.
# Arguments: $1 - path to the test script
#
function bashunit::helper::build_provider_map() {
  bashunit::helper::_resolve_provider_script "$1"
  local script=$_BASHUNIT_PROVIDER_RESOLVED_OUT

  if [ -z "$script" ]; then
    # Unreadable path: reset to an empty map keyed to this argument so a
    # follow-up lookup returns empty without rescanning.
    _BASHUNIT_PROVIDER_MAP_SCRIPT="$1"
    _BASHUNIT_PROVIDER_MAP_FNS=()
    _BASHUNIT_PROVIDER_MAP_PROVIDERS=()
    _BASHUNIT_PROVIDER_MAP_NO_PARALLEL=false
    return
  fi

  if [ "$script" = "$_BASHUNIT_PROVIDER_MAP_SCRIPT" ]; then
    return
  fi

  _BASHUNIT_PROVIDER_MAP_SCRIPT="$script"
  _BASHUNIT_PROVIDER_MAP_FNS=()
  _BASHUNIT_PROVIDER_MAP_PROVIDERS=()
  _BASHUNIT_PROVIDER_MAP_NO_PARALLEL=false

  local count=0
  local fn provider
  # Single awk pass emits "<fn>\t<provider>" for every function whose
  # definition is at most two lines below a `# @data_provider` (or
  # `# data_provider`) annotation, mirroring the previous grep -B2 + sed.
  # A reserved sentinel fn name carries the no-parallel-tests flag out of the
  # single awk pass; real fn names are identifiers so they never collide.
  while IFS=$'\t' read -r fn provider; do
    [ -z "$fn" ] && continue
    if [ "$fn" = "@@no_parallel@@" ]; then
      [ "$provider" = "1" ] && _BASHUNIT_PROVIDER_MAP_NO_PARALLEL=true
      continue
    fi
    _BASHUNIT_PROVIDER_MAP_FNS[count]="$fn"
    _BASHUNIT_PROVIDER_MAP_PROVIDERS[count]="$provider"
    count=$((count + 1))
  done < <(awk '
    /^# bashunit: no-parallel-tests/ { no_parallel = 1; next }
    /^[[:space:]]*#[[:space:]]*@?data_provider[[:space:]]+/ {
      p = $0
      sub(/^[[:space:]]*#[[:space:]]*@?data_provider[[:space:]]+/, "", p)
      sub(/[[:space:]]+$/, "", p)
      pending = p
      pending_line = NR
      next
    }
    {
      if (pending != "" && NR - pending_line <= 2) {
        if (match($0, /^[[:space:]]*(function[[:space:]]+)?[A-Za-z_][A-Za-z0-9_:]*[[:space:]]*\(\)/)) {
          fn = $0
          sub(/^[[:space:]]*(function[[:space:]]+)?/, "", fn)
          sub(/[[:space:]]*\(\).*/, "", fn)
          printf "%s\t%s\n", fn, pending
          pending = ""
        }
      } else if (pending != "" && NR - pending_line > 2) {
        pending = ""
      }
    }
    END { printf "@@no_parallel@@\t%d\n", no_parallel }
  ' "$script" 2>/dev/null)
}


#
# Pure-bash lookup against the cached provider map.
# Writes the provider-function name (or empty) into _BASHUNIT_PROVIDER_FN_OUT.
# Arguments: $1 - test-function name
#
function bashunit::helper::provider_for_function() {
  local function_name=$1
  local i=0
  local total=${#_BASHUNIT_PROVIDER_MAP_FNS[@]}
  while [ "$i" -lt "$total" ]; do
    if [ "${_BASHUNIT_PROVIDER_MAP_FNS[i]}" = "$function_name" ]; then
      _BASHUNIT_PROVIDER_FN_OUT="${_BASHUNIT_PROVIDER_MAP_PROVIDERS[i]}"
      return
    fi
    i=$((i + 1))
  done
  _BASHUNIT_PROVIDER_FN_OUT=""
}


function bashunit::helper::get_provider_data() {
  local function_name="$1"
  local script="$2"

  bashunit::helper::build_provider_map "$script"
  bashunit::helper::provider_for_function "$function_name"

  if [ -n "$_BASHUNIT_PROVIDER_FN_OUT" ]; then
    bashunit::helper::execute_function_if_exists "$_BASHUNIT_PROVIDER_FN_OUT"
  fi
}

