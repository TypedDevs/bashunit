#!/usr/bin/env bash

# Branch coverage extraction and hit computation. See adrs/adr-007-branch-coverage-mvp.md.


# Append "start:end" to a comma-separated arms string. Result is
# returned via the global _BASHUNIT_BRANCH_ARMS_OUT to avoid the cost
# of a subshell on a hot per-line path. Bash 3.0 cannot pass arrays
# (or namerefs) by reference, so a single output slot is the cheapest
# portable option.
_BASHUNIT_BRANCH_ARMS_OUT=""

function bashunit::coverage::_append_arm() {
  local existing="$1" arm_start="$2" arm_end="$3"
  if [ -z "$existing" ]; then
    _BASHUNIT_BRANCH_ARMS_OUT="${arm_start}:${arm_end}"
  else
    _BASHUNIT_BRANCH_ARMS_OUT="${existing},${arm_start}:${arm_end}"
  fi
}

# Detect whether a trimmed line is a case-pattern opener (ends with
# `)` optionally followed by whitespace and a comment). Avoids
# matching mid-line uses such as `cmd $(other)`.
function bashunit::coverage::_is_case_pattern_line() {
  local trimmed="$1"
  case "$trimmed" in
  *')'*) ;;
  *) return 1 ;;
  esac

  local before_paren="${trimmed%%')'*}"
  local after="${trimmed#"$before_paren"}"
  after="${after#)}"
  after="${after#"${after%%[![:space:]]*}"}"
  case "$after" in
  '' | '#'*) return 0 ;;
  esac
  return 1
}


# Extract branch points from a Bash file.
# Output format: <decision_line>|<kind>|<arm_start>:<arm_end>[,<arm_start>:<arm_end>]...
# kind ∈ {if, case, loop}
# Scope: if/elif/else chains, case patterns and loop bodies.
# See adrs/adr-007-branch-coverage-mvp.md.
# The handlers below operate on the per-construct state arrays that
# extract_branches keeps as locals. Bash 3.0 has dynamic scoping for
# `local` vars, so the helpers see and mutate the caller's state
# without needing namerefs (which would require Bash 4.3+).


function bashunit::coverage::_branch_push_if() {
  local lineno=$1
  if_decision_line[if_depth]=$lineno
  if_arms[if_depth]=""
  if_arm_start[if_depth]=$((lineno + 1))
  if_depth=$((if_depth + 1))
}

function bashunit::coverage::_branch_close_if_arm() {
  local lineno=$1 idx=$((if_depth - 1))
  bashunit::coverage::_append_arm \
    "${if_arms[$idx]}" "${if_arm_start[$idx]}" "$((lineno - 1))"
  if_arms[idx]="$_BASHUNIT_BRANCH_ARMS_OUT"
  if_arm_start[idx]=$((lineno + 1))
}

function bashunit::coverage::_branch_emit_if() {
  local lineno=$1 idx=$((if_depth - 1))
  bashunit::coverage::_append_arm \
    "${if_arms[$idx]}" "${if_arm_start[$idx]}" "$((lineno - 1))"
  echo "${if_decision_line[$idx]}|if|${_BASHUNIT_BRANCH_ARMS_OUT}"
  if_depth=$idx
}

function bashunit::coverage::_branch_push_case() {
  local lineno=$1
  case_decision_line[case_depth]=$lineno
  case_arms[case_depth]=""
  case_arm_start[case_depth]=0
  case_in_pattern[case_depth]=0
  case_depth=$((case_depth + 1))
}

function bashunit::coverage::_branch_close_case_arm() {
  local lineno=$1 idx=$((case_depth - 1))
  [ "${case_in_pattern[$idx]}" = "1" ] || return 0
  bashunit::coverage::_append_arm \
    "${case_arms[$idx]}" "${case_arm_start[$idx]}" "$((lineno - 1))"
  case_arms[idx]="$_BASHUNIT_BRANCH_ARMS_OUT"
  case_in_pattern[idx]=0
}

function bashunit::coverage::_branch_emit_case() {
  local lineno=$1 idx=$((case_depth - 1))
  bashunit::coverage::_branch_close_case_arm "$lineno"
  if [ -n "${case_arms[$idx]}" ]; then
    echo "${case_decision_line[$idx]}|case|${case_arms[$idx]}"
  fi
  case_depth=$idx
}

function bashunit::coverage::_branch_open_case_pattern() {
  local lineno=$1 idx=$((case_depth - 1))
  case_arm_start[idx]=$((lineno + 1))
  case_in_pattern[idx]=1
}

# A loop (while/until/for/select) is a single-arm branch: its body. The arm is
# taken iff the loop ran at least once (an executable body line was hit); a
# never-taken body is an uncovered zero-iteration branch. Every `done`-closed
# construct must push so `done` pairs with the right opener when nested.
function bashunit::coverage::_branch_push_loop() {
  local lineno=$1
  loop_decision_line[loop_depth]=$lineno
  loop_arm_start[loop_depth]=$((lineno + 1))
  loop_depth=$((loop_depth + 1))
}

