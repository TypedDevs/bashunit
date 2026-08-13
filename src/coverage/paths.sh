#!/usr/bin/env bash

# Which files coverage tracks, and the hot-path caches behind that decision.

# In-memory lookups for the hot paths.
#
# These used to be one long string per cache, scanned with a leading-`*` glob.
# That scan is quadratic in the number of entries on Bash 3.2: measured at
# 0.38ms per lookup at 11 entries, 3.4ms at 40 and 26.7ms at 121 -- the cache
# cost more than the work it replaced (#1056).
#
# Bash's own variable table is the associative array this repo cannot declare,
# the same trick the spy state uses (_BASHUNIT_SPY_${variable}_TIMES_FILE).
# The key is the path with everything but [a-zA-Z0-9] collapsed to `_`, so two
# different paths can produce the same key; the original path is stored beside
# the value and compared on read, which makes a collision a miss rather than a
# wrong answer.
_BASHUNIT_COVERAGE_LOOKUP_OUT=""

_BASHUNIT_COVERAGE_LOOKUP_KEY_OUT=""

##
# The variable-name-safe key for a path, into
# _BASHUNIT_COVERAGE_LOOKUP_KEY_OUT.
#
# A return slot, not a `$(...)`: lookup_get runs once per traced line on the
# capture path, and a command substitution there would be a fork per line --
# exactly what the fork budget forbids.
# Arguments: $1 - namespace prefix, $2 - path
##
function bashunit::coverage::lookup_key_to_slot() {
  _BASHUNIT_COVERAGE_LOOKUP_KEY_OUT="$1${2//[^a-zA-Z0-9]/_}"
}

##
# Stores a value under a path key.
# Arguments: $1 - namespace prefix, $2 - path, $3 - value
##
function bashunit::coverage::lookup_put() {
  bashunit::coverage::lookup_key_to_slot "$1" "$2"
  local key=$_BASHUNIT_COVERAGE_LOOKUP_KEY_OUT
  eval "${key}_PATH=\$2"
  eval "${key}_VALUE=\$3"
}

##
# Reads the value stored for a path into _BASHUNIT_COVERAGE_LOOKUP_OUT.
# Returns 1 when absent, or when the slot holds a different path (a key
# collision, which must read as a miss).
# Arguments: $1 - namespace prefix, $2 - path
##
function bashunit::coverage::lookup_get() {
  bashunit::coverage::lookup_key_to_slot "$1" "$2"
  local path_var="${_BASHUNIT_COVERAGE_LOOKUP_KEY_OUT}_PATH"
  local value_var="${_BASHUNIT_COVERAGE_LOOKUP_KEY_OUT}_VALUE"

  _BASHUNIT_COVERAGE_LOOKUP_OUT=""
  if [ "${!path_var:-}" != "$2" ]; then
    return 1
  fi
  _BASHUNIT_COVERAGE_LOOKUP_OUT="${!value_var:-}"
  return 0
}

##
# Drops every entry of one namespace, so a second run in the same shell cannot
# inherit a stale decision.
# Arguments: $1 - namespace prefix
##
function bashunit::coverage::reset_lookup_namespace() {
  local name
  for name in $(compgen -v "$1" 2>/dev/null || true); do
    unset "$name"
  done
}

# Normalize file path to absolute
function bashunit::coverage::normalize_path() {
  local file="$1"

  [ -f "$file" ] || {
    # `builtin printf` throughout: a test spying or mocking printf must not be
    # able to shadow a path the coverage engine depends on (#724).
    builtin printf '%s' "$file"
    return 0
  }

  # One fork, not four. This runs on every cache miss in the DEBUG trap -- 494
  # times in a single run of one test file -- and `$(cd "$(dirname X)" && pwd)`
  # plus `$(basename X)` is a command substitution each: 2081ms per 500 calls
  # against 424ms this way (#1102).
  #
  # The `cd` stays: it resolves symlinks, so `/tmp/x` normalizes to
  # `/private/tmp/x` on macOS the way the rest of the tracking expects. Pure
  # string manipulation would be faster still and would report the unresolved
  # path, which no longer matches the tracked roots.
  local dir="${file%/*}" base="${file##*/}"
  if [ "$dir" = "$file" ]; then
    dir="."
  elif [ -z "$dir" ]; then
    dir="/"
  fi

  builtin printf '%s/%s' "$(cd "$dir" 2>/dev/null && pwd)" "$base"
}

# Get deduplicated list of tracked files
function bashunit::coverage::get_tracked_files() {
  if [ ! -f "$_BASHUNIT_COVERAGE_TRACKED_FILES" ]; then
    return
  fi
  sort -u "$_BASHUNIT_COVERAGE_TRACKED_FILES"
}

