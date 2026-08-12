#!/usr/bin/env bash

# Coverage run configuration: data-file locations, tracked-file roots and engine selection.

# Coverage data storage
# Use :- to preserve inherited values from parent bashunit processes
_BASHUNIT_COVERAGE_DATA_FILE="${_BASHUNIT_COVERAGE_DATA_FILE:-}"
_BASHUNIT_COVERAGE_TRACKED_FILES="${_BASHUNIT_COVERAGE_TRACKED_FILES:-}"

# Simple file-based cache for tracked files (Bash 3.0 compatible)
# The tracked cache file stores files that have already been processed
_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE="${_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE:-}"

# File to store which tests hit each line (for detailed coverage tooltips)
_BASHUNIT_COVERAGE_TEST_HITS_FILE="${_BASHUNIT_COVERAGE_TEST_HITS_FILE:-}"

# Engine picked once in init and inherited by every worker, so the per-test
# enable path never re-forks resolve_engine
_BASHUNIT_COVERAGE_ENGINE_RESOLVED="${_BASHUNIT_COVERAGE_ENGINE_RESOLVED:-}"

_BASHUNIT_COVERAGE_IS_PARALLEL=""

# Auto-discover coverage paths from test file names
# When no explicit coverage paths are set, find source files matching test file base names
# Example: tests/unit/assert/basic_test.sh -> finds src/assert/*.sh
function bashunit::coverage::auto_discover_paths() {
  local project_root
  project_root="$(pwd)"
  local -a discovered_paths=()
  local discovered_paths_count=0
  local test_file

  for test_file in "$@"; do
    # Extract base name: tests/unit/assert_test.sh -> assert_test.sh
    local file_basename
    file_basename=$(basename "$test_file")

    # Remove test suffixes to get source name: assert_test.sh -> assert
    local source_name="${file_basename%_test.sh}"
    [ "$source_name" = "$file_basename" ] && source_name="${file_basename%Test.sh}"
    [ "$source_name" = "$file_basename" ] && continue # Not a test file pattern

    # Find matching source files recursively
    local found_file
    while IFS= read -r -d '' found_file; do
      # Skip test files and vendor directories
      case "$found_file" in
      *test* | *Test* | *vendor* | *node_modules*) continue ;;
      esac
      discovered_paths[discovered_paths_count]="$found_file"
      discovered_paths_count=$((discovered_paths_count + 1))
    done < <(find "$project_root" -name "${source_name}*.sh" -type f -print0 2>/dev/null)
  done

  # Return unique paths, comma-separated
  if [ "$discovered_paths_count" -gt 0 ]; then
    printf '%s\n' "${discovered_paths[@]}" | sort -u | tr '\n' ',' | sed 's/,$//'
  fi
}

