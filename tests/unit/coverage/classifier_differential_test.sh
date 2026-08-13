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
  local out status=0
  out=$(env LC_ALL=C "$AWK" "$rules"'
    { printf "%s %s\n", FNR, bu_is_executable($0) }
  ' "$1") || status=$?

  # An awk that failed prints nothing, and empty output is indistinguishable
  # from "every line classified differently" once it reaches the diff -- so a
  # transient fork failure under load reported as "the classifiers disagree",
  # which is the most alarming message this suite can produce and was not what
  # happened (#1143). Say which it was.
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


function test_both_classifiers_agree_on_every_shell_file_in_the_repo() {
  # 460 files, each an awk fork plus a Bash loop over its lines: 4.8s here,
  # but minutes under Git Bash, where the shard hung until CI cancelled it.
  # GNU awk (Ubuntu) and BusyBox awk (Alpine) both run this, which is what the
  # port needed proving against.
  bashunit::skip_on windows "460 awk forks per run takes minutes under Git Bash"

  local disagreements=""
  local file tmp_a tmp_b
  tmp_a=$(bashunit::temp_file cls_a)
  tmp_b=$(bashunit::temp_file cls_b)
  for file in $(cd "$ROOT_DIR" && git ls-files '*.sh'); do
    # `diff <(...) <(...)` cost a fork per file and, under a loaded parallel
    # suite, failed with "diff: /dev/fd/N: Bad file descriptor" -- whose stderr
    # then read as a rule disagreement naming an arbitrary file (#1152). Real
    # files instead, still written concurrently so the two sides overlap the
    # way the process substitutions did, and compared by the shell: $(<file)
    # costs no fork, and only a file that really differs pays for a diff.
    local bash_out awk_out diff_out
    bash_classification "$ROOT_DIR/$file" >"$tmp_a" &
    awk_classification "$ROOT_DIR/$file" >"$tmp_b"
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

# The differential compares two outputs, so anything that empties one of them
# reads as a total disagreement. A transient awk failure under CI load did
# exactly that, reporting "the classifiers disagree on every shell file" when
# nothing had disagreed (#1143).
function test_a_failing_awk_is_reported_as_a_failure_not_a_disagreement() {
  local out
  out=$(awk_classification "/definitely/not/a/file.sh")

  assert_contains "AWK-FAILED" "$out"
}