function bashunit::coverage::_branch_emit_loop() {
  local lineno=$1 idx=$((loop_depth - 1))
  echo "${loop_decision_line[$idx]}|loop|${loop_arm_start[$idx]}:$((lineno - 1))"
  loop_depth=$idx
}

# The branch extractor, as awk source.
#
# Same rules as extract_branches below, which stays the reference: the two are
# diffed line by line over every shell file in the repo by
# tests/unit/coverage/branches_differential_test.sh. This one exists so the
# whole LCOV report can be emitted in one awk invocation (#1090); the Bash one
# still serves the per-file API and the fallback path.
#
# Records land in br_dec/br_kind/br_arms rather than being printed, so the
# caller decides what to do with them.
# shellcheck disable=SC2016
_BASHUNIT_COVERAGE_AWK_BRANCHES='
function bu_br_append_arm(existing, s, e) {
  return (existing == "") ? (s ":" e) : (existing "," s ":" e)
}

# A case-pattern opener ends with `)`, optionally followed by a comment. This
# does not exclude a `(` earlier on the line -- the reference does not either.
function bu_br_is_case_pattern(t,   before, after) {
  if (index(t, ")") == 0) { return 0 }
  before = t
  sub(/\).*$/, "", before)
  after = substr(t, length(before) + 2)
  sub(/^[ \t]+/, "", after)
  return (after == "" || substr(after, 1, 1) == "#")
}

function bu_br_add(decision, kind, arms) {
  br_count++
  br_dec[br_count] = decision
  br_kind[br_count] = kind
  br_arms[br_count] = arms
}

function bu_br_line(line, lineno,   trimmed, first, idx) {
  trimmed = line
  sub(/^[ \t]+/, "", trimmed)
  if (trimmed == "" || substr(trimmed, 1, 1) == "#") { return }

  first = trimmed
  sub(/[ \t;].*$/, "", first)

  if (first == "if") {
    if_decision_line[if_depth] = lineno
    if_arms[if_depth] = ""
    if_arm_start[if_depth] = lineno + 1
    if_depth++
  } else if (first == "elif" || first == "else") {
    if (if_depth > 0) {
      idx = if_depth - 1
      if_arms[idx] = bu_br_append_arm(if_arms[idx], if_arm_start[idx], lineno - 1)
      if_arm_start[idx] = lineno + 1
    }
  } else if (first == "fi") {
    if (if_depth > 0) {
      idx = if_depth - 1
      bu_br_add(if_decision_line[idx], "if", bu_br_append_arm(if_arms[idx], if_arm_start[idx], lineno - 1))
      if_depth = idx
    }
  } else if (first == "case") {
    case_decision_line[case_depth] = lineno
    case_arms[case_depth] = ""
    case_arm_start[case_depth] = 0
    case_in_pattern[case_depth] = 0
    case_depth++
  } else if (first == "esac") {
    if (case_depth > 0) {
      idx = case_depth - 1
      if (case_in_pattern[idx] == 1) {
        case_arms[idx] = bu_br_append_arm(case_arms[idx], case_arm_start[idx], lineno - 1)
        case_in_pattern[idx] = 0
      }
      if (case_arms[idx] != "") { bu_br_add(case_decision_line[idx], "case", case_arms[idx]) }
      case_depth = idx
    }
  } else if (first == "while" || first == "until" || first == "for" || first == "select") {
    loop_decision_line[loop_depth] = lineno
    loop_arm_start[loop_depth] = lineno + 1
    loop_depth++
  } else if (first == "done") {
    if (loop_depth > 0) {
      idx = loop_depth - 1
      bu_br_add(loop_decision_line[idx], "loop", loop_arm_start[idx] ":" (lineno - 1))
      loop_depth = idx
    }
  } else if (case_depth > 0) {
    idx = case_depth - 1
    if (trimmed ~ /^;;&/ || trimmed ~ /^;;/ || trimmed ~ /^;&/) {
      if (case_in_pattern[idx] == 1) {
        case_arms[idx] = bu_br_append_arm(case_arms[idx], case_arm_start[idx], lineno - 1)
        case_in_pattern[idx] = 0
      }
    } else if (bu_br_is_case_pattern(trimmed)) {
      case_arm_start[idx] = lineno + 1
      case_in_pattern[idx] = 1
    }
  }
}

# The depths must be numeric before they index anything: an uninitialised awk
# variable is the empty string as a subscript, so the first push would land in
# arr[""] and the matching pop would read arr[0].
function bu_br_reset() {
  if_depth = 0
  case_depth = 0
  loop_depth = 0
  br_count = 0
}
'

