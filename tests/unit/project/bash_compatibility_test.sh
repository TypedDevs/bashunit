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

# Every "<file>:<line>" sitting in the then-branch of a version gate whose tier
# is at least $2.
#
# A gate is a column-0 `if [ "$_BASHUNIT_BASH_GE_NN" = 1 ]; then`, closed by a
# column-0 `else` or `fi`. Column 0 is the whole check: an indented header is a
# runtime condition inside some other block, and gates nothing, so a construct
# under it would still reach a shell that cannot parse or run it.
#
# The tier is read from the flag name, which is why the name carries it. See
# adrs/adr-013-bash-version-gated-fast-paths.md.
function bashunit::compat::gated_lines_in() {
  find "$1" -name '*.sh' -type f -print0 |
    xargs -0 awk -v min="$2" '
      FNR == 1 { gate = 0 }
      /^if \[ "\$_BASHUNIT_BASH_GE_[0-9]+" = 1 \]; then$/ {
        tier = $0
        sub(/^.*_GE_/, "", tier)
        sub(/".*$/, "", tier)
        gate = tier + 0
        next
      }
      /^(else|fi)$/ { gate = 0; next }
      gate > 0 && gate >= min { printf "%s:%d\n", FILENAME, FNR }
    '
}

# Offenders for a pattern, minus the ones a sufficient gate covers.
#
# $3 is the construct's minimum Bash version as a tier: `printf -v` is 31,
# `declare -A` is 40. A tier of 0 means no gate is ever enough -- either the
# construct is a parse error below the floor, so it kills the file even in a
# branch that shell never takes, or its boundary is not established and
# guessing one would be worse than forbidding it.
#
# Matching stays with `grep -E`, and only the filtering is new: the patterns
# here are written for grep, and handing them to a second regex engine would
# quietly change which lines a rule catches.
function bashunit::compat::ungated_offenders_in() {
  local dir=$1
  local pattern=$2
  local min=$3

  local hits
  hits="$(bashunit::compat::offenders_in "$dir" "$pattern")"
  [ -n "$hits" ] || return 0

  if [ "$min" -eq 0 ]; then
    printf '%s\n' "$hits"
    return 0
  fi

  local allowed
  allowed=$'\n'"$(bashunit::compat::gated_lines_in "$dir" "$min")"$'\n'

  local line file lineno rest
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    file=${line%%:*}
    rest=${line#*:}
    lineno=${rest%%:*}
    case "$allowed" in
    *$'\n'"$file:$lineno"$'\n'*) continue ;;
    esac
    printf '%s\n' "$line"
  done <<EOF
$hits
EOF
}

function bashunit::compat::ungated_offenders() {
  bashunit::compat::ungated_offenders_in "src/" "$1" "$2"
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
  assert_empty "$(bashunit::compat::ungated_offenders \
    '^[[:space:]]*local[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=\(' 32)"
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
  assert_empty "$(bashunit::compat::ungated_offenders \
    '\$\{[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?//[#%][^a-zA-Z0-9_[]' 0)"
}

# `printf -v` is Bash 3.1+. Use the return-slot pattern documented in
# .claude/rules/bash-style.md instead (which also avoids its dynamic-scope trap).
function test_src_has_no_printf_assignment() {
  assert_empty "$(bashunit::compat::ungated_offenders 'printf[[:space:]]+(-[a-zA-Z]*v)' 31)"
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

  assert_empty "$(bashunit::compat::ungated_offenders "$pattern" 31)"
}

# Array `arr+=(x)` is a Bash 3.0 **parse** error, not a runtime one: it kills
# the whole file on 3.0 even inside `if false; then … fi` or an uncalled
# function, and parses fine on 3.2 -- so a green macOS run says nothing about
# it (#1349). No version guard can make it safe; use `arr[${#arr[@]}]=x`.
function test_src_has_no_array_append_assignment() {
  local pattern
  pattern="$(bashunit::compat::append_prefix_pattern)"'\('

  assert_empty "$(bashunit::compat::ungated_offenders "$pattern" 0)"
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
  assert_empty "$(bashunit::compat::ungated_offenders '\[\[[^]]*=~' 0)"
}

# Associative arrays are Bash 4.0+. Use parallel indexed arrays instead.
function test_src_has_no_associative_arrays() {
  assert_empty "$(bashunit::compat::ungated_offenders \
    '(declare|local|typeset)[[:space:]]+(-[a-zA-Z]*A)' 40)"
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
  assert_empty "$(bashunit::compat::ungated_offenders \
    "$(bashunit::compat::case_conversion_pattern)" 40)"
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
  assert_empty "$(bashunit::compat::ungated_offenders '\$\{[A-Za-z_][A-Za-z0-9_]*\[-[0-9]' 43)"
}

# &>> is Bash 4.0+. Use `>> file 2>&1` instead.
function test_src_has_no_append_both_streams_redirect() {
  assert_empty "$(bashunit::compat::ungated_offenders '&>>' 0)"
}

# BASHPID is Bash 4.0+. Subshells inherit $$, so a per-worker unique token needs
# a fork (mktemp) or an externally assigned ordinal -- see #851.
function test_src_has_no_bashpid() {
  assert_empty "$(bashunit::compat::ungated_offenders 'BASHPID' 40)"
}

# mapfile/readarray are Bash 4.0+. Use a `while IFS= read -r` loop instead.
function test_src_has_no_mapfile_or_readarray() {
  assert_empty "$(bashunit::compat::ungated_offenders \
    '(^|[^[:alnum:]_])(mapfile|readarray)([^[:alnum:]_]|$)' 40)"
}

# declare -n / local -n (namerefs) are Bash 4.3+. Use the return-slot pattern
# documented in .claude/rules/bash-style.md instead.
function test_src_has_no_namerefs() {
  assert_empty "$(bashunit::compat::ungated_offenders \
    '(declare|local|typeset)[[:space:]]+(-[a-zA-Z]*n)[[:space:]]' 43)"
}

# coproc is Bash 4.0+.
function test_src_has_no_coproc() {
  assert_empty "$(bashunit::compat::ungated_offenders '(^|[^[:alnum:]_])coproc([^[:alnum:]_]|$)' 40)"
}

# ${var@Q} and friends are Bash 4.4+.
function test_src_has_no_parameter_transformations() {
  assert_empty "$(bashunit::compat::ungated_offenders '\$\{[A-Za-z_][A-Za-z0-9_]*@[QEPAKa]\}' 44)"
}

# A temporary-environment locale prefix (`LC_ALL=C cmd`) makes bash change its
# own locale for that command. Bash 5.3.9 on macOS segfaults on that form inside
# a command substitution -- `x=$(LC_ALL=C echo hi)` exits 139 (#912) -- and no CI
# job runs that build. Use `env LC_ALL=C cmd` instead, which passes the locale
# straight to the child and never touches bash's own.
function test_src_has_no_temporary_locale_assignment_prefix() {
  local pattern='(^|[;&|(])[[:space:]]*((LC_[A-Z_]+|LANG)=[^[:space:]]*[[:space:]]+)+[^[:space:]=]'

  assert_empty "$(bashunit::compat::ungated_offenders "$pattern" 0)"
}


# --- the gate mechanism itself --------------------------------------------
#
# Everything above trusts bashunit::compat::ungated_offenders to allow a
# construct only where a sufficient gate covers it. These pin what "sufficient"
# means, on fixtures rather than on src/, because src/ is expected to be clean
# and a rule that quietly stopped matching would still look green.

# Writes $2 into a fixture file under a fresh directory and echoes the directory.
function _gate_fixture() { # $1 = basename, $2 = contents
  local dir
  dir="$(bashunit::temp_dir)"
  printf '%s\n' "$2" >"$dir/$1.sh"
  printf '%s' "$dir"
}

# `printf -v` is Bash 3.1, so tier 31 is exactly enough.
function test_a_construct_is_allowed_inside_a_gate_of_its_own_tier() {
  local dir
  dir="$(_gate_fixture gated 'if [ "$_BASHUNIT_BASH_GE_31" = 1 ]; then
  printf -v out "%s" "x"
fi')"

  assert_empty "$(bashunit::compat::ungated_offenders_in "$dir" \
    'printf[[:space:]]+(-[a-zA-Z]*v)' 31)"
}

function test_a_construct_is_allowed_inside_a_higher_gate() {
  local dir
  dir="$(_gate_fixture higher 'if [ "$_BASHUNIT_BASH_GE_50" = 1 ]; then
  printf -v out "%s" "x"
fi')"

  assert_empty "$(bashunit::compat::ungated_offenders_in "$dir" \
    'printf[[:space:]]+(-[a-zA-Z]*v)' 31)"
}

function test_a_construct_is_rejected_when_it_is_not_gated_at_all() {
  local dir
  dir="$(_gate_fixture ungated 'printf -v out "%s" "x"')"

  assert_contains "ungated.sh" "$(bashunit::compat::ungated_offenders_in "$dir" \
    'printf[[:space:]]+(-[a-zA-Z]*v)' 31)"
}

function test_a_construct_is_rejected_under_a_lower_gate() {
  local dir
  dir="$(_gate_fixture too_low 'if [ "$_BASHUNIT_BASH_GE_31" = 1 ]; then
  declare -A map
fi')"

  assert_contains "too_low.sh" "$(bashunit::compat::ungated_offenders_in "$dir" \
    '(declare|local|typeset)[[:space:]]+(-[a-zA-Z]*A)' 40)"
}

# The else-branch is what the OLD shell runs, so it is the one place a new
# construct is guaranteed to reach a shell that cannot handle it.
function test_a_construct_is_rejected_in_the_else_branch_of_a_gate() {
  local dir
  dir="$(_gate_fixture else_branch 'if [ "$_BASHUNIT_BASH_GE_31" = 1 ]; then
  out="x"
else
  printf -v out "%s" "x"
fi')"

  assert_contains "else_branch.sh" "$(bashunit::compat::ungated_offenders_in "$dir" \
    'printf[[:space:]]+(-[a-zA-Z]*v)' 31)"
}

function test_a_construct_is_rejected_after_the_gate_closes() {
  local dir
  dir="$(_gate_fixture after_fi 'if [ "$_BASHUNIT_BASH_GE_31" = 1 ]; then
  out="x"
fi
printf -v out "%s" "x"')"

  assert_contains "after_fi.sh" "$(bashunit::compat::ungated_offenders_in "$dir" \
    'printf[[:space:]]+(-[a-zA-Z]*v)' 31)"
}

# An indented header is a runtime condition inside some other block. The body
# is parsed on every shell, and reached whenever that outer block runs, so it
# gates nothing.
function test_an_indented_gate_header_gates_nothing() {
  local dir
  dir="$(_gate_fixture indented 'function f() {
  if [ "$_BASHUNIT_BASH_GE_31" = 1 ]; then
    printf -v out "%s" "x"
  fi
}')"

  assert_contains "indented.sh" "$(bashunit::compat::ungated_offenders_in "$dir" \
    'printf[[:space:]]+(-[a-zA-Z]*v)' 31)"
}

