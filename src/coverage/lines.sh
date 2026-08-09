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
  # `--option)`, `*) # note`. The pattern this replaced spelled the leading
  # segment `[^\)]+`, and inside a POSIX bracket expression a backslash is a
  # literal member of the set, so a backslash anywhere before that `)`
  # suppressed the match. `x=$(foo)` is therefore classified non-executable
  # while `x=$(printf '%s\n')` is executable; both are preserved here.
  case "$line" in
  *')'*)
    local cp_before="${line%%')'*}"
    case "$cp_before" in
    '' | *[\\]*) : ;;
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

  # Extract all lines for this file, count occurrences of each line number.
  local -a counts=()
  local count lineno maxln=0
  while read -r count lineno; do
    if [ -n "$lineno" ]; then
      counts[lineno]=$count
      [ "$lineno" -gt "$maxln" ] && maxln=$lineno
    fi
  done < <(grep "^${file}:" "$_BASHUNIT_COVERAGE_DATA_FILE" 2>/dev/null |
    cut -d: -f2 | sort | uniq -c)

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

function bashunit::coverage::load_hits_by_line() {
  local file="$1"
  _BASHUNIT_COVERAGE_HITS_BY_LINE=()
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
