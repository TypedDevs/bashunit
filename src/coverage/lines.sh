#!/usr/bin/env bash

# Static line classification and reading recorded hit data.


# Check if a line is executable (used by get_executable_lines and report_lcov)
#
# Every tracked line is classified twice per run (once by precompute_file_stats,
# once by report_lcov), so this is the report phase's hottest path and stays
# fork-free. It used to fall back to one `grep -E` per unclassified line against
# a combined regex; 286 source lines cost 1055 grep forks and roughly half of a
# `--coverage` run's wall time (#1005). The pure-Bash rules below reproduce that
# regex exactly, quirks included — see the comments on the individual cases.
#
# Non-executable lines are: comments and the shebang, brace-only lines, a bare
# line continuation, control-flow keywords, loop terminators with a redirection
# or pipe, function declarations, and case patterns.
#
# Arguments: line content, line number
# Returns: 0 if executable, 1 if not
function bashunit::coverage::is_executable_line() {
  local line="$1"
  local lineno="$2"

  # Unused but kept for API compatibility
  : "$lineno"

  # Skip empty lines (line with only whitespace) — built-in, no subshell
  [ -z "${line// /}" ] && return 1

  # Fast path: pure Bash checks for common non-executable patterns (no subshell)
  local stripped="${line#"${line%%[![:space:]]*}"}"
  local _trail="${stripped##*[![:space:]]}"
  local trimmed="${stripped%"$_trail"}"

  case "$trimmed" in
  '#'*) return 1 ;;             # Comments (including shebang)
  '{' | '}' | [\\]) return 1 ;; # Braces only, or a bare line continuation
  esac

  # A keyword may butt straight up against a trailing comment (`done#note`),
  # so end the token at a `#` as well as at whitespace.
  local first="${trimmed%%[[:space:]]*}"
  first="${first%%'#'*}"
  case "$first" in
  'then' | 'else' | 'fi' | 'do' | 'done' | 'esac' | 'in' | ';;' | ';;&' | ';&' | ')')
    local rest="${trimmed#"$first"}"
    local _rl="${rest%%[![:space:]]*}"
    rest="${rest#"$_rl"}"
    case "$rest" in '' | '#'*) return 1 ;; esac
    # A loop terminator still terminates a loop when a redirection or a pipe
    # follows it: `done < file`, `done | sort`. Reaching here means `done` was
    # followed by whitespace and something that is not a comment.
    if [ "$first" = 'done' ]; then
      return 1
    fi
    ;;
  esac

  # Function declarations: `[function ]name()` with an optional trailing `{`.
  # No trailing comment is allowed, matching the pattern this replaced.
  case "$trimmed" in
  *'()'*)
    local fn_rest="$trimmed"
    case "$fn_rest" in
    'function'[[:space:]]*)
      fn_rest="${fn_rest#function}"
      fn_rest="${fn_rest#"${fn_rest%%[![:space:]]*}"}"
      ;;
    esac
    case "$fn_rest" in
    *'{')
      fn_rest="${fn_rest%'{'}"
      fn_rest="${fn_rest%"${fn_rest##*[![:space:]]}"}"
      ;;
    esac
    case "$fn_rest" in
    *'()')
      local fn_name="${fn_rest%'()'}"
      fn_name="${fn_name%"${fn_name##*[![:space:]]}"}"
      case "$fn_name" in
      [a-zA-Z_]*)
        case "${fn_name#?}" in
        *[!a-zA-Z0-9_:]*) : ;;
        *) return 1 ;;
        esac
        ;;
      esac
      ;;
    esac
    ;;
  esac

  # Case patterns: something, then `)`, then end of line or a comment —
  # `--option)`, `*) # note`. A case arm is a decision, and the decision is
  # already accounted for by branch coverage, so an arm line counts as
  # non-executable.
  #
  # The `)` has to actually close an arm. Any `(` earlier on the line means it
  # closes that instead -- `x=$(foo)`, `((i++))`, `cmd <(sub)` -- and those are
  # statements. The rule this replaced asked a different question: its leading
  # segment was spelled `[^\)]+`, and inside a POSIX bracket expression a
  # backslash is a literal member of the set, so a backslash anywhere before
  # the `)` suppressed the match. That made `x=$(foo)` non-executable while
  # `x=$(printf '%s\n')` was executable, and dropped 236 real statements of
  # this repo's own src/ out of every denominator (#1055).
  case "$line" in
  *')'*)
    local cp_before="${line%%')'*}"
    case "$cp_before" in
    '' | *'('*) : ;;
    *)
      local cp_after="${line#*')'}"
      cp_after="${cp_after#"${cp_after%%[![:space:]]*}"}"
      case "$cp_after" in '' | '#'*) return 1 ;; esac
      ;;
    esac
    ;;
  esac

  return 0
}

