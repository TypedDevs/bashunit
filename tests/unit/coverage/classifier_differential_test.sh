#!/usr/bin/env bash

# The awk classifier and the Bash one must agree on every line of every shell
# file in the repo. A disagreement moves coverage numbers silently, which is
# exactly what #1005 warned about when it reproduced the old regex quirk for
# quirk -- so this compares them line by line rather than trusting either.

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
}

# Classifies every line of $1 with awk, printing "<lineno> <0|1>".
# $2 overrides the rule source, which is how the mutation below is injected.
function awk_classification() { # $1 = file, $2 = optional rule source
  local rules="${2:-$(bashunit::coverage::awk_rules)}"
  env LC_ALL=C "$AWK" "$rules"'
    { printf "%s %s\n", FNR, bu_is_executable($0) }
  ' "$1"
}

# Classifies every line of $1 with the Bash reference, same format.
function bash_classification() { # $1 = file
  local lineno=0 line
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    if bashunit::coverage::is_executable_line "$line" "$lineno"; then
      printf '%s 1\n' "$lineno"
    else
      printf '%s 0\n' "$lineno"
    fi
  done <"$1"
}

function test_both_classifiers_agree_on_every_shell_file_in_the_repo() {
  local disagreements=""
  local file
  for file in $(cd "$ROOT_DIR" && git ls-files '*.sh'); do
    local diff_out
    diff_out=$(diff <(bash_classification "$ROOT_DIR/$file") \
      <(awk_classification "$ROOT_DIR/$file") 2>&1) || true
    if [ -n "$diff_out" ]; then
      disagreements="$disagreements
$file
$diff_out"
    fi
  done

  assert_empty "$disagreements"
}

# The differential is only worth anything if it can fail. The mutation removes
# ONE rule from the awk copy and leaves a valid program: an earlier version
# redefined the whole function, which awk rejects outright -- so the test
# passed on an awk error rather than on a disagreement, which is the failure
# mode this guard exists to rule out.
function test_the_differential_catches_a_broken_awk_rule() {
  local fixture
  fixture="$(bashunit::temp_file)"
  printf '# a comment\nx=1\n' >"$fixture"

  local mutated_rules
  mutated_rules=$(bashunit::coverage::awk_rules |
    sed 's|if (substr(trimmed, 1, 1) == "#") { return 0 }||')

  local mutated reference
  mutated=$(awk_classification "$fixture" "$mutated_rules")
  reference=$(bash_classification "$fixture")

  # The mutation must still produce a working classifier, just a wrong one.
  assert_not_empty "$mutated"
  assert_not_equals "$reference" "$mutated"
}

function test_the_classifiers_agree_on_the_quirk_cases() {
  local fixture
  fixture="$(bashunit::temp_file)"
  {
    printf '%s\n' 'x=$(foo)'
    printf '%s\n' 'x=$(printf "%s\n")'
    printf '%s\n' '  --option)'
    printf '%s\n' '  *) # note'
    # shellcheck disable=SC1003  # a lone backslash is the case being tested
    printf '%s\n' '\'
    printf '%s\n' '	'
    printf '%s\n' 'done < file'
    printf '%s\n' 'done'
    printf '%s\n' 'function bashunit::x() {'
    printf '%s\n' 'name() {'
    printf '%s\n' '((i++))'
  } >"$fixture"

  assert_same "$(bash_classification "$fixture")" "$(awk_classification "$fixture")"
}