function bashunit::coverage::init() {
  if ! bashunit::env::is_coverage_enabled; then
    return 0
  fi

  # Skip coverage init if we're a subprocess of another coverage-enabled bashunit
  # This prevents nested bashunit calls (e.g., in acceptance tests) from
  # interfering with the parent's coverage tracking
  if [ -n "${_BASHUNIT_COVERAGE_DATA_FILE:-}" ]; then
    export BASHUNIT_COVERAGE=false
    return 0
  fi

  # Create coverage data directory with unique name via mktemp -d
  # (avoids $$-$RANDOM collisions and symlink races in shared temp dirs)
  local coverage_dir
  coverage_dir=$("${MKTEMP:-mktemp}" -d "${BASHUNIT_TEMP_DIR:-${TMPDIR:-/tmp}}/bashunit-coverage.XXXXXXXX")

  _BASHUNIT_COVERAGE_DATA_FILE="${coverage_dir}/hits.dat"
  _BASHUNIT_COVERAGE_TRACKED_FILES="${coverage_dir}/files.dat"
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE="${coverage_dir}/cache.dat"
  _BASHUNIT_COVERAGE_TEST_HITS_FILE="${coverage_dir}/test_hits.dat"

  # Initialize empty files
  : >"$_BASHUNIT_COVERAGE_DATA_FILE"
  : >"$_BASHUNIT_COVERAGE_TRACKED_FILES"
  : >"$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
  : >"$_BASHUNIT_COVERAGE_TEST_HITS_FILE"

  # Reset in-memory caches and buffers
  _BASHUNIT_COVERAGE_BUFFER=""
  _BASHUNIT_COVERAGE_BUFFER_COUNT=0
  _BASHUNIT_COVERAGE_HITS_BUFFER=""
  # The lookups live in the variable table now, so clearing them means dropping
  # their namespaces: a second run in the same shell must not inherit a
  # tracking decision or a normalized path from the first.
  bashunit::coverage::reset_lookup_namespace "_BASHUNIT_COVLOOKUP_TRACK_"
  bashunit::coverage::reset_lookup_namespace "_BASHUNIT_COVLOOKUP_PATH_"
  _BASHUNIT_COVERAGE_IS_PARALLEL=""
  _BASHUNIT_COVERAGE_STATS_FILES=()
  _BASHUNIT_COVERAGE_STATS_EXEC=()
  _BASHUNIT_COVERAGE_STATS_HIT=()
  _BASHUNIT_COVERAGE_STATS_PCT=()
  _BASHUNIT_COVERAGE_STATS_CLASS=()
  _BASHUNIT_COVERAGE_STATS_COUNT=0
  bashunit::coverage::reset_lookup_namespace "_BASHUNIT_COVLOOKUP_STATS_"

  _BASHUNIT_COVERAGE_ENGINE_RESOLVED=$(bashunit::coverage::resolve_engine)

  export _BASHUNIT_COVERAGE_DATA_FILE
  export _BASHUNIT_COVERAGE_TRACKED_FILES
  export _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE
  export _BASHUNIT_COVERAGE_TEST_HITS_FILE
  export _BASHUNIT_COVERAGE_ENGINE_RESOLVED
}

##
# Whether this Bash can send xtrace to a private file descriptor.
# BASH_XTRACEFD and the {fd}> auto-allocation it relies on both landed in 4.1;
# below that, xtrace can only reach stderr, where it would intermix with the
# output of the code under test.
# Returns: 0 when supported, 1 otherwise
##
function bashunit::coverage::xtrace_is_supported() {
  if [ "${BASH_VERSINFO[0]}" -gt 4 ]; then
    return 0
  fi
  [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -ge 1 ]
}

##
# Resolve BASHUNIT_COVERAGE_ENGINE (auto|xtrace|trap) to the engine to run.
# Anything unrecognised, and any xtrace request this Bash cannot honour, falls
# back to the trap engine: it is slower but available everywhere.
# Returns: prints "xtrace" or "trap"
##
function bashunit::coverage::resolve_engine() {
  case "${BASHUNIT_COVERAGE_ENGINE:-auto}" in
  xtrace | auto)
    if bashunit::coverage::xtrace_is_supported; then
      echo "xtrace"
    else
      echo "trap"
    fi
    ;;
  *) echo "trap" ;;
  esac
}

##
# The engine this run is actually using.
# Prefers the value resolved once in init and exported to every worker, so a
# worker reports what it ran rather than re-deciding.
# Returns: prints "xtrace" or "trap"
##
function bashunit::coverage::engine_in_use() {
  if [ -n "${_BASHUNIT_COVERAGE_ENGINE_RESOLVED:-}" ]; then
    echo "$_BASHUNIT_COVERAGE_ENGINE_RESOLVED"
    return 0
  fi
  bashunit::coverage::resolve_engine
}

##
# Whether an explicit engine request could not be honoured.
# Only an explicit `xtrace` counts: `auto` resolving to trap is the documented
# fallback, not an ignored request. macOS ships Bash 3.2, so this is the common
# case there and used to be entirely silent (#1005).
# Returns: 0 when downgraded, 1 otherwise
##
function bashunit::coverage::engine_was_downgraded() {
  if [ "${BASHUNIT_COVERAGE_ENGINE:-auto}" != "xtrace" ]; then
    return 1
  fi
  if bashunit::coverage::xtrace_is_supported; then
    return 1
  fi
  return 0
}
