#!/usr/bin/env bash

# Line capture: DEBUG-trap and xtrace engines, buffering, teardown and parallel merge.

# In-memory buffer for coverage data (reduces file I/O)


# Field separator inside an xtrace PS4 prefix. A control character keeps the
# parse correct for paths containing spaces or colons.
_BASHUNIT_COVERAGE_XTRACE_FS=$'\034'
# Bash replicates only PS4's *first* character once per nesting level, so the
# literal '|' that follows it always marks where the path begins, whatever the
# trace depth.
_BASHUNIT_COVERAGE_XTRACE_PS4='@|${BASH_SOURCE}'"$_BASHUNIT_COVERAGE_XTRACE_FS"
_BASHUNIT_COVERAGE_XTRACE_PS4="$_BASHUNIT_COVERAGE_XTRACE_PS4"'${LINENO}'"$_BASHUNIT_COVERAGE_XTRACE_FS"' '

# Per-shell xtrace state. Empty FD means the xtrace engine is not active, which
# is what disable_trap dispatches on.
_BASHUNIT_COVERAGE_XTRACE_FD=""
_BASHUNIT_COVERAGE_XTRACE_FILE=""
_BASHUNIT_COVERAGE_XTRACE_SAVED_PS4=""

# Return slots for _resolve_output_files
_BASHUNIT_COVERAGE_DATA_TARGET_OUT=""
_BASHUNIT_COVERAGE_HITS_TARGET_OUT=""


# Name kept from the trap-only era: this is the seam runner/exec.sh and
# runner/hooks.sh already call around every test body and lifecycle hook.
function bashunit::coverage::enable_trap() {
  if ! bashunit::env::is_coverage_enabled; then
    return 0
  fi

  local engine="${_BASHUNIT_COVERAGE_ENGINE_RESOLVED:-}"
  if [ -z "$engine" ]; then
    engine=$(bashunit::coverage::resolve_engine)
  fi

  if [ "$engine" = "xtrace" ]; then
    bashunit::coverage::_enable_xtrace
    return 0
  fi

  # Enable trap inheritance into functions
  set -T

  # Set DEBUG trap to record line execution
  # Use ${VAR:-} to handle unset variables when set -u is active (in subshells)
  #
  # The `case` runs inside the trap, before any function call: a line from a
  # file no coverage path can admit is rejected there instead of paying a call
  # into record_line to be rejected inside it (#1060).
  # shellcheck disable=SC2064  # the body is built here on purpose: what must
  # survive to trap time is the ${BASH_SOURCE}/${LINENO} inside the
  # single-quoted string, and the glob has to be baked in as syntax.
  local record='bashunit::coverage::record_line "${BASH_SOURCE[0]:-}" "${LINENO:-}"'
  if [ -n "${_BASHUNIT_COVERAGE_TRAP_GLOB:-}" ]; then
    # The alternation has to reach the trap as syntax, not as an expanded
    # variable: `case $x in $pattern)` does not split a `|` that arrived
    # through a parameter.
    local guarded='case "${BASH_SOURCE[0]:-}" in '
    guarded="$guarded${_BASHUNIT_COVERAGE_TRAP_GLOB}) $record ;; esac"
    # shellcheck disable=SC2064
    trap "$guarded" DEBUG
  else
    # shellcheck disable=SC2064
    trap "$record" DEBUG
  fi
}

function bashunit::coverage::disable_trap() {
  if [ -n "$_BASHUNIT_COVERAGE_XTRACE_FD" ]; then
    bashunit::coverage::_disable_xtrace
    return 0
  fi

  trap - DEBUG
  set +T
}

