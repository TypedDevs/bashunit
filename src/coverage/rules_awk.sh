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

# Whether a source line ends with a line continuation: an odd number of
# trailing backslashes, and not a comment. Lives here because both the LCOV
# emitter and the stats pass propagate hits along a continuation chain (#722).
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
'

# The DA/LF/LH block of one file's LCOV record, in one pass.
#
# Reads the file's aggregated hit block first (#1057), then the source, and
# applies the same continuation propagation the Bash reader does: the DEBUG
# trap attributes a multi-line statement to its starting line, so the count
# carries forward across the backslash chain (#722).
# shellcheck disable=SC2016
_BASHUNIT_COVERAGE_AWK_LCOV='
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

# Executable and hit counts for MANY files, in one awk invocation.
#
# The report needs a count per tracked file, and computing it per file meant a
# Bash loop over every line of every file: 1956ms for 128 files, the last
# per-line Bash loop in the report phase. Reading the manifest and walking each
# pair with getline pays the cost of a fork once for the whole run (#1088).
#
# Input is a manifest of "<hits block>\t<source>" lines; output is
# "<executable>\t<hit>\t<source>". The source path comes last so a path holding
# a tab still reads back whole.
# shellcheck disable=SC2016
_BASHUNIT_COVERAGE_AWK_STATS='
{
  hitsfile = $0
  sub(/\t.*$/, "", hitsfile)
  src = $0
  sub(/^[^\t]*\t/, "", src)

  split("", hits)
  if (hitsfile != "") {
    while ((getline hline < hitsfile) > 0) {
      split(hline, hp, " ")
      hits[hp[1] + 0] = hp[2] + 0
    }
    close(hitsfile)
  }

  total = 0
  split("", sl)
  while ((getline sline < src) > 0) {
    total++
    sl[total] = sline
  }
  close(src)

  # The DEBUG trap attributes a multi-line statement to its starting line, so
  # the count carries forward across the backslash chain (#722).
  carry = 0
  for (ln = 1; ln <= total; ln++) {
    h = (ln in hits) ? hits[ln] : 0
    if (carry > 0 && h < carry) { h = carry; hits[ln] = h }
    if (h > 0 && bu_ends_with_continuation(sl[ln])) { carry = h } else { carry = 0 }
  }

  executable = 0
  hit = 0
  for (ln = 1; ln <= total; ln++) {
    if (!bu_is_executable(sl[ln])) { continue }
    executable++
    if ((ln in hits) && hits[ln] > 0) { hit++ }
  }

  print executable "\t" hit "\t" src
}
'

# The whole LCOV report, in one awk invocation.
#
# report_lcov used to run three awk forks and two Bash loops per tracked file:
# 3133ms for 128 files, of which the awk work itself was a rounding error. This
# reads the same manifest as the stats pass and emits every record a file needs
# from a single walk that already holds the source lines and the propagated hit
# counts: 262ms, byte-identical output (#1090).
#
# Composed with the classifier rules, the declaration scanner and the branch
# scanner, all of which are included ahead of it.
# shellcheck disable=SC2016
_BASHUNIT_COVERAGE_AWK_LCOV_ALL='
# An arm ran as often as its FIRST executable line did (#1061).
function bu_arm_taken(s, e,   ln) {
  for (ln = s; ln <= e; ln++) {
    if (!bu_is_executable(sl[ln])) { continue }
    return (ln in hits) ? hits[ln] : 0
  }
  return 0
}

BEGIN { print "TN:" }

{
  hitsfile = $0
  sub(/\t.*$/, "", hitsfile)
  src = $0
  sub(/^[^\t]*\t/, "", src)

  split("", hits)
  if (hitsfile != "") {
    while ((getline hline < hitsfile) > 0) {
      split(hline, hp, " ")
      hits[hp[1] + 0] = hp[2] + 0
    }
    close(hitsfile)
  }

  total = 0
  split("", sl)
  while ((getline sline < src) > 0) {
    total++
    sl[total] = sline
  }
  close(src)

  # The DEBUG trap attributes a multi-line statement to its starting line, so
  # the count carries forward across the backslash chain (#722).
  carry = 0
  for (ln = 1; ln <= total; ln++) {
    h = (ln in hits) ? hits[ln] : 0
    if (carry > 0 && h < carry) { h = carry; hits[ln] = h }
    if (h > 0 && bu_ends_with_continuation(sl[ln])) { carry = h } else { carry = 0 }
  }

  bu_fn_reset()
  bu_br_reset()
  for (ln = 1; ln <= total; ln++) {
    bu_fn_line(sl[ln], ln)
    bu_br_line(sl[ln], ln)
  }
  bu_fn_finish(total)

  print "SF:" src

  # FN lines as we walk, the matching FNDA lines after them, per LCOV
  # convention.
  fn_hit = 0
  fnda = ""
  for (i = 1; i <= fn_count; i++) {
    print "FN:" fns[i] "," fnn[i]
    any = 0
    for (ln = fns[i]; ln <= fne[i]; ln++) {
      if ((ln in hits) && hits[ln] > 0) { any = 1; break }
    }
    fnda = fnda "FNDA:" any "," fnn[i] "\n"
    if (any == 1) { fn_hit++ }
  }
  printf "%s", fnda
  print "FNF:" fn_count
  print "FNH:" fn_hit

  br_total = 0
  br_hit = 0
  for (i = 1; i <= br_count; i++) {
    n = split(br_arms[i], arms, ",")
    for (a = 1; a <= n; a++) {
      split(arms[a], se, ":")
      taken = bu_arm_taken(se[1] + 0, se[2] + 0)
      print "BRDA:" br_dec[i] "," (i - 1) "," (a - 1) "," taken
      br_total++
      if (taken > 0) { br_hit++ }
    }
  }
  print "BRF:" br_total
  print "BRH:" br_hit

  executable = 0
  hit = 0
  for (ln = 1; ln <= total; ln++) {
    if (!bu_is_executable(sl[ln])) { continue }
    executable++
    h = (ln in hits) ? hits[ln] : 0
    if (h > 0) { hit++ }
    print "DA:" ln "," h
  }
  print "LF:" executable
  print "LH:" hit
  print "end_of_record"
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

##
# Emits "<executable>\t<hit>\t<source>" for every pair in the manifest, in one
# awk invocation.
# Arguments: $1 - manifest of "<hits block>\t<source>" lines
##
function bashunit::coverage::awk_file_stats() {
  env LC_ALL=C "$AWK" \
    "${_BASHUNIT_COVERAGE_AWK_RULES}${_BASHUNIT_COVERAGE_AWK_STATS}" \
    "$1"
}

##
# Emits the whole LCOV report for every pair in the manifest, in one awk
# invocation.
# Arguments: $1 - manifest of "<hits block>\t<source>" lines
##
function bashunit::coverage::awk_lcov_report() {
  env LC_ALL=C "$AWK" \
    "${_BASHUNIT_COVERAGE_AWK_RULES}${_BASHUNIT_COVERAGE_AWK_FUNCTIONS}\
${_BASHUNIT_COVERAGE_AWK_BRANCHES}${_BASHUNIT_COVERAGE_AWK_LCOV_ALL}" \
    "$1"
}