##
# The `case` pattern the DEBUG trap uses to reject a file before calling into
# the recorder, built once per run from BASHUNIT_COVERAGE_PATHS.
#
# The trap fires for every executed line, including every line of bashunit's
# own code running inside the test body and the hooks; most of those events
# used to pay a function call, two locals and a cache lookup only to be
# rejected (#1060). This pattern is a pre-filter, deliberately a SUPERSET of
# what should_track admits -- exclusions and the real decision stay there.
#
# Each configured path contributes four alternatives, because the trap sees
# ${BASH_SOURCE[0]} exactly as the source wrote it: resolved absolute, as
# given, and the two forms of "somewhere under a directory of that name",
# which is what keeps a test that `cd`s (issue #529) from losing coverage.
#
# Writes _BASHUNIT_COVERAGE_TRAP_GLOB; empty means "no filtering", which is
# what an unset BASHUNIT_COVERAGE_PATHS must produce so behaviour cannot change.
##
_BASHUNIT_COVERAGE_TRAP_GLOB=""

function bashunit::coverage::build_trap_glob() {
  _BASHUNIT_COVERAGE_TRAP_GLOB=""

  [ -n "${BASHUNIT_COVERAGE_PATHS:-}" ] || return 0

  local glob=""
  local cwd
  cwd=$(pwd)
  local old_ifs="$IFS"
  IFS=','
  local path resolved relative
  for path in $BASHUNIT_COVERAGE_PATHS; do
    [ -n "$path" ] || continue
    case "$path" in
    /*) resolved="$path" ;;
    *) resolved="$cwd/$path" ;;
    esac

    # An absolute coverage path still has to admit the relative spellings: the
    # trap sees ${BASH_SOURCE[0]} as the source wrote it, and a file sourced as
    # "src/util/str.sh" never matches "/repo/src/util*".
    relative="$path"
    case "$relative" in
    "$cwd"/*) relative="${relative#"$cwd"/}" ;;
    esac

    if [ -n "$glob" ]; then
      glob="$glob|"
    fi
    glob="$glob${resolved}*|${relative}*|./${relative}*|*/${relative}/*|*/${relative}"
  done
  IFS="$old_ifs"

  _BASHUNIT_COVERAGE_TRAP_GLOB="$glob"
}

##
# Writes every file under BASHUNIT_COVERAGE_PATHS into the tracked list, before
# a single test runs.
#
# A file entered that list the first time one of its lines executed, so a file
# no test ever reached was absent from the report and could not lower the
# percentage: coverage was measured over the files that ran, not over the files
# the user asked about. On this repo that was 11 files of 121, and a
# denominator of 2,200 against a real 9,285 (#1053).
#
# The capture path still adds files as it sees them, so nothing changes for
# executed code; get_tracked_files already sorts and dedupes. Cost is one find
# per run, bounded by the project rather than by the test count. A file created
# after this point is not seeded -- it is still tracked if it executes.
##
_BASHUNIT_COVERAGE_SEEDED=false

function bashunit::coverage::seed_tracked_files() {
  # Once per run, and at report time rather than at init: the denominator is a
  # reporting concern, and seeding in init made every capture-only run -- and
  # every unit test that calls init -- walk the whole project for nothing.
  if [ "$_BASHUNIT_COVERAGE_SEEDED" = true ]; then
    return 0
  fi
  _BASHUNIT_COVERAGE_SEEDED=true

  [ -n "${BASHUNIT_COVERAGE_PATHS:-}" ] || return 0
  [ -n "${_BASHUNIT_COVERAGE_TRACKED_FILES:-}" ] || return 0

  local old_ifs="$IFS"
  IFS=','
  local path
  for path in $BASHUNIT_COVERAGE_PATHS; do
    [ -n "$path" ] || continue
    IFS="$old_ifs"
    bashunit::coverage::_seed_one_path "$path"
    IFS=','
  done
  IFS="$old_ifs"
}