# Point xtrace at a per-worker trace file and mark the test boundary.
#
# The trace is *appended to and never parsed here*: parsing per test costs an
# awk fork plus a full pass per test, which measured ~27x the cost of capturing
# and cancelled the engine's whole reason to exist. Attribution that the trap
# engine reads from globals is written into the trace as a sentinel instead, and
# bashunit::coverage::finalize does one pass over everything after the run.
#
# Concurrent workers only ever run within a single test file, so the dispatcher
# ordinal that already names their .result files also keeps traces apart —
# BASHPID is Bash 4.0+ and banned by the compatibility gate.
function bashunit::coverage::_enable_xtrace() {
  local coverage_dir="${_BASHUNIT_COVERAGE_DATA_FILE%/*}"
  _BASHUNIT_COVERAGE_XTRACE_FILE="${coverage_dir}/xtrace.$$.${_BASHUNIT_RUNNER_RESULT_ORDINAL:-0}.trace"

  exec {_BASHUNIT_COVERAGE_XTRACE_FD}>>"$_BASHUNIT_COVERAGE_XTRACE_FILE"

  local test_ctx=""
  if [ -n "${_BASHUNIT_COVERAGE_CURRENT_TEST_FILE:-}" ] &&
    [ -n "${_BASHUNIT_COVERAGE_CURRENT_TEST_FN:-}" ]; then
    test_ctx="${_BASHUNIT_COVERAGE_CURRENT_TEST_FILE}:${_BASHUNIT_COVERAGE_CURRENT_TEST_FN}"
  fi
  builtin printf '%sTEST%s%s\n' "$_BASHUNIT_COVERAGE_XTRACE_FS" \
    "$_BASHUNIT_COVERAGE_XTRACE_FS" "$test_ctx" >&"$_BASHUNIT_COVERAGE_XTRACE_FD"

  _BASHUNIT_COVERAGE_XTRACE_SAVED_PS4="${PS4:-}"
  BASH_XTRACEFD=$_BASHUNIT_COVERAGE_XTRACE_FD
  PS4=$_BASHUNIT_COVERAGE_XTRACE_PS4
  set -x
}

# Stop tracing and undo anything the test body may have changed. Restoring PS4
# is what keeps a test that sets its own xtrace from corrupting later traces.
function bashunit::coverage::_disable_xtrace() {
  set +x
  PS4=$_BASHUNIT_COVERAGE_XTRACE_SAVED_PS4

  local fd="$_BASHUNIT_COVERAGE_XTRACE_FD"
  _BASHUNIT_COVERAGE_XTRACE_FD=""
  _BASHUNIT_COVERAGE_XTRACE_FILE=""

  unset BASH_XTRACEFD
  exec {fd}>&-
}


# Collect the distinct source paths a trace mentions, so the shell can make the
# should_track decision awk cannot.
_BASHUNIT_COVERAGE_XTRACE_PATHS_AWK='
{
  if (substr($0, 1, 1) != "@") { next }
  i = 1
  while (substr($0, i, 1) == "@") { i++ }
  if (substr($0, i, 1) != "|") { next }
  rest = substr($0, i + 1)
  p = index(rest, fsc)
  if (p == 0) { next }
  path = substr(rest, 1, p - 1)
  if (path != "" && !(path in seen)) { seen[path] = 1; print path }
}
'

# Emit hit records, attributing each to the test named by the last sentinel.
_BASHUNIT_COVERAGE_XTRACE_EMIT_AWK='
FILENAME == map_file {
  tab = index($0, "\t")
  if (tab > 0) {
    norm = substr($0, tab + 1)
    if (norm != "-") { tracked[substr($0, 1, tab - 1)] = norm }
  }
  next
}
substr($0, 1, 1) == fsc {
  head = substr($0, 2)
  if (substr(head, 1, 5) == "TEST" fsc) { ctx = substr(head, 6); next }
}
{
  if (substr($0, 1, 1) != "@") { next }
  i = 1
  while (substr($0, i, 1) == "@") { i++ }
  if (substr($0, i, 1) != "|") { next }
  rest = substr($0, i + 1)
  p = index(rest, fsc)
  if (p == 0) { next }
  path = substr(rest, 1, p - 1)
  if (!(path in tracked)) { next }
  tail = substr(rest, p + 1)
  q = index(tail, fsc)
  if (q == 0) { next }
  line = substr(tail, 1, q - 1)
  if (line == "") { next }
  record = tracked[path] ":" line
  print record >> data_out
  if (ctx != "") { print record "|" ctx >> hits_out }
}
'


