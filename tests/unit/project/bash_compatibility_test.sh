#!/usr/bin/env bash

# Guards the minimum-bash contract mechanically.
#
# The Bash 3.0 CI job only catches a too-new construct when a test happens to
# EXECUTE the line: `${var,,}` inside a rarely-taken branch parses fine and fails
# at runtime, so it can ship. These greps close that gap by rejecting the
# construct at source level regardless of coverage.
#
# Only genuinely version-breaking syntax belongs here. Style preferences (for
# example preferring `[ ]` over `[[ ]]`) are not compatibility rules and are not
# enforced by these tests -- `[[ ]]` works on every bash we support.

# Returns offending "file:line: text" for a pattern, skipping comment lines so a
# rule quoted in documentation or in the `learn` tutorial text is not an error.
function bashunit::compat::offenders() {
  grep -rnE "$1" src/ 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true
}

# Bash 3.0 does not expand a compound array assignment attached to `local`:
# `local arr=(a b)` stores the literal string "(a b)" as a single element
# instead of building the array. Every bash >= 3.2 does the right thing, so
# this only ever breaks on the Bash 3.0 jobs, and silently (see #764).
# Declare and assign on separate lines instead:
#
#   local arr
#   arr=(a b)
#
function test_src_has_no_compound_array_assignment_attached_to_local() {
  local offenders
  offenders=$(grep -rnE '^[[:space:]]*local[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=\(' src/ || true)

  assert_empty "$offenders"
}

# `${var//#pat/repl}` and `${var//%pat/repl}` anchor the match to the start or
# the end. So a bare `#` or `%` as the WHOLE pattern is ambiguous, and Bash 3.0
# resolves it as the anchor with an empty pattern: the replacement is
# prepended/appended and the text is left untouched. `${t//#/\#}` on
# "check # SKIP me" gives "\#check # SKIP me" there, and `${t//%/%25}` on
# "100%" gives "100%%25" -- both silent, and both shipped (#1119, #1121).
#
# Write the pattern as a bracket expression: `${var//[#]/…}`, `${var//[%]/…}`.
function test_src_has_no_bare_hash_or_percent_substitution_pattern() {
  local offenders
  offenders=$(bashunit::compat::offenders \
    '\$\{[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?//[#%][^a-zA-Z0-9_[]')

  assert_empty "$offenders"
}

# `printf -v` is Bash 3.1+. Use the return-slot pattern documented in
# .claude/rules/bash-style.md instead (which also avoids its dynamic-scope trap).
function test_src_has_no_printf_assignment() {
  assert_empty "$(bashunit::compat::offenders 'printf[[:space:]]+(-[a-zA-Z]*v)')"
}

# `+=` append assignment is Bash 3.1+. Use `var="$var$more"` for strings and
# `arr[${#arr[@]}]=x` to append to an array. Arithmetic `(( x += 1 ))` is fine on
# 3.0, so only assignment-position `+=` is matched here.
function test_src_has_no_append_assignment() {
  # Anchored at a statement boundary, not just start-of-line: `cmd; x+=y`,
  # `if c; then x+=y; fi` and `for i; do x+=y; done` are all Bash 3.1+ append
  # assignments, and a `^`-only anchor walked straight past every one of them.
  local pattern='(^|[;&|]|\bthen\b|\bdo\b|\belse\b)[[:space:]]*'
  pattern="$pattern"'(local[[:space:]]+|declare[[:space:]]+[^[:space:]]+[[:space:]]+|export[[:space:]]+)?'
  pattern="$pattern"'[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?\+='

  assert_empty "$(bashunit::compat::offenders "$pattern")"
}

# `[[ =~ ]]` exists on Bash 3.0, but 3.2 changed whether a quoted right-hand side
# is a regex or a literal, so the same match behaves differently across supported
# versions. Regex matching goes through `grep -E` -- see perf-fork-budget.md.
function test_src_has_no_regex_match_operator() {
  assert_empty "$(bashunit::compat::offenders '\[\[[^]]*=~')"
}

# Associative arrays are Bash 4.0+. Use parallel indexed arrays instead.
function test_src_has_no_associative_arrays() {
  assert_empty "$(bashunit::compat::offenders '(declare|local|typeset)[[:space:]]+(-[a-zA-Z]*A)')"
}

# ${var,,} / ${var^^} case conversion is Bash 4.0+. Use tr instead.
function test_src_has_no_parameter_expansion_case_conversion() {
  assert_empty "$(bashunit::compat::offenders '\$\{[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?(,,|\^\^|,|\^)\}')"
}

# ${array[-1]} is Bash 4.3+. Use ${array[${#array[@]}-1]} instead.
function test_src_has_no_negative_array_subscripts() {
  assert_empty "$(bashunit::compat::offenders '\$\{[A-Za-z_][A-Za-z0-9_]*\[-[0-9]')"
}

# &>> is Bash 4.0+. Use `>> file 2>&1` instead.
function test_src_has_no_append_both_streams_redirect() {
  assert_empty "$(bashunit::compat::offenders '&>>')"
}

# BASHPID is Bash 4.0+. Subshells inherit $$, so a per-worker unique token needs
# a fork (mktemp) or an externally assigned ordinal -- see #851.
function test_src_has_no_bashpid() {
  assert_empty "$(bashunit::compat::offenders 'BASHPID')"
}

# mapfile/readarray are Bash 4.0+. Use a `while IFS= read -r` loop instead.
function test_src_has_no_mapfile_or_readarray() {
  assert_empty "$(bashunit::compat::offenders '(^|[^[:alnum:]_])(mapfile|readarray)([^[:alnum:]_]|$)')"
}

# declare -n / local -n (namerefs) are Bash 4.3+. Use the return-slot pattern
# documented in .claude/rules/bash-style.md instead.
function test_src_has_no_namerefs() {
  assert_empty "$(bashunit::compat::offenders '(declare|local|typeset)[[:space:]]+(-[a-zA-Z]*n)[[:space:]]')"
}

# coproc is Bash 4.0+.
function test_src_has_no_coproc() {
  assert_empty "$(bashunit::compat::offenders '(^|[^[:alnum:]_])coproc([^[:alnum:]_]|$)')"
}

# ${var@Q} and friends are Bash 4.4+.
function test_src_has_no_parameter_transformations() {
  assert_empty "$(bashunit::compat::offenders '\$\{[A-Za-z_][A-Za-z0-9_]*@[QEPAKa]\}')"
}

# A temporary-environment locale prefix (`LC_ALL=C cmd`) makes bash change its
# own locale for that command. Bash 5.3.9 on macOS segfaults on that form inside
# a command substitution -- `x=$(LC_ALL=C echo hi)` exits 139 (#912) -- and no CI
# job runs that build. Use `env LC_ALL=C cmd` instead, which passes the locale
# straight to the child and never touches bash's own.
function test_src_has_no_temporary_locale_assignment_prefix() {
  local pattern='(^|[;&|(])[[:space:]]*((LC_[A-Z_]+|LANG)=[^[:space:]]*[[:space:]]+)+[^[:space:]=]'

  assert_empty "$(bashunit::compat::offenders "$pattern")"
}