##
# Seeds one configured path.
#
# The exclusion test is inlined rather than delegated to should_track: that
# normalizes every path it is given, which is a subshell per file, and seeding
# walks the whole project. `find` is given an absolute root, so what it prints
# is already normalized, and the patterns are applied with a `case` -- the same
# `*pattern*` match should_track uses, so the seeded set and the captured set
# agree.
# Arguments: $1 - configured path
##
function bashunit::coverage::_seed_one_path() {
  local path="$1"
  local root

  case "$path" in
  /*) root="$path" ;;
  *) root="$(pwd)/$path" ;;
  esac

  if [ -f "$root" ]; then
    root="$(bashunit::coverage::normalize_path "$root")"
    bashunit::coverage::_seed_emit "$root"
    return 0
  fi
  [ -d "$root" ] || return 0
  root="$(cd "$root" && pwd)"

  local file
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    bashunit::coverage::_seed_emit "$file"
  done < <(find "$root" -type f -name '*.sh' 2>/dev/null)
}

##
# Writes one already-absolute path to the tracked list unless an exclude
# pattern matches it.
##
function bashunit::coverage::_seed_emit() {
  local file="$1"
  local old_ifs="$IFS"
  IFS=','
  local pattern
  for pattern in ${BASHUNIT_COVERAGE_EXCLUDE:-}; do
    case "$file" in
    *$pattern*)
      IFS="$old_ifs"
      return 0
      ;;
    esac
  done
  IFS="$old_ifs"

  printf '%s\n' "$file" >>"$_BASHUNIT_COVERAGE_TRACKED_FILES"
}

# The decision cache on disk, read into memory once per process.
#
# It used to be consulted with `grep "^$file:" | head -1`, three processes per
# lookup, on every in-memory miss -- and the in-memory caches die with each
# test subshell, so that was 1427 lookups in a single run of one test file:
# 2ms each against 0.064ms for an in-memory scan of the same 13 entries
# (#1104). The same shape #1076 removed from the stats cache.
#
# Entries this process writes are appended to both, so the file is read once
# and never re-read. A worker that misses an entry another worker appended
# afterwards just recomputes it, which is the same decision at a little cost.
_BASHUNIT_COVERAGE_DISKCACHE_FILE=""
_BASHUNIT_COVERAGE_DISKCACHE_KEYS=()
_BASHUNIT_COVERAGE_DISKCACHE_VALUES=()
_BASHUNIT_COVERAGE_DISKCACHE_COUNT=0

function bashunit::coverage::_diskcache_load() {
  local cache_file="$1"
  [ "$_BASHUNIT_COVERAGE_DISKCACHE_FILE" = "$cache_file" ] && return 0

  _BASHUNIT_COVERAGE_DISKCACHE_FILE="$cache_file"
  _BASHUNIT_COVERAGE_DISKCACHE_KEYS=()
  _BASHUNIT_COVERAGE_DISKCACHE_VALUES=()
  _BASHUNIT_COVERAGE_DISKCACHE_COUNT=0
  [ -f "$cache_file" ] || return 0

  local line idx=0
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    _BASHUNIT_COVERAGE_DISKCACHE_KEYS[idx]="${line%:*}"
    _BASHUNIT_COVERAGE_DISKCACHE_VALUES[idx]="${line##*:}"
    idx=$((idx + 1))
  done <"$cache_file"
  _BASHUNIT_COVERAGE_DISKCACHE_COUNT=$idx
}

# Sets _BASHUNIT_COVERAGE_DISKCACHE_OUT to the cached decision, or returns 1.
_BASHUNIT_COVERAGE_DISKCACHE_OUT=""

function bashunit::coverage::_diskcache_get() {
  local file="$1" idx=0
  while [ "$idx" -lt "$_BASHUNIT_COVERAGE_DISKCACHE_COUNT" ]; do
    if [ "${_BASHUNIT_COVERAGE_DISKCACHE_KEYS[idx]}" = "$file" ]; then
      _BASHUNIT_COVERAGE_DISKCACHE_OUT="${_BASHUNIT_COVERAGE_DISKCACHE_VALUES[idx]}"
      return 0
    fi
    idx=$((idx + 1))
  done
  return 1
}

# Records a decision in the file and in the copy this process is reading.
function bashunit::coverage::_diskcache_put() {
  local cache_file="$1" file="$2" decision="$3"
  { [ -n "$cache_file" ] && [ -f "$cache_file" ]; } || return 0

  echo "${file}:${decision}" >>"$cache_file"
  local idx="$_BASHUNIT_COVERAGE_DISKCACHE_COUNT"
  _BASHUNIT_COVERAGE_DISKCACHE_KEYS[idx]="$file"
  _BASHUNIT_COVERAGE_DISKCACHE_VALUES[idx]="$decision"
  _BASHUNIT_COVERAGE_DISKCACHE_COUNT=$((idx + 1))
}

function bashunit::coverage::should_track() {
  local file="$1"

  # Skip empty paths
  [ -z "$file" ] && return 1

  # Skip if tracked files list doesn't exist (trap inherited by child process)
  [ -z "$_BASHUNIT_COVERAGE_TRACKED_FILES" ] && return 1

  # Check file-based cache for previous decision (Bash 3.0 compatible)
  # Cache format: "file:0" for excluded, "file:1" for tracked
  # In parallel mode, use per-process cache to avoid race conditions
  local cache_file="$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
  if bashunit::parallel::is_enabled && [ -n "$cache_file" ]; then
    cache_file="${cache_file}.$$"
    # Initialize per-process cache if needed. `${cache_file%/*}` rather than
    # dirname: this runs per call, and a fork here is a fork per file.
    if [ ! -f "$cache_file" ] && [ -d "${cache_file%/*}" ]; then
      : >"$cache_file"
    fi
  fi
  if [ -n "$cache_file" ]; then
    bashunit::coverage::_diskcache_load "$cache_file"
    if bashunit::coverage::_diskcache_get "$file"; then
      [ "$_BASHUNIT_COVERAGE_DISKCACHE_OUT" = "1" ] && return 0 || return 1
    fi
  fi

  # Normalize path
  local normalized_file
  normalized_file=$(bashunit::coverage::normalize_path "$file")

  # Check exclusion patterns
  # Save and restore IFS to avoid corrupting caller's environment
  local old_ifs="$IFS"
  IFS=','
  local pattern
  for pattern in $BASHUNIT_COVERAGE_EXCLUDE; do
    case "$normalized_file" in
    *$pattern*)
      IFS="$old_ifs"
      # Cache exclusion decision (use per-process cache in parallel mode)
      bashunit::coverage::_diskcache_put "$cache_file" "$file" "0"
      return 1
      ;;
    esac
  done

  # Check inclusion paths
  local matched=false
  local path
  for path in $BASHUNIT_COVERAGE_PATHS; do
    # Resolve relative paths
    local resolved_path
    case "$path" in
    /*)
      resolved_path="$path"
      ;;
    *)
      resolved_path="$(pwd)/$path"
      ;;
    esac
    # Collapse doubled slashes the way normalize_path's cd/pwd does, or a
    # configured path that arrived with one ("$TMPDIR/src" where TMPDIR ends in
    # a slash) never prefixes the normalized file and the whole tree reads as
    # untracked. Parameter expansion, not a cd/pwd subshell: should_track runs
    # once per file on a cache miss, and a fork here is a fork per file.
    while [ "$resolved_path" != "${resolved_path//\/\//\/}" ]; do
      resolved_path="${resolved_path//\/\//\/}"
    done

    case "$normalized_file" in
    "$resolved_path"*)
      matched=true
      break
      ;;
    esac
  done
  IFS="$old_ifs"

  if [ "$matched" = "false" ]; then
    # Cache exclusion decision (use per-process cache in parallel mode)
    bashunit::coverage::_diskcache_put "$cache_file" "$file" "0"
    return 1
  fi

  # Cache tracking decision (use per-process cache in parallel mode)
  bashunit::coverage::_diskcache_put "$cache_file" "$file" "1"

  # Track this file for later reporting
  # In parallel mode, use a per-process file to avoid race conditions
  local tracked_file="$_BASHUNIT_COVERAGE_TRACKED_FILES"
  if bashunit::parallel::is_enabled; then
    tracked_file="${_BASHUNIT_COVERAGE_TRACKED_FILES}.$$"
  fi

  # Only write if parent directory exists
  if [ -d "$(dirname "$tracked_file")" ]; then
    # Check if not already written to avoid duplicates
    if ! grep -q "^${normalized_file}$" "$tracked_file" 2>/dev/null; then
      echo "$normalized_file" >>"$tracked_file"
    fi
  fi

  return 0
}

# Convert file path to safe filename for HTML
# Return slot for path_to_filename_to_slot.
_BASHUNIT_COVERAGE_SAFE_NAME_OUT=""

##
# Sets _BASHUNIT_COVERAGE_SAFE_NAME_OUT to the page name for a source path.
#
# `$PWD` rather than `$(pwd)`: the HTML report calls this once per page and the
# subshell cost more than the string work it wrapped (#1117).
# Arguments: $1 - source file
##
function bashunit::coverage::path_to_filename_to_slot() {
  local file="$1"
  local display_file="${file#"$PWD"/}"
  # Replace / with _ and . with _
  local safe_name="${display_file//\//_}"
  _BASHUNIT_COVERAGE_SAFE_NAME_OUT="${safe_name//./_}"
}

function bashunit::coverage::path_to_filename() {
  bashunit::coverage::path_to_filename_to_slot "$1"
  echo "$_BASHUNIT_COVERAGE_SAFE_NAME_OUT"
}
