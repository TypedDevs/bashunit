#!/usr/bin/env bash

##
# --rerun-failed support.
#
# Recording (every run, regardless of the flag): each failing test appends its
# raw "<test_file>:<function_name>" identity to the shared collection temp file
# RERUN_FAILED_OUTPUT_PATH (created in env.sh). File appends work across the
# parallel test subshells, so both modes share one collector. At the end of a
# run the collector is persisted to the cache file (deduped); a fully green run
# truncates it.
#
# Replay (only with --rerun-failed): the cache is loaded, discovery is
# restricted to the recorded files, and each file's functions are filtered to
# the recorded names. --filter/--tag still apply on top (intersection).
##

# Entries loaded for replay: newline-delimited "<file>:<fn>". Empty when none.
_BASHUNIT_RERUN_ENTRIES=""

##
# Path to the persisted cache file. Defaults to ".bashunit/last-failed" under
# the working directory; BASHUNIT_RERUN_CACHE_DIR overrides the directory.
##
function bashunit::rerun::cache_file() {
  echo "${BASHUNIT_RERUN_CACHE_DIR:-.bashunit}/last-failed"
}

function bashunit::rerun::is_enabled() {
  [ "${BASHUNIT_RERUN_FAILED:-false}" = true ]
}

##
# Appends a failed test's raw identity to the collection temp file.
# Arguments: $1 test file path, $2 raw function name.
##
function bashunit::rerun::record() {
  local test_file=$1
  local fn_name=$2
  [ -n "${RERUN_FAILED_OUTPUT_PATH:-}" ] || return 0
  printf '%s:%s\n' "$test_file" "$fn_name" >>"$RERUN_FAILED_OUTPUT_PATH" 2>/dev/null || true
}

##
# Persists the collected failures to the cache (deduped, first-seen order).
# A run with no collected failures truncates an existing cache. Write errors
# (e.g. a read-only working directory) are ignored silently.
##
function bashunit::rerun::persist() {
  local cache
  cache="$(bashunit::rerun::cache_file)"
  local collected="${RERUN_FAILED_OUTPUT_PATH:-}"

  if [ -n "$collected" ] && [ -s "$collected" ]; then
    local dir="${cache%/*}"
    if [ "$dir" != "$cache" ]; then
      mkdir -p "$dir" 2>/dev/null || return 0
    fi
    awk '!seen[$0]++' "$collected" >"$cache" 2>/dev/null || true
  elif [ -f "$cache" ]; then
    : >"$cache" 2>/dev/null || true
  fi
}

##
# Loads the cache into _BASHUNIT_RERUN_ENTRIES (empty when the cache is absent).
##
function bashunit::rerun::load() {
  local cache
  cache="$(bashunit::rerun::cache_file)"
  _BASHUNIT_RERUN_ENTRIES=""
  [ -f "$cache" ] || return 0
  _BASHUNIT_RERUN_ENTRIES="$(cat "$cache" 2>/dev/null)"
}

function bashunit::rerun::has_entries() {
  [ -n "$_BASHUNIT_RERUN_ENTRIES" ]
}

##
# Echoes the distinct test files from the loaded entries (first-seen order).
##
function bashunit::rerun::files() {
  [ -n "$_BASHUNIT_RERUN_ENTRIES" ] || return 0
  printf '%s\n' "$_BASHUNIT_RERUN_ENTRIES" | awk '
    NF {
      file = $0
      sub(/:[^:]*$/, "", file)
      if (!seen[file]++) print file
    }'
}

##
# Returns 0 when "<file>:<fn>" is among the loaded entries.
##
function bashunit::rerun::allows() {
  local file=$1
  local fn=$2
  case "
$_BASHUNIT_RERUN_ENTRIES
" in
  *"
$file:$fn
"*) return 0 ;;
  esac
  return 1
}

##
# Filters a space-separated function list down to the ones recorded for a file.
# Arguments: $1 test file path, $2 space-separated function names.
##
function bashunit::rerun::filter_functions() {
  local file=$1
  local functions=$2
  local kept=""
  local fn
  for fn in $functions; do
    if bashunit::rerun::allows "$file" "$fn"; then
      kept="$kept $fn"
    fi
  done
  echo "${kept# }"
}
