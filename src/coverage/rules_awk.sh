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

# The multi-line statement scanner, as awk. Mirrors
# bashunit::coverage::scan_reset / scan_line / scan_is_open, which is the
# reference and carries the full explanation of the state machine (#1338).
#
# _bu_st[1.._bu_sp] is the context stack, innermost last: S single-quoted,
# D double-quoted, A array literal, C command/process substitution,
# R arithmetic paren, P other paren, H case command header,
# K case expecting a pattern, B case arm body.
# The quote character itself has to be built with sprintf: this program lives
# in a shell single-quoted string and so cannot contain one.
function bu_scan_reset() {
  _bu_sp = 0
  _bu_hd = ""
  _bu_hdtab = 0
  _bu_cont = 0
  _bu_command_start = 1
  _bu_sq = sprintf("%c", 39)
  _bu_special = "[" _bu_sq "\"\\\\#()<;&|]"
  split("", _bu_st)
  split("", _bu_cont_depth)
}

# Records the delimiter of a heredoc from the text following `<<`. The quoting
# of a delimiter only decides whether the body expands, so it is stripped.
function bu_scan_heredoc(rest,   word) {
  _bu_hdtab = 0
  if (substr(rest, 1, 1) == "-") { _bu_hdtab = 1; rest = substr(rest, 2) }
  sub(/^[ \t]+/, "", rest)
  word = rest
  sub(/[ \t;&|<>)].*$/, "", word)
  gsub(/\\/, "", word)
  gsub(/"/, "", word)
  gsub(_bu_sq, "", word)
  _bu_hd = word
}

function bu_scan_pop_case() {
  if (_bu_sp > 0 && (_bu_st[_bu_sp] == "K" || _bu_st[_bu_sp] == "B")) {
    delete _bu_st[_bu_sp--]
  }
}

# Consumes ordinary unquoted words only while the shell expects a command.
# Separators are handled by bu_scan_line, so compact and nested case commands
# reach this function in source order without treating quoted text as syntax.
function bu_scan_words(text,   token, top) {
  while (_bu_command_start && text != "") {
    sub(/^[ \t]+/, "", text)
    if (text == "") { return }
    token = text
    sub(/[ \t].*$/, "", token)
    text = substr(text, length(token) + 1)
    top = (_bu_sp > 0) ? _bu_st[_bu_sp] : ""
    if (top == "H" && token == "in") {
      _bu_st[_bu_sp] = "K"; _bu_command_start = 1
    } else if (top == "H") {
      # Subject words continue until the unquoted `in` keyword.
      _bu_command_start = 1
    } else if ((top == "K" || top == "B") && token == "esac") {
      bu_scan_pop_case(); _bu_command_start = 0
    } else if (top == "K") {
      # `case` here is a pattern word, not a nested command.
      _bu_command_start = 0
    } else if (token == "case") {
      _bu_st[++_bu_sp] = "H"; _bu_command_start = 1
    } else if (token == "if" || token == "while" || token == "until" ||
        token == "then" || token == "do" || token == "else" ||
        token == "elif" || token == "{" || token == "!") {
      _bu_command_start = 1
    } else { _bu_command_start = 0 }
  }
}

function bu_scan_update_continuation(   k, depth) {
  depth = 0
  for (k = 1; k <= _bu_sp; k++) { if (_bu_st[k] == "C") { depth++ } }
  for (k in _bu_cont_depth) {
    if ((k + 0) >= depth) { delete _bu_cont_depth[k] }
  }
  if (_bu_cont) { _bu_cont_depth[depth] = 1 }
  else { _bu_command_start = 1 }
}

function bu_scan_has_continuation(   depth) {
  for (depth in _bu_cont_depth) { return 1 }
  return 0
}