function bashunit::coverage::get_executable_lines() {
  local file="$1"
  local count=0
  local lineno=0
  local line

  while IFS= read -r line || [ -n "$line" ]; do
    ((++lineno))
    bashunit::coverage::is_executable_line "$line" "$lineno" && ((++count))
  done <"$file"

  echo "$count"
}

function bashunit::coverage::get_hit_lines() {
  local file="$1"

  if [ ! -f "$_BASHUNIT_COVERAGE_DATA_FILE" ]; then
    echo "0"
    return
  fi

  # Get unique hit line numbers
  local hit_lines
  hit_lines=$( (grep "^${file}:" "$_BASHUNIT_COVERAGE_DATA_FILE" 2>/dev/null || true) |
    cut -d: -f2 | sort -u)

  if [ -z "$hit_lines" ]; then
    echo "0"
    return
  fi

  # Only count hits that correspond to executable lines
  # This prevents >100% coverage when DEBUG trap fires on non-executable lines

  # Pre-load file lines into indexed array (avoids sed per line)
  local -a file_lines=()
  local _idx=0 _fl
  while IFS= read -r _fl || [ -n "$_fl" ]; do
    file_lines[_idx]="$_fl"
    ((++_idx))
  done <"$file"

  local count=0
  local line_num
  for line_num in $hit_lines; do
    local line_content="${file_lines[$((line_num - 1))]:-}"
    [ -z "$line_content" ] && continue
    if bashunit::coverage::is_executable_line "$line_content" "$line_num"; then
      ((++count))
    fi
  done

  echo "$count"
}

# Compute executable + hit counts for a file in a single source-file pass.
# Reuses get_all_line_hits to avoid scanning the coverage data per line.
# Output format: "executable:hit"
function bashunit::coverage::compute_file_coverage() {
  local file="$1"

  bashunit::coverage::load_hits_by_line "$file"

  local executable=0 hit=0 lineno=0 line line_hits
  local -a cv_lines=()
  local _cli=0 _cl
  while IFS= read -r _cl || [ -n "$_cl" ]; do
    cv_lines[_cli]="$_cl"
    ((++_cli))
  done <"$file"

  for line in "${cv_lines[@]}"; do
    ((++lineno))
    bashunit::coverage::is_executable_line "$line" "$lineno" || continue
    ((++executable))
    line_hits=${_BASHUNIT_COVERAGE_HITS_BY_LINE[lineno]:-0}
    [ "$line_hits" -gt 0 ] && ((++hit))
  done

  echo "${executable}:${hit}"
}

