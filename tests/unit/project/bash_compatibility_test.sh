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

# Returns offending "file:line: text" for a pattern under a directory, skipping
# comment lines so a rule quoted in documentation or in a comment is not an
# error.
function bashunit::compat::offenders_in() {
  grep -rnE "$2" "$1" 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true
}

function bashunit::compat::offenders() {
  bashunit::compat::offenders_in "src/" "$1"
}

# The statement boundary both append rules anchor at: `cmd; x+=y`,
# `if c; then x+=y; fi` and `for i; do x+=y; done` are all appends, and a
# `^`-only anchor walked straight past every one of them.
function bashunit::compat::append_prefix_pattern() {
  local pattern='(^|[;&|]|\bthen\b|\bdo\b|\belse\b)[[:space:]]*'
  pattern="$pattern"'(local[[:space:]]+|declare[[:space:]]+[^[:space:]]+[[:space:]]+|export[[:space:]]+)?'
  pattern="$pattern"'[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?\+='
  echo "$pattern"
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

# String `x+=y` is Bash 3.1+. Use `var="$var$more"`. Arithmetic `(( x += 1 ))`
# is fine on 3.0, so only assignment-position `+=` is matched here.
#
# Measured on a real 3.00.22: this form parses on 3.0 and is simply inert in a
# branch that shell never takes, which is why it is a separate, weaker rule
# from the array form below (#1349).
function test_src_has_no_string_append_assignment() {
  local pattern
  pattern="$(bashunit::compat::append_prefix_pattern)"'([^(]|$)'

  assert_empty "$(bashunit::compat::offenders "$pattern")"
}

# Array `arr+=(x)` is a Bash 3.0 **parse** error, not a runtime one: it kills
# the whole file on 3.0 even inside `if false; then … fi` or an uncalled
# function, and parses fine on 3.2 -- so a green macOS run says nothing about
# it (#1349). No version guard can make it safe; use `arr[${#arr[@]}]=x`.
function test_src_has_no_array_append_assignment() {
  local pattern
  pattern="$(bashunit::compat::append_prefix_pattern)"'\('

  assert_empty "$(bashunit::compat::offenders "$pattern")"
}

# The two rules must not answer for each other, or the split means nothing: a
# rule that matched both would keep calling a parse error a runtime concern.
function test_the_append_rules_each_match_only_their_own_construct() {
  local dir
  dir="$(bashunit::temp_dir)"
  printf 'function f() {\n  x+=y\n}\n' >"$dir/string_append.sh"
  printf 'function f() {\n  arr+=(x)\n}\n' >"$dir/array_append.sh"

  local string_pattern array_pattern
  string_pattern="$(bashunit::compat::append_prefix_pattern)"'([^(]|$)'
  array_pattern="$(bashunit::compat::append_prefix_pattern)"'\('

  local string_hits array_hits
  string_hits="$(bashunit::compat::offenders_in "$dir" "$string_pattern")"
  array_hits="$(bashunit::compat::offenders_in "$dir" "$array_pattern")"

  assert_contains "string_append.sh" "$string_hits"
  assert_not_contains "array_append.sh" "$string_hits"
  assert_contains "array_append.sh" "$array_hits"
  assert_not_contains "string_append.sh" "$array_hits"
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
#
# The name class covers positional and `$@`/`$*` too: a rule built only around
# `[A-Za-z_][A-Za-z0-9_]*` saw `${var,,}` and walked past `${1,,}` and `${@,,}`,
# which are the same Bash 4.0 construct and fail the same way -- at runtime, so
# an uncaught one ships and breaks only when its line executes (#1350).
function bashunit::compat::case_conversion_pattern() {
  echo '\$\{([A-Za-z_][A-Za-z0-9_]*|[0-9]+|[@*])(\[[^]]*\])?(,,|\^\^|,|\^)\}'
}

function test_src_has_no_parameter_expansion_case_conversion() {
  assert_empty "$(bashunit::compat::offenders "$(bashunit::compat::case_conversion_pattern)")"
}

# Every spelling of the construct, so the rule cannot silently narrow back to
# the one that happens to be written most often.
function test_the_case_conversion_rule_sees_every_parameter_spelling() {
  local dir
  dir="$(bashunit::temp_dir)"
  {
    echo 'lower=${var,,}'
    echo 'upper=${var^^}'
    echo 'positional=${1,,}'
    echo 'all_args=${@,,}'
    echo 'star_args=${*,,}'
    echo 'element=${arr[0],,}'
    echo 'first_char=${var^}'
  } >"$dir/case_conversion.sh"

  local hits
  hits="$(bashunit::compat::offenders_in "$dir" \
    "$(bashunit::compat::case_conversion_pattern)")"

  local line
  local missed=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$hits" in
    *"$line"*) ;;
    *) missed="$missed $line" ;;
    esac
  done <<<"$(printf '%s\n' 'lower=' 'upper=' 'positional=' 'all_args=' 'star_args=' 'element=' 'first_char=')"

  assert_empty "$missed"
}

# And nothing that is not the construct: `${var:-,}` and `${#var}` are ordinary
# expansions on every supported bash.
function test_the_case_conversion_rule_ignores_other_expansions() {
  local dir
  dir="$(bashunit::temp_dir)"
  {
    echo 'default=${var:-,}'
    echo 'length=${#var}'
    echo 'joined=${arr[*]}'
  } >"$dir/not_case_conversion.sh"

  assert_empty "$(bashunit::compat::offenders_in "$dir" \
    "$(bashunit::compat::case_conversion_pattern)")"
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