function bashunit::coverage::extract_branches() {
  local file="$1"

  local -a lines=()
  local _i=0 _l
  while IFS= read -r _l || [ -n "$_l" ]; do
    lines[_i]="$_l"
    ((++_i))
  done <"$file"
  local total_lines=$_i

  # State arrays — read and mutated by the _branch_* helpers via Bash's
  # dynamic scoping. Each array is keyed by depth so nested constructs
  # work without associative arrays.
  local -a if_decision_line=() if_arms=() if_arm_start=()
  local if_depth=0
  local -a case_decision_line=() case_arms=() case_arm_start=() case_in_pattern=()
  local case_depth=0
  local -a loop_decision_line=() loop_arm_start=()
  local loop_depth=0

  local lineno=0 line trimmed first
  while [ "$lineno" -lt "$total_lines" ]; do
    line="${lines[$lineno]}"
    lineno=$((lineno + 1))

    trimmed="${line#"${line%%[![:space:]]*}"}"
    case "$trimmed" in '' | '#'*) continue ;; esac
    first="${trimmed%%[[:space:]\;]*}"

    # Reserved-word patterns single-quoted to dodge `case ... esac`
    # parser confusion.
    case "$first" in
    'if') bashunit::coverage::_branch_push_if "$lineno" ;;
    'elif' | 'else')
      [ "$if_depth" -gt 0 ] && bashunit::coverage::_branch_close_if_arm "$lineno"
      ;;
    'fi')
      [ "$if_depth" -gt 0 ] && bashunit::coverage::_branch_emit_if "$lineno"
      ;;
    'case') bashunit::coverage::_branch_push_case "$lineno" ;;
    'esac')
      [ "$case_depth" -gt 0 ] && bashunit::coverage::_branch_emit_case "$lineno"
      ;;
    'while' | 'until' | 'for' | 'select')
      bashunit::coverage::_branch_push_loop "$lineno"
      ;;
    'done')
      [ "$loop_depth" -gt 0 ] && bashunit::coverage::_branch_emit_loop "$lineno"
      ;;
    *)
      [ "$case_depth" -eq 0 ] && continue
      case "$trimmed" in
      ';;&'* | ';;'* | ';&'*)
        bashunit::coverage::_branch_close_case_arm "$lineno"
        ;;
      *)
        if bashunit::coverage::_is_case_pattern_line "$trimmed"; then
          bashunit::coverage::_branch_open_case_pattern "$lineno"
        fi
        ;;
      esac
      ;;
    esac
  done
}


# Sets _BASHUNIT_ARM_TAKEN_OUT to how many times the arm [arm_start..arm_end]
# ran, or 0 when it never did.
#
# The count is the FIRST executable line's, not the maximum across the arm.
# Entering an arm executes its first line exactly once per entry, while a later
# line can run more often (a loop) or fewer times (an early return), so the
# first line is the one that answers "how often was this branch taken" (#1061).
#
# Reads hit counts from the shared _BASHUNIT_COVERAGE_HITS_BY_LINE global (see
# load_hits_by_line); the caller must have populated the src_lines array in
# scope -- Bash 3.0 cannot pass arrays into a function. Result is returned via
# the global to avoid a per-arm subshell.
_BASHUNIT_ARM_TAKEN_OUT=0

function bashunit::coverage::_arm_taken() {
  local arm_start="$1" arm_end="$2" ln
  for ((ln = arm_start; ln <= arm_end; ln++)); do
    bashunit::coverage::is_executable_line \
      "${src_lines[$((ln - 1))]:-}" "$ln" || continue
    _BASHUNIT_ARM_TAKEN_OUT="${_BASHUNIT_COVERAGE_HITS_BY_LINE[$ln]:-0}"
    return
  done
  _BASHUNIT_ARM_TAKEN_OUT=0
}

# Compute branch hit data for a file.
# Output format: <decision_line>|<block>|<branch_index>|<taken_count>
# block = sequential id per decision (0..N-1), branch_index = arm index (0..M-1).
# taken_count is the execution count of the arm's first executable line, which
# is what an LCOV consumer reads out of the BRDA fourth field.
# An arm is "taken" iff at least one executable line inside its range
# has a recorded hit. taken_count is 0 or 1 — MVP does not preserve
# per-arm hit counts.
function bashunit::coverage::compute_branch_hits() {
  local file="$1"

  # A no-op when the caller (report_lcov) already loaded this file: the loader
  # remembers which file its array holds.
  bashunit::coverage::load_hits_by_line "$file"

  local -a src_lines=()
  local _sli=0 _sl
  while IFS= read -r _sl || [ -n "$_sl" ]; do
    src_lines[_sli]="$_sl"
    ((++_sli))
  done <"$file"

  local block=0 decision_line _kind arms branch_entry
  local -a arm_specs=()
  local arm arm_index
  while IFS= read -r branch_entry; do
    [ -z "$branch_entry" ] && continue
    IFS='|' read -r decision_line _kind arms <<<"$branch_entry"

    arm_index=0
    IFS=',' read -ra arm_specs <<<"$arms"
    for arm in "${arm_specs[@]}"; do
      bashunit::coverage::_arm_taken "${arm%%:*}" "${arm##*:}"
      echo "${decision_line}|${block}|${arm_index}|${_BASHUNIT_ARM_TAKEN_OUT}"
      arm_index=$((arm_index + 1))
    done

    block=$((block + 1))
  done < <(bashunit::coverage::extract_branches "$file")
}
