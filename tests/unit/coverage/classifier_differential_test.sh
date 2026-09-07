#!/usr/bin/env bash

# The awk rules and the Bash ones must agree on every line of every shell file
# in the repo. A disagreement moves coverage numbers silently, which is exactly
# what #1005 warned about when it reproduced the old regex quirk for quirk --
# so this compares them line by line rather than trusting either.
#
# Two rule sets share the walk, because both are per-line and both have a Bash
# reference with an awk mirror: whether a line is executable (#1005) and whether
# the statement on it continues onto the next one (#722, #1338). The scanner
# also carries state between lines, so the file's end state is compared too --
# and asserted clean, since real shell files balance their quotes.

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  LF="
"
}

# Reports every line of $1 with awk as "<lineno> <executable> <open>", then a
# final "end <stack> <heredoc>" holding the scanner state the file left behind.
# $2 overrides the rule source, which is how the mutation below is injected.
function awk_classification() { # $1 = file, $2 = optional rule source
  local rules="${2:-$(bashunit::coverage::awk_rules)}"
  local out status=0
  out=$(env LC_ALL=C "$AWK" "$rules"'
    BEGIN { bu_scan_reset() }
    { bu_scan_line($0); printf "%s %s %s\n", FNR, bu_is_executable($0), bu_scan_open() }
    END { printf "end %s %s\n", bu_scan_stack(), _bu_hd }
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

# Reports every line of $1 with the Bash reference, same format.
function bash_classification() { # $1 = file
  local lineno=0 line executable open
  bashunit::coverage::scan_reset
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    executable=0
    bashunit::coverage::is_executable_line "$line" "$lineno" && executable=1
    bashunit::coverage::scan_line "$line"
    open=0
    bashunit::coverage::scan_is_open && open=1
    printf '%s %s %s\n' "$lineno" "$executable" "$open"
  done <"$1"
  printf 'end %s %s\n' \
    "$_BASHUNIT_COVERAGE_SCAN_STACK" "$_BASHUNIT_COVERAGE_SCAN_HEREDOC"
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


function test_both_rule_sets_agree_on_every_shell_file_in_the_repo() {
  # 460 files, each an awk fork plus a Bash loop over its lines: 4.8s here,
  # but minutes under Git Bash, where the shard hung until CI cancelled it.
  # GNU awk (Ubuntu) and BusyBox awk (Alpine) both run this, which is what the
  # port needed proving against.
  bashunit::skip_on windows "460 awk forks per run takes minutes under Git Bash"

  local disagreements=""
  # A shell file that parses has every quote, parenthesis and heredoc closed by
  # the time it ends, so a leftover context is the scanner mis-reading real code
  # -- the check that the state machine is right, not merely mirrored (#1338).
  local unclean=""
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

    local end_state="${bash_out##*"$LF"}"
    if [ "$end_state" != "end  " ]; then
      unclean="$unclean
$file left $end_state"
    fi
  done

  assert_empty "$disagreements"
  assert_empty "$unclean"
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

function test_the_rule_sets_agree_on_the_quirk_cases() {
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
    # The scanner's own quirks: an array literal spans, a substitution does not,
    # and a quote is only a quote where the shell reads one (#1338).
    printf '%s\n' 'arr=('
    printf '%s\n' '  "one"'
    printf '%s\n' ')'
    printf '%s\n' "s='multi"
    printf '%s\n' "line'"
    printf '%s\n' "echo hi  # don't"
    printf '%s\n' 'y="$(f '"'"'a"b'"'"')"'
    printf '%s\n' 'cat <<-EOF'
    printf '\t%s\n' 'body'
    printf '\t%s\n' 'EOF'
    printf '%s\n' 'read -r v <<<"here"'
    printf '%s\n' 'x="$(' '  values=(' '    "one"' '    "two"' '  )' '  if false; then' '    : skipped' '  fi' ')"'
    printf '%s\n' 'x=(' '  <(' '    : command' '  )' ')'
    printf '%s\n' 'result="$(' '  case "$value" in' '    x)' '      if false; then' \
      '        echo skipped_case_child' '      fi' '      ;;' '  esac' ')"'
    printf '%s\n' 'result="$(' '  case x in' '    x) case y in' '      y) : ;;' \
      '    esac ;;' '    z)' '      if false; then' '        echo skipped_nested_case' \
      '      fi' '      ;;' '  esac' ')"'
    printf '%s\n' 'result="$(' '  case case in' '    case)' '      : arm' \
      '      ;;' '  esac' ')"'
    printf '%s\n' 'result="$(' '  case x in' '    (x) case y in' '      y) : ;;' \
      '    esac ;;' '  esac' ')"'
    printf '%s\n' 'result="$(' '  case z in (x) case y in' '    y) : ;;' \
      '  esac ;;' '  esac' ')"'
    printf '%s\n' 'result="$(' '  case z in' '    foo|esac)' '      : arm' \
      '      ;;' '  esac' ')"'
    printf '%s\n' 'result="$(' '  if case x in' '    x) false ;;' '  esac' \
      '  then :; fi' '  while case x in' '    x) false ;;' '  esac' \
      '  do :; done' '  until case x in' '    x) false ;;' '  esac' \
      '  do :; done' ')"'
    # shellcheck disable=SC1003  # literal trailing backslash in child command
    printf '%s\n' 'result="$(' '  printf ran \' ')"' 'result="$(' \
      '  if false; then' '    echo skipped_after_child_continuation' '  fi' ')"'
    # shellcheck disable=SC1003  # literal trailing backslash before heredoc
    printf '%s\n' 'return 0 <<EOF \' 'payload' 'EOF' 'echo after_heredoc'
    printf '%s\n' 'value=$((' '  case' '  + 1' '))' 'items=(' '  one' ')'
    printf '%s\n' 'case x in x) printf "%s" "esac" ;; esac'
    printf '%s\n' 'case x in x) :;;esac'
    printf '%s\n' 'case x in x) : ;; esac # comment ('
    printf '%s\n' 'x=$((1 << 2))' 'x="$((1 << 2))"' '((x = (1 << 2)))'
    printf '%s\n' 'x=$((1 <<(2 << 1)))' 'echo done'
    # shellcheck disable=SC1003  # literal backslash at the end of a comment
    printf '%s\n' 'echo ran # comment \' 'echo next'
  } >"$fixture"

  assert_same "$(bash_classification "$fixture")" "$(awk_classification "$fixture")"
}

# The scanner half of the differential needs its own mutation guard: a rule
# removed from the awk copy has to surface as a disagreement, not as an awk
# that refuses to run.
function test_the_differential_catches_a_broken_awk_scanner_rule() {
  local fixture
  fixture="$(bashunit::temp_file)"
  printf '%s\n' 'arr=(' '  "one"' ')' >"$fixture"

  local mutated_rules
  mutated_rules=$(bashunit::coverage::awk_rules |
    sed 's|(prev == "=") ? "A" : "P"|"P"|')

  local mutated reference
  mutated=$(awk_classification "$fixture" "$mutated_rules")
  reference=$(bash_classification "$fixture")

  assert_not_empty "$mutated"
  assert_not_equals "$reference" "$mutated"
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
