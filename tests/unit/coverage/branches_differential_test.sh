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
  local out status=0
  out=$(env LC_ALL=C "$AWK" "$scanner"'
    BEGIN { bu_br_reset() }
    { bu_br_line($0, FNR) }
    END {
      for (i = 1; i <= br_count; i++) {
        print br_dec[i] "|" br_kind[i] "|" br_arms[i]
      }
    }
  ' "$1") || status=$?

  # An awk that failed prints nothing, which diffs as "the scanners disagree
  # about every branch in the file" -- alarming, and not what happened. Say
  # which it was (#1143).
  if [ "$status" -ne 0 ]; then
    printf 'AWK-FAILED(exit %s) on %s\n' "$status" "$1"
    return 0
  fi

  # A file with no output must stay empty: printf '%s\n' "" emits a blank line,
  # which diffs against awk's genuine no-output as a disagreement.
  if [ -n "$out" ]; then
    printf '%s\n' "$out"
  fi
}

# Renders the difference between two strings, for the report of a file that
# really disagrees. Deliberately not used to *decide* agreement -- that cost a
# diff fork per file and dragged in the process substitutions that flake under
# load (#1152).
function diff_of() { # $1 = bash side, $2 = awk side
  local a b
  a=$(bashunit::temp_file diff_a)
  b=$(bashunit::temp_file diff_b)
  printf '%s\n' "$1" >"$a"
  printf '%s\n' "$2" >"$b"
  diff "$a" "$b" 2>&1 || true
}


function test_both_branch_scanners_agree_on_every_shell_file_in_the_repo() {
  # One awk fork per file plus a Bash loop over its lines: seconds here, but
  # minutes under Git Bash, where forks are slow enough to hang a shard.
  bashunit::skip_on windows "an awk fork per repo file takes minutes under Git Bash"

  local disagreements=""
  local file tmp_a tmp_b
  tmp_a=$(bashunit::temp_file br_a)
  tmp_b=$(bashunit::temp_file br_b)
  for file in $(cd "$ROOT_DIR" && git ls-files '*.sh'); do
    # `diff <(...) <(...)` cost a fork per file and, under a loaded parallel
    # suite, failed with "diff: /dev/fd/N: Bad file descriptor" -- whose stderr
    # then read as a disagreement naming an arbitrary file (#1152). Real files
    # instead, still written concurrently so the two sides overlap the way the
    # process substitutions did, and compared by the shell: $(<file) costs no
    # fork, and only a file that really differs pays for a diff.
    local bash_out awk_out diff_out
    bashunit::coverage::extract_branches "$ROOT_DIR/$file" >"$tmp_a" &
    awk_branches "$ROOT_DIR/$file" >"$tmp_b"
    wait
    bash_out=$(<"$tmp_a")
    awk_out=$(<"$tmp_b")

    if [ "$bash_out" != "$awk_out" ]; then
      diff_out=$(diff_of "$bash_out" "$awk_out")
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

# Same diagnostic gap as the line classifier's: empty output from a failed awk
# is indistinguishable from a total disagreement once it reaches the diff.
function test_a_failing_awk_is_reported_as_a_failure_not_a_disagreement() {
  local out
  out=$(awk_branches "/definitely/not/a/file.sh")

  assert_contains "AWK-FAILED" "$out"
}
