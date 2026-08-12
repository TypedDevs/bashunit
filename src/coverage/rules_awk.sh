#!/usr/bin/env bash

# The line classifier, as awk source.
#
# bashunit::coverage::is_executable_line is the reference implementation and
# stays the place the rules are decided. This is the same rules in awk, so a
# whole-file scan can classify without a Bash loop per line -- the shape
# .claude/rules/perf-fork-budget.md prescribes for file scans (#1059).
#
# The two must agree exactly, or coverage numbers move silently. That is what
# tests/unit/coverage/classifier_differential_test.sh checks, line by line,
# over every `git ls-files '*.sh'` in the repo.
#
# It lives in a shell string rather than a .awk file because the build
# flattens *.sh into one artifact (ADR-011); a separate file would not ship.

# shellcheck disable=SC2016  # the $0/$1 in here are awk's, not the shell's
_BASHUNIT_COVERAGE_AWK_RULES='
# Whether a source line counts as executable. Mirrors
# bashunit::coverage::is_executable_line, quirk for quirk.
function bu_is_executable(line,   tmp, stripped, trimmed, first, rest, fn_rest, fn_name, cp_before, cp_after, i, c) {
  # Empty means "nothing but SPACES": the reference strips spaces only, so a
  # line of tabs is not empty and goes on to the rules below.
  tmp = line
  gsub(/ /, "", tmp)
  if (tmp == "") { return 0 }

  stripped = line
  sub(/^[ \t]+/, "", stripped)
  trimmed = stripped
  sub(/[ \t]+$/, "", trimmed)

  if (substr(trimmed, 1, 1) == "#") { return 0 }
  if (trimmed == "{" || trimmed == "}" || trimmed == "\\") { return 0 }

  # The first token ends at whitespace or at a `#`, so `done#note` still reads
  # as the keyword `done`.
  first = trimmed
  sub(/[ \t].*$/, "", first)
  sub(/#.*$/, "", first)

  if (first == "then" || first == "else" || first == "fi" || first == "do" ||
      first == "done" || first == "esac" || first == "in" || first == ";;" ||
      first == ";;&" || first == ";&" || first == ")") {
    rest = substr(trimmed, length(first) + 1)
    sub(/^[ \t]+/, "", rest)
    if (rest == "" || substr(rest, 1, 1) == "#") { return 0 }
    # A loop terminator still terminates the loop when a redirection or a pipe
    # follows: `done < file`, `done | sort`.
    if (first == "done") { return 0 }
  }

  # Function declarations: `[function ]name()` with an optional trailing `{`,
  # and no trailing comment.
  if (index(trimmed, "()") > 0) {
    fn_rest = trimmed
    if (fn_rest ~ /^function[ \t]/) {
      sub(/^function/, "", fn_rest)
      sub(/^[ \t]+/, "", fn_rest)
    }
    if (substr(fn_rest, length(fn_rest), 1) == "{") {
      fn_rest = substr(fn_rest, 1, length(fn_rest) - 1)
      sub(/[ \t]+$/, "", fn_rest)
    }
    if (length(fn_rest) >= 2 && substr(fn_rest, length(fn_rest) - 1) == "()") {
      fn_name = substr(fn_rest, 1, length(fn_rest) - 2)
      sub(/[ \t]+$/, "", fn_name)
      if (fn_name ~ /^[a-zA-Z_]/) {
        # Every character after the first must be a name character; the
        # reference accepts `:` so bashunit::fn() reads as a declaration.
        for (i = 2; i <= length(fn_name); i++) {
          c = substr(fn_name, i, 1)
          if (c !~ /[a-zA-Z0-9_:]/) { return 1 }
        }
        return 0
      }
    }
  }

  # Case arms: something, then `)`, then end of line or a comment. The `)` only
  # closes an arm when no `(` opened earlier on the line, so `x=$(foo)`,
  # `((i++))` and `cmd <(sub)` stay statements (#1055).
  if (index(trimmed, ")") > 0) {
    cp_before = trimmed
    sub(/\).*$/, "", cp_before)
    if (cp_before != "" && index(cp_before, "(") == 0) {
      cp_after = substr(trimmed, length(cp_before) + 2)
      sub(/^[ \t]+/, "", cp_after)
      if (cp_after == "" || substr(cp_after, 1, 1) == "#") { return 0 }
    }
  }

  return 1
}
'

# The DA/LF/LH block of one file's LCOV record, in one pass.
#
# Reads the file's aggregated hit block first (#1057), then the source, and
# applies the same continuation propagation the Bash reader does: the DEBUG
# trap attributes a multi-line statement to its starting line, so the count
# carries forward across the backslash chain (#722).
# shellcheck disable=SC2016
_BASHUNIT_COVERAGE_AWK_LCOV='
function bu_ends_with_continuation(line,   lead, i, n) {
  lead = line
  sub(/^[ \t]+/, "", lead)
  if (substr(lead, 1, 1) == "#") { return 0 }
  n = 0
  for (i = length(line); i >= 1; i--) {
    if (substr(line, i, 1) == "\\") { n++ } else { break }
  }
  return (n % 2) == 1
}

# The guard is FILENAME, not the usual `FNR == NR`: a run with no recorded hits
# passes an EMPTY first file, and `FNR == NR` is then true for the first record
# of the SECOND file, which would swallow the source line 1.
FILENAME == hitsfile {
  # The hits block: "<lineno> <count>".
  hits[$1] = $2
  next
}

{
  total++
  src[total] = $0
}

END {
  carry = 0
  for (ln = 1; ln <= total; ln++) {
    h = (ln in hits) ? hits[ln] + 0 : 0
    if (carry > 0 && h < carry) { h = carry; hits[ln] = h }
    if (h > 0 && bu_ends_with_continuation(src[ln])) { carry = h } else { carry = 0 }
  }

  executable = 0
  hit = 0
  for (ln = 1; ln <= total; ln++) {
    if (!bu_is_executable(src[ln])) { continue }
    executable++
    h = (ln in hits) ? hits[ln] + 0 : 0
    if (h > 0) { hit++ }
    printf "DA:%s,%s\n", ln, h
  }
  printf "LF:%s\n", executable
  printf "LH:%s\n", hit
}
'

##
# The awk source of the shared classification rules.
##
function bashunit::coverage::awk_rules() {
  printf '%s' "$_BASHUNIT_COVERAGE_AWK_RULES"
}

##
# Emits the DA/LF/LH records of $1 in one awk pass.
# Arguments: $1 - source file
##
function bashunit::coverage::awk_lcov_lines() {
  local file="$1"

  bashunit::coverage::ensure_hits_aggregated
  bashunit::coverage::hits_file_for "$file"
  local hits_file="$_BASHUNIT_COVERAGE_HITS_FILE_OUT"
  if [ -z "$hits_file" ] || [ ! -f "$hits_file" ]; then
    # /dev/null keeps the two-input shape: no hits is a valid run.
    hits_file="/dev/null"
  fi

  env LC_ALL=C "$AWK" -v hitsfile="$hits_file" \
    "${_BASHUNIT_COVERAGE_AWK_RULES}${_BASHUNIT_COVERAGE_AWK_LCOV}" \
    "$hits_file" "$file"
}