# Detect whether a source line ends with a Bash line-continuation, i.e. an
# odd number of unescaped trailing backslashes with no trailing whitespace.
# Comment lines never continue. Used to propagate coverage hits from a
# statement's starting line to its continuation lines (see #722).
function bashunit::coverage::_ends_with_continuation() {
  local line="$1"
  local lead="${line#"${line%%[![:space:]]*}"}"
  case "$lead" in '#'*) return 1 ;; esac
  local trailing="${line##*[!\\]}"
  case "$line" in *[!\\]*) : ;; *) trailing="$line" ;; esac
  [ $((${#trailing} % 2)) -eq 1 ]
}

# Get all line hits for a file in one pass (performance optimization)
# Output format: one "lineno:count" per line

# The one-pass hit aggregation, and where each file's block lives.
#
# The capture path writes one record per execution event ("<file>:<line>"), so
# counting used to mean scanning the whole data file per tracked file. One awk
# pass now groups every record by file and line and writes a small block per
# file, which the report reads directly: the data file is read once per run
# instead of once per file.
_BASHUNIT_COVERAGE_HITS_AGGREGATED=false
_BASHUNIT_COVERAGE_HITS_FILE_OUT=""

##
# The path of the aggregated block for a source file, into
# _BASHUNIT_COVERAGE_HITS_FILE_OUT (empty when coverage has no data dir).
#
# The name is the source path with everything but [a-zA-Z0-9] collapsed, the
# same rule the lookup keys use; two sources can therefore share a block name,
# so each block records the path it belongs to on its first line.
# Arguments: $1 - source file
##
function bashunit::coverage::hits_file_for() {
  _BASHUNIT_COVERAGE_HITS_FILE_OUT=""
  [ -n "${_BASHUNIT_COVERAGE_DATA_FILE:-}" ] || return 0

  local dir="${_BASHUNIT_COVERAGE_DATA_FILE%/*}/hits"
  local name="${1//[^a-zA-Z0-9]/_}"
  _BASHUNIT_COVERAGE_HITS_FILE_OUT="$dir/$name"
}

##
# Invalidates the aggregation. Called wherever the data file grows, so a report
# never reads counts that predate the records it is reporting on.
##
function bashunit::coverage::invalidate_hits_aggregation() {
  _BASHUNIT_COVERAGE_HITS_AGGREGATED=false
  # The loaded array came from the old aggregation, so it is stale too.
  _BASHUNIT_COVERAGE_HITS_BY_LINE_FILE=""
}

##
# Groups the coverage data file by file and line, once per run.
##
function bashunit::coverage::ensure_hits_aggregated() {
  if [ "$_BASHUNIT_COVERAGE_HITS_AGGREGATED" = true ]; then
    return 0
  fi
  _BASHUNIT_COVERAGE_HITS_AGGREGATED=true

  [ -n "${_BASHUNIT_COVERAGE_DATA_FILE:-}" ] || return 0
  [ -f "$_BASHUNIT_COVERAGE_DATA_FILE" ] || return 0

  local dir="${_BASHUNIT_COVERAGE_DATA_FILE%/*}/hits"
  rm -rf "$dir" 2>/dev/null || true
  mkdir -p "$dir" 2>/dev/null || return 0

  # The record is "<path>:<line>", and a path may itself contain a colon, so the
  # split is on the LAST one. Each block is written sorted by line number, which
  # is the order the reader wants and awk can produce here because the counts
  # are only known at END.
  env LC_ALL=C awk -v dir="$dir" '
    {
      i = length($0)
      while (i > 0 && substr($0, i, 1) != ":") { i-- }
      if (i == 0) { next }
      path = substr($0, 1, i - 1)
      line = substr($0, i + 1)
      if (line !~ /^[0-9]+$/) { next }
      key = path SUBSEP line
      if (!(key in counts)) { order[++n] = key }
      counts[key]++
    }
    END {
      for (j = 1; j <= n; j++) {
        split(order[j], parts, SUBSEP)
        name = parts[1]
        gsub(/[^a-zA-Z0-9]/, "_", name)
        print parts[2], counts[order[j]] > (dir "/" name)
      }
      for (j = 1; j <= n; j++) {
        split(order[j], parts, SUBSEP)
        name = parts[1]
        gsub(/[^a-zA-Z0-9]/, "_", name)
        close(dir "/" name)
      }
    }
  ' "$_BASHUNIT_COVERAGE_DATA_FILE" 2>/dev/null || true
}

#
# Bash's DEBUG trap attributes a multi-line statement's execution to the line
# where the statement starts; backslash continuation lines never receive their
# own hit. To match the report's expectation that continuation lines are
# covered, the start line's count is propagated forward across the
# continuation chain (see #722).
function bashunit::coverage::get_all_line_hits() {
  local file="$1"

  if [ ! -f "$_BASHUNIT_COVERAGE_DATA_FILE" ]; then
    return
  fi

  # Read this file's counts out of the per-file block the aggregation wrote.
  # This used to be `grep | cut | sort | uniq -c` over the WHOLE data file, run
  # once per tracked file: 4 forks and a full scan each, so 484 forks and 121
  # scans at 121 files (#1057). The aggregation is one awk pass for the run,
  # triggered by load_hits_by_line in the parent shell; a direct caller of this
  # function (a unit test) gets it here instead.
  bashunit::coverage::ensure_hits_aggregated

  local -a counts=()
  local count lineno maxln=0
  local hits_file
  bashunit::coverage::hits_file_for "$file"
  hits_file=$_BASHUNIT_COVERAGE_HITS_FILE_OUT

  if [ -n "$hits_file" ] && [ -f "$hits_file" ]; then
    while read -r lineno count; do
      if [ -n "$count" ]; then
        counts[lineno]=$count
        [ "$lineno" -gt "$maxln" ] && maxln=$lineno
      fi
    done <"$hits_file"
  fi

  if [ "$maxln" -eq 0 ]; then
    return
  fi

  # Read the source so continuation lines can be detected.
  local -a src=()
  local _i=0 _l
  while IFS= read -r _l || [ -n "$_l" ]; do
    src[_i]="$_l"
    ((++_i))
  done <"$file"

  local total=$_i
  [ "$maxln" -gt "$total" ] && total=$maxln

  # Propagate each start line's count forward across its continuation chain.
  local carry=0 idx h
  for ((idx = 1; idx <= total; idx++)); do
    h=${counts[idx]:-0}
    if [ "$carry" -gt 0 ] && [ "$h" -lt "$carry" ]; then
      h=$carry
      counts[idx]=$h
    fi
    if [ "$h" -gt 0 ] && bashunit::coverage::_ends_with_continuation "${src[idx - 1]:-}"; then
      carry=$h
    else
      carry=0
    fi
  done

  local ln
  for ((ln = 1; ln <= total; ln++)); do
    [ "${counts[ln]:-0}" -gt 0 ] && echo "${ln}:${counts[ln]}"
  done

  # The for loop's exit status leaks the last `[ -gt ]` test, which is 1 when the
  # final line has no hits; return 0 explicitly so callers under `set -e` (strict
  # mode) don't treat a successful run as a failure (see #722).
  return 0
}


# Populates the shared _BASHUNIT_COVERAGE_HITS_BY_LINE array (sparse, keyed by
# line number -> hit count) from get_all_line_hits for $1.
#
# Seven call sites used to repeat this "while IFS=: read ... done < <(get_all_line_hits)"
# parse loop into their own `local -a hits_by_line`. Bash 3.0 cannot return an
# array from a function or pass one by reference, and copying a sparse array
# with `local -a x=("${src[@]}")` silently renumbers it from 0, which would
# corrupt the line-number keys -- so this loader writes one shared global
# instead (return-slot pattern, see bash-style.md). Callers must consume the
# result before the next call; there is no adjacent-call isolation.
declare -a _BASHUNIT_COVERAGE_HITS_BY_LINE
# Which file the array currently holds. report_lcov loads a file and then calls
# compute_branch_hits, which used to load the same file again and clobber it;
# every other report section reloaded it too. Remembering the file makes the
# repeat a no-op instead of a second pass (#1057).
_BASHUNIT_COVERAGE_HITS_BY_LINE_FILE=""

function bashunit::coverage::load_hits_by_line() {
  local file="$1"

  if [ -n "$file" ] && [ "$file" = "$_BASHUNIT_COVERAGE_HITS_BY_LINE_FILE" ]; then
    return 0
  fi

  # Here, not inside get_all_line_hits: that runs in the process substitution
  # below, and a flag set in a subshell dies with it -- the aggregation would
  # run again for every file, which is slower than the scan it replaced.
  bashunit::coverage::ensure_hits_aggregated

  _BASHUNIT_COVERAGE_HITS_BY_LINE=()
  _BASHUNIT_COVERAGE_HITS_BY_LINE_FILE="$file"
  local hl_lineno hl_count
  while IFS=: read -r hl_lineno hl_count; do
    [ -n "$hl_lineno" ] && _BASHUNIT_COVERAGE_HITS_BY_LINE[hl_lineno]=$hl_count
  done < <(bashunit::coverage::get_all_line_hits "$file")
}

# Get all test hits for a file in one pass (performance optimization)
# Output format: lineno|test_file:test_function (may have duplicates, one per hit)
function bashunit::coverage::get_all_line_tests() {
  local file="$1"

  if [ ! -f "${_BASHUNIT_COVERAGE_TEST_HITS_FILE:-}" ]; then
    return
  fi

  # Format in file: source_file:line|test_file:test_function
  # Output: lineno|test_file:test_function
  grep "^${file}:" "$_BASHUNIT_COVERAGE_TEST_HITS_FILE" 2>/dev/null |
    sed "s|^${file}:||" | sort -u
}
