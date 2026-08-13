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
# The rules are unchanged, quirks included -- notably that braces are counted
# without regard for strings or comments, so `echo "{"` inside a body extends
# the span. Changing that is a numbers change, not a perf change.
#
# It lives in a shell string rather than a .awk file because the build flattens
# *.sh into one artifact (ADR-011); a separate file would not ship.
# shellcheck disable=SC2016  # the $0 in here is awk's, not the shell's
_BASHUNIT_COVERAGE_AWK_FUNCTIONS='
{
  line = $0
  if (in_function == 0) {
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
        tmp = line; nopen = gsub(/\{/, "{", tmp)
        tmp = line; nclose = gsub(/\}/, "}", tmp)
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
    tmp = line; nopen = gsub(/\{/, "{", tmp)
    tmp = line; nclose = gsub(/\}/, "}", tmp)
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
