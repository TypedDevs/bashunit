#!/usr/bin/env bash

# Locating function definitions and their line spans, for the reports.

# The declaration scanner, as awk source.
#
# It was a Bash `while read` loop with two `${line//[^\{]/}` substitutions per
# line to count braces. Bash 3.2 pattern substitution over a whole file is the
# single most expensive thing in the report phase: 17.5 ms per file against
# awk's 3.1 ms, and the report calls this once per file per renderer. One pass
# in awk instead (#1084).
#
# Braces are counted as code only: a brace inside a comment, a string or a
# heredoc body is data, and counting it kept the enclosing function open so it
# swallowed every later declaration in the file (#1086).
#
# It lives in a shell string rather than a .awk file because the build flattens
# *.sh into one artifact (ADR-011); a separate file would not ship.
# shellcheck disable=SC2016  # the $0 in here is awk's, not the shell's
_BASHUNIT_COVERAGE_AWK_FUNCTIONS='
BEGIN { SQ = sprintf("%c", 39) }

# Scans one line under the quote and heredoc state carried over from the lines
# before it -- a string or a heredoc body can span lines, so per-line state is
# not enough. Sets nopen/nclose to the braces that are code, and code_start to
# 1 when the line begins outside any string or heredoc, which is the only place
# a declaration can start.
function bu_scan(line,   i, n, c, rest, delim, q) {
  nopen = 0
  nclose = 0
  code_start = (in_s == 0 && in_d == 0 && hd == "")

  if (hd != "") {
    rest = line
    if (hd_strip) { sub(/^\t+/, "", rest) }
    if (rest == hd) { hd = "" }
    return
  }

  n = length(line)
  for (i = 1; i <= n; i++) {
    c = substr(line, i, 1)

    if (in_s) {
      # Single quotes take no escapes: the next one always closes.
      if (c == SQ) { in_s = 0 }
      continue
    }
    if (in_d) {
      if (c == "\\") { i++; continue }
      if (c == "\"") { in_d = 0 }
      continue
    }
    if (c == "\\") { i++; continue }
    if (c == SQ) { in_s = 1; continue }
    if (c == "\"") { in_d = 1; continue }

    # A `#` opens a comment only where bash opens one, at the start of a word,
    # so ${x#foo} and a#b keep their braces.
    if (c == "#") {
      if (i == 1) { return }
      q = substr(line, i - 1, 1)
      if (q == " " || q == "\t" || q == ";" || q == "&" || q == "|" || q == "(") { return }
      continue
    }

    if (c == "<" && substr(line, i + 1, 1) == "<") {
      # `<<<` is a here-string: one line, no body. Consume all three so the
      # second `<` cannot read as the start of a heredoc and swallow the file.
      if (substr(line, i + 2, 1) == "<") { i = i + 2; continue }

      rest = substr(line, i + 2)
      hd_strip = 0
      if (substr(rest, 1, 1) == "-") { hd_strip = 1; rest = substr(rest, 2) }
      sub(/^[ \t]+/, "", rest)
      q = substr(rest, 1, 1)
      if (q == SQ || q == "\"") {
        delim = substr(rest, 2)
        if (index(delim, q) == 0) {
          delim = ""
        } else {
          sub(q ".*$", "", delim)
        }
      } else {
        delim = rest
        sub(/[ \t;)&|<>].*$/, "", delim)
      }
      # The body starts on the next line, so nothing after the operator on this
      # one can close the function.
      if (delim != "") { hd = delim; return }
      continue
    }

    if (c == "{") { nopen++ } else if (c == "}") { nclose++ }
  }
}

{
  line = $0
  bu_scan(line)

  if (in_function == 0 && code_start) {
    # Pattern 1: function name() { or function name {
    # Pattern 2: name() { or name () {
    stripped = line
    sub(/^[ \t]+/, "", stripped)
    if (stripped ~ /^function[ \t]/) {
      sub(/^function/, "", stripped)
      sub(/^[ \t]+/, "", stripped)
    }

    # The candidate name is the first word, ending at whitespace, `(` or `{`.
    name = stripped
    sub(/[ \t({].*$/, "", name)

    if (name != "") {
      ok = 1
      # A candidate holding anything outside the identifier alphabet is not a
      # function name. Cutting at the first `{` means `VAR="x${Y}"` yields
      # `VAR="x$`, whose trailing `{Y}"` then looks like a body opener -- every
      # such assignment became a phantom FN record, and one containing the
      # record separator `|` shifted the fields and crashed the arithmetic in
      # report_lcov (#936). Checking only the first character let all of that
      # through.
      if (name ~ /[^a-zA-Z0-9_:]/) {
        ok = 0
      } else if (name !~ /^[a-zA-Z_]/) {
        ok = 0
      } else {
        # A declaration continues with `()` or `{`; a call does not.
        after = substr(stripped, length(name) + 1)
        sub(/^[ \t]+/, "", after)
        if (substr(after, 1, 2) != "()" && substr(after, 1, 1) != "{") { ok = 0 }
      }

      if (ok) {
        in_function = 1
        current_fn = name
        fn_start = NR
        brace_count = nopen - nclose
        # Single-line function: braces balance on the same line, both present.
        if (brace_count == 0 && nopen > 0 && nclose > 0) {
          print current_fn "|" fn_start "|" NR
          in_function = 0
          current_fn = ""
        }
        next
      }
    }
  }

  if (in_function == 1) {
    brace_count = brace_count + nopen - nclose
    if (brace_count <= 0) {
      print current_fn "|" fn_start "|" NR
      in_function = 0
      current_fn = ""
      brace_count = 0
    }
  }
}

# An unclosed function (should not happen in valid code) still gets a record,
# ending at the last line, so a truncated file cannot drop one silently.
END {
  if (in_function == 1 && current_fn != "") { print current_fn "|" fn_start "|" NR }
}
'

##
# Extract function definitions from a bash file.
# Output format: function_name|start_line|end_line (one per function)
# Arguments: $1 - source file
##
function bashunit::coverage::extract_functions() {
  env LC_ALL=C "$AWK" "$_BASHUNIT_COVERAGE_AWK_FUNCTIONS" "$1"
}