# A header the recogniser does not accept must gate nothing, rather than being
# read loosely: a near-miss is how a rule quietly stops enforcing.
function test_a_non_canonical_gate_header_gates_nothing() {
  local dir
  dir="$(_gate_fixture non_canonical 'if [ "$_BASHUNIT_BASH_GE_31" = "1" ]; then
  printf -v out "%s" "x"
fi')"

  assert_contains "non_canonical.sh" "$(bashunit::compat::ungated_offenders_in "$dir" \
    'printf[[:space:]]+(-[a-zA-Z]*v)' 31)"
}

# A pragma is the author's claim, not a structural fact, so honouring one would
# be a smuggling path by construction. It was considered and rejected.
function test_a_pragma_comment_cannot_smuggle_a_construct_in() {
  local dir
  dir="$(_gate_fixture pragma 'printf -v out "%s" "x" # bashunit: bash4')"

  assert_contains "pragma.sh" "$(bashunit::compat::ungated_offenders_in "$dir" \
    'printf[[:space:]]+(-[a-zA-Z]*v)' 31)"
}

# Tier 0 means no gate is ever enough: `arr+=(x)` and `&>>` are parse errors on
# the floor, so they kill the file from inside a branch that shell never takes.
function test_a_tier_zero_construct_is_rejected_even_inside_the_highest_gate() {
  local dir
  dir="$(_gate_fixture parse_time 'if [ "$_BASHUNIT_BASH_GE_50" = 1 ]; then
  arr+=(x)
  cmd &>>log
fi')"

  local pattern
  pattern="$(bashunit::compat::append_prefix_pattern)"'\('

  assert_contains "parse_time.sh" "$(bashunit::compat::ungated_offenders_in "$dir" \
    "$pattern" 0)"
  assert_contains "parse_time.sh" "$(bashunit::compat::ungated_offenders_in "$dir" \
    '&>>' 0)"
}

