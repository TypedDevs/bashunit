#!/usr/bin/env bash

# The awk branch scanner and the Bash one must agree on every shell file in the
# repo. Both are live: the Bash one serves the per-file API and the fallback,
# the awk one runs inside the single-invocation LCOV report (#1090). A
# disagreement moves BRDA/BRF/BRH silently, so this compares them file by file
# rather than trusting either.

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
}

# Extracts $1's branches with awk, in the same
# "<decision>|<kind>|<arm>[,<arm>]" shape the Bash reference prints.
# $2 overrides the scanner source, which is how the mutation below is injected.
function awk_branches() { # $1 = file, $2 = optional scanner source
  local scanner="${2:-$_BASHUNIT_COVERAGE_AWK_BRANCHES}"
  env LC_ALL=C "$AWK" "$scanner"'
    BEGIN { bu_br_reset() }
    { bu_br_line($0, FNR) }
    END {
      for (i = 1; i <= br_count; i++) {
        print br_dec[i] "|" br_kind[i] "|" br_arms[i]
      }
    }
  ' "$1"
}

function test_both_branch_scanners_agree_on_every_shell_file_in_the_repo() {
  # One awk fork per file plus a Bash loop over its lines: seconds here, but
  # minutes under Git Bash, where forks are slow enough to hang a shard.
  bashunit::skip_on windows "an awk fork per repo file takes minutes under Git Bash"

  local disagreements=""
  local file
  for file in $(cd "$ROOT_DIR" && git ls-files '*.sh'); do
    local diff_out
    diff_out=$(diff <(bashunit::coverage::extract_branches "$ROOT_DIR/$file") \
      <(awk_branches "$ROOT_DIR/$file") 2>&1) || true
    if [ -n "$diff_out" ]; then
      disagreements="$disagreements
$file
$diff_out"
    fi
  done

  assert_empty "$disagreements"
}

# The differential is only worth anything if it can fail. The mutation drops the
# `elif`/`else` arm split and leaves a valid program, so a disagreement is what
# fails the test -- not an awk error.
function test_the_differential_catches_a_broken_awk_scanner() {
  local fixture
  fixture="$(bashunit::temp_file)"
  printf 'if [ -n "$x" ]; then\n  echo a\nelse\n  echo b\nfi\n' >"$fixture"

  local mutated_scanner
  mutated_scanner=$(printf '%s' "$_BASHUNIT_COVERAGE_AWK_BRANCHES" |
    sed 's|} else if (first == "elif" \|\| first == "else") {|} else if (first == "@never@") {|')

  local mutated reference
  mutated=$(awk_branches "$fixture" "$mutated_scanner")
  reference=$(bashunit::coverage::extract_branches "$fixture")

  assert_not_empty "$mutated"
  assert_not_equals "$reference" "$mutated"
}

function test_the_scanners_agree_on_nested_and_mixed_constructs() {
  local fixture
  fixture="$(bashunit::temp_file)"
  {
    printf '%s\n' 'while read -r line; do'
    printf '%s\n' '  case "$line" in'
    printf '%s\n' '  a)'
    printf '%s\n' '    if [ -n "$line" ]; then'
    printf '%s\n' '      echo one'
    printf '%s\n' '    elif [ -z "$line" ]; then'
    printf '%s\n' '      echo two'
    printf '%s\n' '    else'
    printf '%s\n' '      echo three'
    printf '%s\n' '    fi'
    printf '%s\n' '    ;;'
    printf '%s\n' '  b | c) # a trailing comment'
    printf '%s\n' '    for i in 1 2; do'
    printf '%s\n' '      echo "$i"'
    printf '%s\n' '    done'
    printf '%s\n' '    ;;&'
    printf '%s\n' '  *) : ;;'
    printf '%s\n' '  esac'
    printf '%s\n' 'done'
  } >"$fixture"

  assert_same "$(bashunit::coverage::extract_branches "$fixture")" \
    "$(awk_branches "$fixture")"
}