function bu_scan_line(line,   i, n, c, prev, top, body, rest, offset, lead, keyword, head) {
  _bu_cont = 0

  if (_bu_hd != "") {
    body = line
    if (_bu_hdtab) { sub(/^\t+/, "", body) }
    if (body == _bu_hd) { _bu_hd = "" }
    bu_scan_update_continuation()
    return
  }

  # Same early-out as the reference: with nothing open, a line holding none of
  # these characters cannot change state unless it starts with a reserved word
  # that introduces a command.
  lead = line
  sub(/^[ \t]+/, "", lead)
  keyword = lead
  sub(/[ \t;&|)].*$/, "", keyword)
  if (_bu_sp == 0 && !bu_scan_has_continuation() && _bu_command_start &&
      keyword != "case" && keyword != "if" && keyword != "while" &&
      keyword != "until" && keyword != "then" && keyword != "do" &&
      keyword != "else" && keyword != "elif" && keyword != "{" &&
      keyword != "!" && index(line, _bu_sq) == 0 && index(line, "\"") == 0 &&
      index(line, "\\") == 0 && index(line, "(") == 0 && index(line, "<") == 0 &&
      index(line, ";") == 0 && index(line, "&") == 0 && index(line, "|") == 0) {
    return
  }

  n = length(line)
  prev = ""
  for (i = 1; i <= n; i++) {
    top = (_bu_sp > 0) ? _bu_st[_bu_sp] : ""
    # Skip ordinary text in one native scan, as the Bash reference does.
    rest = substr(line, i)
    if (top == "S") { offset = index(rest, _bu_sq) }
    else if (top == "D") { offset = match(rest, /["\\$]/) }
    else { offset = match(rest, _bu_special) }
    head = offset ? substr(rest, 1, offset - 1) : rest
    if (_bu_command_start && top != "S" && top != "D" && top != "A" &&
        top != "R") {
      bu_scan_words(head)
    }
    if (!offset) { break }
    if (offset > 1) { prev = substr(rest, offset - 1, 1) }
    i += offset - 1
    c = substr(line, i, 1)
    top = (_bu_sp > 0) ? _bu_st[_bu_sp] : ""

    # Nothing but the closing quote is reported inside a single-quoted string.
    if (top == "S") {
      if (c == _bu_sq) {
        _bu_sp--
        if (_bu_sp > 0 && _bu_st[_bu_sp] == "H") { _bu_command_start = 1 }
      }
      prev = c
      continue
    }

    # A backslash escapes the next character in both remaining contexts; inside
    # a single-quoted string it is literal, and the branch above took that case.
    if (c == "\\") {
      if (i == n) { _bu_cont = 1 }
      else { _bu_command_start = 0 }
      i++; prev = substr(line, i, 1); continue
    }

    if (top == "D") {
      if (c == "\"") {
        _bu_sp--
        if (_bu_sp > 0 && _bu_st[_bu_sp] == "H") { _bu_command_start = 1 }
      }
      else if (c == "$" && substr(line, i + 1, 1) == "(") {
        if (substr(line, i + 2, 1) == "(") {
          _bu_st[++_bu_sp] = "R"; _bu_st[++_bu_sp] = "R"
          _bu_command_start = 0
          i += 2; prev = "("; continue
        }
        _bu_sp++; _bu_st[_bu_sp] = "C"; _bu_command_start = 1
        i++; prev = "("; continue
      }
      prev = c
      continue
    }

    if (c == _bu_sq) {
      _bu_sp++; _bu_st[_bu_sp] = "S"
      if (top != "A" && top != "H") { _bu_command_start = 0 }
      prev = c; continue
    }
    if (c == "\"") {
      _bu_sp++; _bu_st[_bu_sp] = "D"
      if (top != "A" && top != "H") { _bu_command_start = 0 }
      prev = c; continue
    }
    if (c == "#") {
      if (prev == "" || prev == " " || prev == "\t" ||
          prev == ";" || prev == "&" || prev == "|") {
        bu_scan_update_continuation()
        return
      }
      prev = c
      continue
    }
    if (c == "(") {
      if (top == "K" && _bu_command_start) {
        _bu_command_start = 0
        prev = c
        continue
      }
      if (substr(line, i + 1, 1) == "(") {
        _bu_st[++_bu_sp] = "R"; _bu_st[++_bu_sp] = "R"
        i++; prev = "("; continue
      }
      _bu_sp++
      if (prev == "$") { _bu_st[_bu_sp] = "C"; _bu_command_start = 1 }
      else if (top == "R") { _bu_st[_bu_sp] = "R" }
      else if (prev == "<" || prev == ">") {
        _bu_st[_bu_sp] = "C"; _bu_command_start = 1
      }
      else { _bu_st[_bu_sp] = (prev == "=") ? "A" : "P" }
      prev = c
      continue
    }
    if (c == ")") {
      if (top == "K") { _bu_st[_bu_sp] = "B"; _bu_command_start = 1 }
      else {
        if (_bu_sp > 0) { _bu_sp-- }
        _bu_command_start = (_bu_sp > 0 && _bu_st[_bu_sp] == "H")
      }
      prev = c
      continue
    }
    if (c == ";") {
      if (top == "B" && (substr(line, i + 1, 1) == ";" ||
          substr(line, i + 1, 1) == "&")) {
        _bu_st[_bu_sp] = "K"
      }
      _bu_command_start = 1
      prev = c
      continue
    }
    if (c == "&") {
      _bu_command_start = 1
      prev = c
      continue
    }
    if (c == "|") {
      # Pattern alternatives remain pattern words, even when named `esac`.
      _bu_command_start = (top == "K") ? 0 : 1
      prev = c
      continue
    }
    if (c == "<" && top == "R") { prev = c; continue }
    if (c == "<" && substr(line, i + 1, 1) == "<") {
      if (substr(line, i + 2, 1) == "<") { i += 2; prev = "<"; continue }
      bu_scan_heredoc(substr(line, i + 2))
      i++
      prev = "<"
      continue
    }
    prev = c
  }
  bu_scan_update_continuation()
}

function bu_scan_open(   k) {
  if (_bu_cont) { return 1 }
  if (_bu_hd != "") { return 1 }
  for (k = _bu_sp; k > 0; k--) {
    if (_bu_st[k] == "C") { return 0 }
    if (_bu_st[k] == "S" || _bu_st[k] == "D" || _bu_st[k] == "A") { return 1 }
  }
  return 0
}

# The open contexts, innermost last. Only the differential reads it: a real
# shell file ends with nothing open, so a non-empty state at EOF is a lexer bug
# and this says which context leaked.
function bu_scan_stack(   k, s) {
  s = ""
  for (k = 1; k <= _bu_sp; k++) { s = s _bu_st[k] }
  return s
}

# Describes the literal spans held by the scanner stack before or after a line.
# Command substitutions increase the command depth. Literal contexts remain
# attached to the depth at which they opened while child commands are scanned.
function bu_scan_span_state(after,   k, depth, c) {
  depth = 0
  if (after) { split("", _bu_after_span) }
  else { split("", _bu_before_span) }
  for (k = 1; k <= _bu_sp; k++) {
    c = _bu_st[k]
    if (c == "C") { depth++ }
    else if (c == "S" || c == "D" || c == "A") {
      if (after) { _bu_after_span[depth] = 1 }
      else { _bu_before_span[depth] = 1 }
    }
  }
  for (k in _bu_cont_depth) {
    if (after) { _bu_after_span[k] = 1 }
    else { _bu_before_span[k] = 1 }
  }
  if (after) { _bu_after_depth = depth }
  else { _bu_before_depth = depth }
}

# Gives every line of a multi-line statement the highest count recorded
# anywhere in it. The DEBUG trap reports the statement on one line of the span
# and which one depends on the Bash version, so the propagation runs in both
# directions (#722, #1338). Mirrors the loop in get_all_line_hits.
function bu_propagate(sl, hits, total,   ln, start, max, fill, h, open, d, was, now, member, n, parts, current) {
  bu_scan_reset()
  split("", span_lines)
  split("", span_max)
  start = 1
  max = 0
  for (ln = 1; ln <= total; ln++) {
    h = (ln in hits) ? hits[ln] + 0 : 0
    if (h > max) { max = h }

    bu_scan_span_state(0)
    bu_scan_line(sl[ln])
    bu_scan_span_state(1)

    open = bu_scan_open()
    if (!open) {
      if (max > 0 && start < ln) {
        for (fill = start; fill <= ln; fill++) { hits[fill] = max }
      }
      start = ln + 1
      max = 0
    }

    split("", seen)
    for (d in _bu_before_span) { seen[d] = 1 }
    for (d in _bu_after_span) { seen[d] = 1 }
    for (d in seen) {
      was = (d in _bu_before_span)
      now = (d in _bu_after_span)
      member = (was && _bu_before_depth == d) ||
        (now && _bu_after_depth == d) || (was != now)
      if (member) {
        span_lines[d] = span_lines[d] " " ln
        if (h > span_max[d]) { span_max[d] = h }
      }
      if (was && !now) {
        if (span_max[d] > 0) {
          n = split(span_lines[d], parts, " ")
          for (fill = 1; fill <= n; fill++) {
            if (parts[fill] == "") { continue }
            current = (parts[fill] in hits) ? hits[parts[fill]] + 0 : 0
            if (span_max[d] > current) { hits[parts[fill]] = span_max[d] }
          }
        }
        delete span_lines[d]
        delete span_max[d]
      }
    }
  }
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
  bu_propagate(src, hits, total)

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

  bu_propagate(sl, hits, total)

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

  bu_propagate(sl, hits, total)

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
