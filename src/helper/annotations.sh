#!/usr/bin/env bash

# Per-test `# @timeout`, `# @retry` and `# @skip` annotations.
#
# The scan itself lives in bashunit::helper::build_provider_map: that pass
# already walks every test file once, in the main shell, and the fork budget
# allows no second awk per file (#773). This module owns the map it fills, the
# lookups over it and the validation of the values it carries.

_BASHUNIT_ANNOT_MAP_FNS=()
_BASHUNIT_ANNOT_MAP_TIMEOUTS=()
_BASHUNIT_ANNOT_MAP_RETRIES=()
_BASHUNIT_ANNOT_MAP_SKIPS=()
_BASHUNIT_ANNOT_MAP_REASONS=()

_BASHUNIT_ANNOT_TIMEOUT_OUT=""
_BASHUNIT_ANNOT_RETRY_OUT=""
_BASHUNIT_ANNOT_SKIP_OUT="false"
_BASHUNIT_ANNOT_REASON_OUT=""

##
# Empties the map. Called whenever the provider pass starts a new file.
##
function bashunit::helper::annotations_reset() {
  _BASHUNIT_ANNOT_MAP_FNS=()
  _BASHUNIT_ANNOT_MAP_TIMEOUTS=()
  _BASHUNIT_ANNOT_MAP_RETRIES=()
  _BASHUNIT_ANNOT_MAP_SKIPS=()
  _BASHUNIT_ANNOT_MAP_REASONS=()
}

##
# Records one function's annotations, as emitted by the provider pass.
# Arguments: $1 - function, $2 - raw timeout, $3 - raw retry, $4 - skip (0|1),
#            $5 - skip reason
##
function bashunit::helper::annotations_record() {
  local count=${#_BASHUNIT_ANNOT_MAP_FNS[@]}
  _BASHUNIT_ANNOT_MAP_FNS[count]="$1"
  _BASHUNIT_ANNOT_MAP_TIMEOUTS[count]="${2-}"
  _BASHUNIT_ANNOT_MAP_RETRIES[count]="${3-}"
  _BASHUNIT_ANNOT_MAP_SKIPS[count]="${4-}"
  _BASHUNIT_ANNOT_MAP_REASONS[count]="${5-}"
}

##
# Pure-bash lookup against the cached map. Writes the raw values into
# _BASHUNIT_ANNOT_TIMEOUT_OUT, _BASHUNIT_ANNOT_RETRY_OUT,
# _BASHUNIT_ANNOT_SKIP_OUT and _BASHUNIT_ANNOT_REASON_OUT.
# Arguments: $1 - test-function name
##
function bashunit::helper::annotations_for_function() {
  local function_name=$1
  local i=0
  local total=${#_BASHUNIT_ANNOT_MAP_FNS[@]}

  _BASHUNIT_ANNOT_TIMEOUT_OUT=""
  _BASHUNIT_ANNOT_RETRY_OUT=""
  _BASHUNIT_ANNOT_SKIP_OUT="false"
  _BASHUNIT_ANNOT_REASON_OUT=""

  while [ "$i" -lt "$total" ]; do
    if [ "${_BASHUNIT_ANNOT_MAP_FNS[i]}" = "$function_name" ]; then
      _BASHUNIT_ANNOT_TIMEOUT_OUT="${_BASHUNIT_ANNOT_MAP_TIMEOUTS[i]}"
      _BASHUNIT_ANNOT_RETRY_OUT="${_BASHUNIT_ANNOT_MAP_RETRIES[i]}"
      if [ "${_BASHUNIT_ANNOT_MAP_SKIPS[i]}" = "1" ]; then
        _BASHUNIT_ANNOT_SKIP_OUT="true"
      fi
      _BASHUNIT_ANNOT_REASON_OUT="${_BASHUNIT_ANNOT_MAP_REASONS[i]}"
      return
    fi
    i=$((i + 1))
  done
}

##
# Whether a value is a non-negative integer.
# Arguments: $1 - value
##
function bashunit::helper::_annotations_is_count() {
  case "$1" in
  '' | *[!0-9]*) return 1 ;;
  esac
  return 0
}

##
# Aborts the run when a marker carries a value the runner cannot honour.
# Falling back to the default silently would run a different test than the one
# the annotation asked for, the same reasoning as @revs=abc in #884.
# Arguments: $1 - script the map was built from
##
function bashunit::helper::annotations_validate_or_exit() {
  local script=$1
  local i=0
  local total=${#_BASHUNIT_ANNOT_MAP_FNS[@]}
  local fn value

  while [ "$i" -lt "$total" ]; do
    fn="${_BASHUNIT_ANNOT_MAP_FNS[i]}"

    value="${_BASHUNIT_ANNOT_MAP_TIMEOUTS[i]}"
    if [ -n "$value" ] && ! bashunit::helper::_annotations_is_count "$value"; then
      bashunit::helper::_annotations_reject "$script" "$fn" "timeout" "$value"
    fi

    value="${_BASHUNIT_ANNOT_MAP_RETRIES[i]}"
    if [ -n "$value" ] && ! bashunit::helper::_annotations_is_count "$value"; then
      bashunit::helper::_annotations_reject "$script" "$fn" "retry" "$value"
    fi

    i=$((i + 1))
  done
}

##
# Arguments: $1 - script, $2 - function, $3 - marker, $4 - offending value
##
function bashunit::helper::_annotations_reject() {
  printf "%sError: @%s '%s' above %s in %s is not a non-negative integer.%s\n" \
    "${_BASHUNIT_COLOR_FAILED}" "$3" "$4" "$2" "$1" "${_BASHUNIT_COLOR_DEFAULT}" >&2
  exit 1
}