# An unclosed gate must not leak into the next file scanned.
function test_a_gate_does_not_carry_over_into_the_next_file() {
  local dir
  dir="$(bashunit::temp_dir)"
  printf '%s\n' 'if [ "$_BASHUNIT_BASH_GE_50" = 1 ]; then
  out="x"' >"$dir/a_unclosed.sh"
  printf '%s\n' 'printf -v out "%s" "x"' >"$dir/b_next.sh"

  assert_contains "b_next.sh" "$(bashunit::compat::ungated_offenders_in "$dir" \
    'printf[[:space:]]+(-[a-zA-Z]*v)' 31)"
}

# Every gate in src/ names a flag the flags file actually declares. A typo
# would leave the flag empty, the fast body unreachable and the fallback in use
# on every shell -- green, silently slower, and impossible to see in review.
function test_every_gate_in_src_names_a_declared_flag() {
  local used declared missing
  used="$(grep -rhoE '_BASHUNIT_BASH_GE_[0-9]+' src/ | LC_ALL=C sort -u)"
  declared="$(grep -hoE '^_BASHUNIT_BASH_GE_[0-9]+' src/system/bash.sh | LC_ALL=C sort -u)"

  missing=""
  local flag
  while IFS= read -r flag; do
    [ -z "$flag" ] && continue
    case "$declared" in
    *"$flag"*) ;;
    *) missing="$missing $flag" ;;
    esac
  done <<EOF
