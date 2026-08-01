#!/usr/bin/env bash

# @tag extraction and matching.

#
# Scans a script once and caches its test-function -> tags pairs.
# Memoized by resolved path, so repeated calls for the same file do not rescan.
# Arguments: $1 - path to the test script
#
function bashunit::helper::build_tags_map() {
  local script=$1
  # Handle directory changes in set_up_before_script (issue #529)
  if [ ! -f "$script" ] && [ -n "${BASHUNIT_WORKING_DIR:-}" ]; then
    script="$BASHUNIT_WORKING_DIR/$script"
  fi

  if [ ! -f "$script" ]; then
    # Unreadable path: reset to an empty map keyed to this argument so a
    # follow-up lookup returns empty without rescanning.
    _BASHUNIT_TAGS_MAP_SCRIPT="$1"
    _BASHUNIT_TAGS_MAP_FNS=()
    _BASHUNIT_TAGS_MAP_TAGS=()
    return
  fi

  if [ "$script" = "$_BASHUNIT_TAGS_MAP_SCRIPT" ]; then
    return
  fi

  _BASHUNIT_TAGS_MAP_SCRIPT="$script"
  _BASHUNIT_TAGS_MAP_FNS=()
  _BASHUNIT_TAGS_MAP_TAGS=()

  local count=0
  local fn tags
  # Single awk pass emits "<fn>\t<tags>" for every function that carries at
  # least one `# @tag <name>` comment in the contiguous comment block directly
  # above its definition, mirroring the previous per-function backward walk.
  # Tags accumulate nearest-to-the-function first (same order the old walk
  # produced). A blank or non-comment line breaks the association; other
  # comment lines keep the block open. Both `function test_x` and `test_x()`
  # definition styles are recognised.
  while IFS=$'\t' read -r fn tags; do
    [ -z "$fn" ] && continue
    _BASHUNIT_TAGS_MAP_FNS[count]="$fn"
    _BASHUNIT_TAGS_MAP_TAGS[count]="$tags"
    count=$((count + 1))
  done < <(awk '
    /^[[:space:]]*#[[:space:]]*@tag[[:space:]]/ {
      t = $0
      sub(/^[[:space:]]*#[[:space:]]*@tag[[:space:]]+/, "", t)
      tags = (tags == "" ? t : t "," tags)
      next
    }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*(function[[:space:]]+)?[A-Za-z_][A-Za-z0-9_:]*[[:space:]]*\(\)/ {
      fn = $0
      sub(/^[[:space:]]*(function[[:space:]]+)?/, "", fn)
      sub(/[[:space:]]*\(\).*/, "", fn)
      if (tags != "") printf "%s\t%s\n", fn, tags
      tags = ""
      next
    }
    { tags = "" }
  ' "$script" 2>/dev/null)
}


#
# Pure-bash lookup against the cached tags map.
# Writes the comma-separated tags (or empty) into _BASHUNIT_TAGS_OUT.
# Arguments: $1 - test-function name
#
function bashunit::helper::tags_for_function() {
  local function_name=$1
  local i=0
  local total=${#_BASHUNIT_TAGS_MAP_FNS[@]}
  while [ "$i" -lt "$total" ]; do
    if [ "${_BASHUNIT_TAGS_MAP_FNS[i]}" = "$function_name" ]; then
      _BASHUNIT_TAGS_OUT="${_BASHUNIT_TAGS_MAP_TAGS[i]}"
      return
    fi
    i=$((i + 1))
  done
  _BASHUNIT_TAGS_OUT=""
}


#
# Checks if a function's tags match the include/exclude filters.
# Include uses OR logic (any match passes).
# Exclude uses OR logic (any match fails).
# Exclude takes precedence over include.
# Arguments: $1 - comma-separated tags for the function,
#            $2 - comma-separated include tags (empty = no filter),
#            $3 - comma-separated exclude tags (empty = no filter)
# Returns: 0 if the function should run, 1 if it should be skipped
#
function bashunit::helper::function_matches_tags() {
  local fn_tags="$1"
  local include_tags="$2"
  local exclude_tags="$3"

  # Check exclude tags first (exclude wins over include)
  if [ -n "$exclude_tags" ]; then
    local IFS=','
    local etag
    for etag in $exclude_tags; do
      local check_tag
      for check_tag in $fn_tags; do
        if [ "$check_tag" = "$etag" ]; then
          return 1
        fi
      done
    done
  fi

  # Check include tags (OR logic: any match passes)
  if [ -n "$include_tags" ]; then
    if [ -z "$fn_tags" ]; then
      return 1
    fi
    local IFS=','
    local itag
    for itag in $include_tags; do
      local check_tag
      for check_tag in $fn_tags; do
        if [ "$check_tag" = "$itag" ]; then
          return 0
        fi
      done
    done
    return 1
  fi

  return 0
}
