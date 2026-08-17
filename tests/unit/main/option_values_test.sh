#!/usr/bin/env bash

# Anti-drift contract: bashunit::main::option_takes_value must know exactly the
# options cmd_test consumes a value for. `watch` uses it to tell an option's
# value apart from the path it polls, so an option missing from it silently
# becomes a watched directory rather than an error.
#
# The expected set is derived from cmd_test's own parser instead of being
# repeated here: an option takes a value there precisely when its case arm ends
# in an unconditional `shift`.

# Options whose case arm in the parse loop shifts. Two sources, because --suite
# is resolved by the pre-scan in apply_suites and removed from argv before the
# main loop sees it.
function option_values_expected() {
  {
    awk '/# Parse test-specific options/,/^  done$/' src/main/test.sh
    awk '/^function bashunit::main::apply_suites\(\)/,/^}$/' src/main/test.sh
  } |
    awk '
      /^[[:space:]]+--?[a-zA-Z][a-zA-Z0-9-]*( \| --?[a-zA-Z][a-zA-Z0-9-]*)*\)$/ {
        arm = $0
        sub(/\)$/, "", arm)
        gsub(/[[:space:]]/, "", arm)
        next
      }
      # Only an unconditional shift at the arm body indent counts: --debug
      # shifts one level deeper, inside a conditional, and takes an optional
      # value rather than a required one.
      /^      shift$/ { if (arm != "") print arm }
      /^[[:space:]]+;;$/ { arm = "" }
    ' |
    tr '|' '\n' | LC_ALL=C sort -u
}

# The options the predicate itself lists.
function option_values_declared() {
  awk '/^function bashunit::main::option_takes_value\(\)/,/^}$/' src/main/validate.sh |
    awk '/case /,/esac/' |
    grep -oE '(^|[ |])--?[a-zA-Z][a-zA-Z0-9-]*' |
    tr -d ' |' | LC_ALL=C sort -u
}

function test_the_predicate_knows_every_option_cmd_test_takes_a_value_for() {
  local missing=""
  local flag
  while IFS= read -r flag; do
    [ -z "$flag" ] && continue
    if ! bashunit::main::option_takes_value "$flag"; then
      missing="$missing $flag"
    fi
  done <<EOF
$(option_values_expected)
EOF

  assert_same "" "$missing"
}

# The other direction, so a removed option does not leave a stale entry that
# makes watch swallow the path after it.
function test_the_predicate_lists_nothing_cmd_test_does_not_take_a_value_for() {
  local expected
  expected="$(option_values_expected)"

  local stale=""
  local flag
  while IFS= read -r flag; do
    [ -z "$flag" ] && continue
    # Matched a whole line at a time: a plain substring test would find `-f`
    # inside `--filter` and hide a stale short option.
    case "
$expected
" in
    *"
$flag
"*) ;;
    *) stale="$stale $flag" ;;
    esac
  done <<EOF
$(option_values_declared)
EOF

  assert_same "" "$stale"
}

function test_a_valueless_option_is_not_reported_as_taking_one() {
  local wrong=""
  local flag
  for flag in --parallel --strict --simple --detailed --list --rerun-failed; do
    if bashunit::main::option_takes_value "$flag"; then
      wrong="$wrong $flag"
    fi
  done

  assert_same "" "$wrong"
}