##
# Fold every captured xtrace into the hit records the reports read.
# No-op unless the xtrace engine ran. Must be called after the last test and
# before aggregate_parallel, from the main shell.
##
function bashunit::coverage::finalize() {
  bashunit::coverage::invalidate_hits_aggregation
  if [ "${_BASHUNIT_COVERAGE_ENGINE_RESOLVED:-}" != "xtrace" ]; then
    return 0
  fi
  [ -n "$_BASHUNIT_COVERAGE_DATA_FILE" ] || return 0

  local coverage_dir="${_BASHUNIT_COVERAGE_DATA_FILE%/*}"
  local -a traces=()
  local trace
  for trace in "$coverage_dir"/xtrace.*.trace; do
    [ -f "$trace" ] || continue
    traces[${#traces[@]}]="$trace"
  done
  [ "${#traces[@]}" -gt 0 ] || return 0

  local map_file="${coverage_dir}/xtrace-map.dat"
  local paths_file="${coverage_dir}/xtrace-paths.dat"
  : >"$map_file"

  "$AWK" -v fsc="$_BASHUNIT_COVERAGE_XTRACE_FS" \
    "$_BASHUNIT_COVERAGE_XTRACE_PATHS_AWK" "${traces[@]}" >"$paths_file"

  local path
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if bashunit::coverage::should_track "$path"; then
      builtin printf '%s\t%s\n' "$path" \
        "$(bashunit::coverage::normalize_path "$path")" >>"$map_file"
    else
      builtin printf '%s\t-\n' "$path" >>"$map_file"
    fi
  done <"$paths_file"

  "$AWK" \
    -v map_file="$map_file" \
    -v fsc="$_BASHUNIT_COVERAGE_XTRACE_FS" \
    -v data_out="$_BASHUNIT_COVERAGE_DATA_FILE" \
    -v hits_out="$_BASHUNIT_COVERAGE_TEST_HITS_FILE" \
    "$_BASHUNIT_COVERAGE_XTRACE_EMIT_AWK" "$map_file" "${traces[@]}"

  rm -f "$paths_file" "${traces[@]}"
}

function bashunit::coverage::record_line() {
  local file="$1"
  local lineno="$2"

  # Skip if no file or line
  { [ -z "$file" ] || [ -z "$lineno" ]; } && return 0

  # Skip if coverage data file doesn't exist (trap inherited by child process)
  [ -z "$_BASHUNIT_COVERAGE_DATA_FILE" ] && return 0

  # Fast in-memory should_track cache (avoids grep + file I/O per line)
  local decision=""
  if bashunit::coverage::lookup_get "_BASHUNIT_COVLOOKUP_TRACK_" "$file"; then
    decision="$_BASHUNIT_COVERAGE_LOOKUP_OUT"
  else
    if bashunit::coverage::should_track "$file"; then
      decision=1
    else
      decision=0
    fi
    bashunit::coverage::lookup_put "_BASHUNIT_COVLOOKUP_TRACK_" "$file" "$decision"
  fi
  if [ "$decision" = "0" ]; then
    return 0
  fi

  # Fast in-memory path normalization cache (avoids cd + pwd subshell per line)
  local normalized_file=""
  if bashunit::coverage::lookup_get "_BASHUNIT_COVLOOKUP_PATH_" "$file"; then
    normalized_file="$_BASHUNIT_COVERAGE_LOOKUP_OUT"
  else
    normalized_file=$(bashunit::coverage::normalize_path "$file")
    bashunit::coverage::lookup_put "_BASHUNIT_COVLOOKUP_PATH_" "$file" "$normalized_file"
  fi

  # Write the record out now rather than buffering it in a variable.
  #
  # A buffer that lives in a shell variable dies with the subshell that filled
  # it, so every hit recorded inside a `$( )` was lost unless that subshell
  # happened to reach the flush threshold first: 196 of 236 hits on Bash 5,
  # deterministically, while Bash 3.2 lost none -- the same project reporting
  # different coverage per Bash version. Appending is also FASTER than growing
  # the string was (8896ms to 6739ms on 3.2, 4612ms to 3988ms on 5), and a
  # one-line append interleaves better between parallel workers than a
  # multi-kilobyte flush (#1101).
  #
  # `builtin printf` so a test spying or mocking printf cannot shadow the
  # coverage write and silently drop data (#724).
  bashunit::coverage::_resolve_output_files
  builtin printf '%s:%s\n' "$normalized_file" "$lineno" \
    >>"$_BASHUNIT_COVERAGE_DATA_TARGET_OUT"

  if [ -n "${_BASHUNIT_COVERAGE_CURRENT_TEST_FILE:-}" ] &&
    [ -n "${_BASHUNIT_COVERAGE_CURRENT_TEST_FN:-}" ]; then
    builtin printf '%s:%s|%s:%s\n' "$normalized_file" "$lineno" \
      "$_BASHUNIT_COVERAGE_CURRENT_TEST_FILE" "$_BASHUNIT_COVERAGE_CURRENT_TEST_FN" \
      >>"$_BASHUNIT_COVERAGE_HITS_TARGET_OUT"
  fi

  # The report must not read counts that predate these records.
  _BASHUNIT_COVERAGE_HITS_AGGREGATED=false
  _BASHUNIT_COVERAGE_HITS_BY_LINE_FILE=""
}

# Resolve the parallel-safe destinations for hit records into the return slots
# _BASHUNIT_COVERAGE_DATA_TARGET_OUT and _BASHUNIT_COVERAGE_HITS_TARGET_OUT.
function bashunit::coverage::_resolve_output_files() {
  # Cache the parallel check to avoid function calls
  if [ -z "$_BASHUNIT_COVERAGE_IS_PARALLEL" ]; then
    if bashunit::parallel::is_enabled; then
      _BASHUNIT_COVERAGE_IS_PARALLEL="yes"
    else
      _BASHUNIT_COVERAGE_IS_PARALLEL="no"
    fi
  fi

  if [ "$_BASHUNIT_COVERAGE_IS_PARALLEL" = "yes" ]; then
    _BASHUNIT_COVERAGE_DATA_TARGET_OUT="${_BASHUNIT_COVERAGE_DATA_FILE}.$$"
    _BASHUNIT_COVERAGE_HITS_TARGET_OUT="${_BASHUNIT_COVERAGE_TEST_HITS_FILE}.$$"
  else
    _BASHUNIT_COVERAGE_DATA_TARGET_OUT="$_BASHUNIT_COVERAGE_DATA_FILE"
    _BASHUNIT_COVERAGE_HITS_TARGET_OUT="$_BASHUNIT_COVERAGE_TEST_HITS_FILE"
  fi
}

##
# Makes the records written so far readable by the report.
#
# It used to write out an in-memory buffer; records go straight to disk now
# (#1101), so all that remains is dropping the aggregation computed before
# them. Kept because callers mean "publish what I recorded", not "write a
# buffer".
##
function bashunit::coverage::flush_buffer() {
  bashunit::coverage::invalidate_hits_aggregation
}

function bashunit::coverage::aggregate_parallel() {
  bashunit::coverage::invalidate_hits_aggregation
  # Aggregate per-process coverage files created during parallel execution
  local base_file="$_BASHUNIT_COVERAGE_DATA_FILE"
  local tracked_base="$_BASHUNIT_COVERAGE_TRACKED_FILES"
  local test_hits_base="$_BASHUNIT_COVERAGE_TEST_HITS_FILE"

  # Find and merge all per-process coverage data files
  # Use nullglob to handle case when no files match
  local pid_files pid_file
  pid_files=$(ls -1 "${base_file}."* 2>/dev/null) || true
  if [ -n "$pid_files" ]; then
    while IFS= read -r pid_file; do
      [ -f "$pid_file" ] || continue
      cat "$pid_file" >>"$base_file"
      rm -f "$pid_file"
    done <<<"$pid_files"
  fi

  # Find and merge all per-process tracked files lists
  pid_files=$(ls -1 "${tracked_base}."* 2>/dev/null) || true
  if [ -n "$pid_files" ]; then
    while IFS= read -r pid_file; do
      [ -f "$pid_file" ] || continue
      cat "$pid_file" >>"$tracked_base"
      rm -f "$pid_file"
    done <<<"$pid_files"
  fi

  # Find and merge all per-process test hits files
  if [ -n "$test_hits_base" ]; then
    pid_files=$(ls -1 "${test_hits_base}."* 2>/dev/null) || true
    if [ -n "$pid_files" ]; then
      while IFS= read -r pid_file; do
        [ -f "$pid_file" ] || continue
        cat "$pid_file" >>"$test_hits_base"
        rm -f "$pid_file"
      done <<<"$pid_files"
    fi
  fi

  # Deduplicate tracked files
  if [ -f "$tracked_base" ]; then
    sort -u "$tracked_base" -o "$tracked_base"
  fi
}

function bashunit::coverage::cleanup() {
  if [ -n "$_BASHUNIT_COVERAGE_DATA_FILE" ]; then
    local coverage_dir
    coverage_dir=$(dirname "$_BASHUNIT_COVERAGE_DATA_FILE")
    rm -rf "$coverage_dir"
  fi
}