$used
EOF

  assert_empty "$missing"
}

# The Bash 3.0 job catches a parse-time construct anywhere in src/ because the
# entrypoint sources every module. This says the same thing about the shell
# running right now, which is trivially true on 5.x and the actual check on the
# macOS 3.2 and real-3.0 jobs.
function test_every_src_file_parses_with_the_running_bash() {
  local file
  local failures=""

  while IFS= read -r file; do
    [ -z "$file" ] && continue
    bash -n "$file" 2>/dev/null || failures="$failures $file"
  done <<EOF
$(find src -name '*.sh' -type f)
EOF

  assert_empty "$failures"
}


# --- shell facts the code is built on -------------------------------------
#
# Both of these were stated wrongly in the rules files and relied on while
# planning performance work (#1354). A claim about the shell is worth a test
# precisely because nothing else notices when it stops being true.

# The rules said a Bash 3 subshell inherits the `RANDOM` state, and gave that
# as the reason a --parallel worker cannot mint a unique token. Measured, the
# truth is messier than either that or its correction:
#
#   plain shell, every supported version   three `$( )` reads differ
#   --parallel worker, Linux 3.0 and 5.2   three `$( )` reads differ
#   --parallel worker, macOS 3.2.57        three `$( )` reads are IDENTICAL
#
# So RANDOM is neither reliably shared nor reliably reseeded: it depends on the
# platform and on how deeply nested the subshell is. Nothing may depend on it
# either way, which is why there is no assertion about it here -- pinning either
# direction would just make one platform red. The ordinal scheme (#851) stands,
# now for a stronger reason than the one originally written down (#1354).
#
# What IS stable is the half the design actually rests on: a subshell inherits
# `$$`, so a token built from it repeats across workers.
function test_a_subshell_inherits_the_parent_pid() {
  assert_same "$$" "$(printf '%s' "$$")"
}

# `shopt -s extdebug` turns on errtrace and functrace everywhere. Turning it
# back off does not behave the same across the supported range: up to 4.3 it
# leaves them as they were, from 4.4 it clears both. That is the concrete shape
# of the hazard #808 works around, and anything that stops doing this inside a
# subshell has to save and restore them.
function test_unsetting_extdebug_clears_error_tracing_from_bash_44() {
  local state
  state=$(
    set -E
    set -T
    shopt -s extdebug
    shopt -u extdebug
    e=off
    t=off
    # Parameter expansion, not `case`: a `)` in a case pattern inside `$( )`
    # is a parse error on Bash 3.2, which closes the substitution early.
    if [ "${-#*E}" != "$-" ]; then e=on; fi
    if [ "${-#*T}" != "$-" ]; then t=on; fi
    echo "$e/$t"
  )

  local expected="on/on"
  if [ "${BASH_VERSINFO[0]:-0}" -gt 4 ]; then
    expected="off/off"
  elif [ "${BASH_VERSINFO[0]:-0}" -eq 4 ] && [ "${BASH_VERSINFO[1]:-0}" -ge 4 ]; then
    expected="off/off"
  fi

  assert_same "$expected" "$state"
}
