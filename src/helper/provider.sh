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
    bashunit::helper::annotations_reset
    return
  fi

  if [ "$script" = "$_BASHUNIT_PROVIDER_MAP_SCRIPT" ]; then
    return
  fi

  _BASHUNIT_PROVIDER_MAP_SCRIPT="$script"
  _BASHUNIT_PROVIDER_MAP_FNS=()
  _BASHUNIT_PROVIDER_MAP_PROVIDERS=()
  _BASHUNIT_PROVIDER_MAP_NO_PARALLEL=false

  bashunit::helper::annotations_reset

  local count=0
  local fn provider annot_timeout annot_retry annot_skip annot_reason
  # Single awk pass emits "<fn>\t<provider>" for every function whose
  # definition is at most two lines below a `# @data_provider` (or
  # `# data_provider`) annotation, mirroring the previous grep -B2 + sed.
  # A reserved sentinel fn name carries the no-parallel-tests flag out of the
  # single awk pass; real fn names are identifiers so they never collide.
  #
  # The per-test `# @timeout` / `# @retry` / `# @skip` markers ride on this same
  # pass, as "@@annot@@" rows: this scan already visits every file exactly once
  # in the main shell, and the fork budget leaves no room for a second awk per
  # file (#773). Unlike the provider marker, those follow the `# @tag` rule --
  # the contiguous comment block directly above the definition.
  while IFS=$'\t' read -r fn provider annot_timeout annot_retry annot_skip annot_reason; do
    [ -z "$fn" ] && continue
    if [ "$fn" = "@@no_parallel@@" ]; then
      [ "$provider" = "1" ] && _BASHUNIT_PROVIDER_MAP_NO_PARALLEL=true
      continue
    fi
    if [ "$fn" = "@@annot@@" ]; then
      [ "$annot_timeout" = "@@none@@" ] && annot_timeout=""
      [ "$annot_retry" = "@@none@@" ] && annot_retry=""
      bashunit::helper::annotations_record \
        "$provider" "$annot_timeout" "$annot_retry" "$annot_skip" "$annot_reason"
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
    /^[[:space:]]*#[[:space:]]*@timeout([[:space:]]|=)/ {
      v = $0
      sub(/^[[:space:]]*#[[:space:]]*@timeout[[:space:]=]+/, "", v)
      sub(/[[:space:]]+$/, "", v)
      a_timeout = v
      next
    }
    /^[[:space:]]*#[[:space:]]*@retry([[:space:]]|=)/ {
      v = $0
      sub(/^[[:space:]]*#[[:space:]]*@retry[[:space:]=]+/, "", v)
      sub(/[[:space:]]+$/, "", v)
      a_retry = v
      next
    }
    /^[[:space:]]*#[[:space:]]*@skip([[:space:]]|$)/ {
      v = $0
      sub(/^[[:space:]]*#[[:space:]]*@skip[[:space:]]*/, "", v)
      sub(/[[:space:]]+$/, "", v)
      a_skip = 1
      a_reason = v
      next
    }
    # Any other comment keeps the block open, the same rule @tag follows.
    /^[[:space:]]*#/ { next }
    {
      is_fn = match($0, /^[[:space:]]*(function[[:space:]]+)?[A-Za-z_][A-Za-z0-9_:]*[[:space:]]*\(\)/)
      if (is_fn) {
        fn = $0
        sub(/^[[:space:]]*(function[[:space:]]+)?/, "", fn)
        sub(/[[:space:]]*\(\).*/, "", fn)
      }

      if (pending != "" && NR - pending_line <= 2) {
        if (is_fn) {
          printf "%s\t%s\n", fn, pending
          pending = ""
        }
      } else if (pending != "" && NR - pending_line > 2) {
        pending = ""
      }

      if (is_fn && (a_timeout != "" || a_retry != "" || a_skip != "")) {
        # Tab is an IFS whitespace character, so `read` collapses a run of them
        # and an empty interior field would shift every later one. Absent
        # values therefore travel as a sentinel; the reason is last and may be
        # empty.
        printf "@@annot@@\t%s\t%s\t%s\t%s\t%s\n", fn,
          (a_timeout == "" ? "@@none@@" : a_timeout),
          (a_retry == "" ? "@@none@@" : a_retry),
          (a_skip == "" ? "0" : a_skip), a_reason
      }
      # A blank or code line ends the block for the next definition, whether or
      # not this line was one.
      a_timeout = ""
      a_retry = ""
      a_skip = ""
      a_reason = ""
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

