#!/usr/bin/env bash

# Helper to mark assertion as failed and set the guard flag
function bashunit::assert::mark_failed() {
  # While a bashunit::assert_once marker absorbs this assertion, neither the
  # counter nor the guard moves: the marker's flush reports the single verdict,
  # and leaving the guard clear lets the rest of the composed assertion run.
  if [ "${_BASHUNIT_ASSERT_ONCE_ACTIVE:-0}" -eq 1 ]; then
    if bashunit::assert::once_is_absorbing; then
      _BASHUNIT_ASSERT_ONCE_FAILED=1
      return 0
    fi
  fi
  bashunit::state::add_assertions_failed
  bashunit::state::mark_assertion_failed_in_test
}

# Guard clause to skip assertion if one already failed in test (when stop-on-assertion is enabled)
function bashunit::assert::should_skip() {
  bashunit::env::is_stop_on_assertion_failure_enabled && ((_BASHUNIT_ASSERTION_FAILED_IN_TEST))
}

# Emits a machine-detectable assertion usage error. The runner strips the
# prefix and reports the message through the existing Error channel.
##
# Emits a machine-detectable assertion usage error for an argument of the wrong
# *shape*, as opposed to a missing one. Same prefix as usage_error, so the
# runner strips it and reports through the existing Error channel.
# Arguments: $1 - assertion name, $2 - the rest of the sentence
##
function bashunit::assert::usage_error_detail() {
  local assertion=$1
  local detail=$2

  printf 'bashunit: assertion usage error: %s %s\n' "$assertion" "$detail" >&2
}

function bashunit::assert::usage_error() {
  local assertion=$1
  local required=$2
  local signature=$3
  local supplied=$4

  printf 'bashunit: assertion usage error: %s expects %s arguments (%s), got %s\n' \
    "$assertion" "$required" "$signature" "$supplied" >&2
}

_BASHUNIT_ASSERT_LABEL_OUT=""

# Resolve assertion label into the slot _BASHUNIT_ASSERT_LABEL_OUT with no fork:
# use custom label if provided, otherwise derive from the test function name.
#
# $2 is the frame to fall back to when no test_* function is on the stack. It
# defaults to 2 (the caller of this function), so any wrapper that adds a frame
# between the assertion and this call must pass its own depth -- otherwise the
# fallback reports the wrapper's name instead of the assertion's.
# Arguments: $1 - custom label (optional), $2 - fallback depth (default 2)
function bashunit::assert::label_to_slot() {
  local custom_label="${1:-}"
  local fallback_depth="${2:-2}"
  if [ -n "$custom_label" ]; then
    _BASHUNIT_ASSERT_LABEL_OUT=$custom_label
    return
  fi
  bashunit::helper::find_test_function_name_to_slot "$fallback_depth"
  bashunit::helper::normalize_test_function_name_to_slot "$_BASHUNIT_HELPER_TESTFN_OUT"
  _BASHUNIT_ASSERT_LABEL_OUT=$_BASHUNIT_HELPER_NORMALIZED_OUT
}

##
# Reports an assertion failure: resolves the label, marks the assertion failed
# and prints the standard "Expected / <condition>" block. Collapses the
# label_to_slot + mark_failed + print_failed_test sequence every assertion
# repeats.
#
# The fallback depth is 3, not label_to_slot's default 2, to account for this
# extra stack frame: when no test_* frame is on the stack the label must still
# resolve to the *assertion* that called this helper. Guarded by the
# "labelled with its own name" tests in
# tests/acceptance/bashunit_hook_failure_test.sh.
#
# Arguments: $1 - label override (empty to derive), $2 - expected, $3 - failure
#            condition message, $4 - actual, $5 - extra key (optional),
#            $6 - extra value (optional)
##
function bashunit::assert::fail_with() {
  bashunit::assert::label_to_slot "${1:-}" 3
  bashunit::assert::mark_failed
  bashunit::console_results::print_failed_test \
    "$_BASHUNIT_ASSERT_LABEL_OUT" "${2-}" "${3-}" "${4-}" "${5-}" "${6-}"
}

_BASHUNIT_ASSERT_JOINED_OUT=""

# Join positional args into _BASHUNIT_ASSERT_JOINED_OUT with no fork.
# Output matches $(printf '%s\n' "$@") exactly: newline-joined, trailing
# newlines stripped (as command substitution strips them).
# Callers pass their variadic "actual" as "${arr[@]+"${arr[@]}"}": an assertion
# invoked with no actual value leaves that array empty, and a bare
# "${arr[@]}" on an empty array is an unbound-variable error under `set -u`
# (i.e. --strict) on Bash < 4.4. The guard makes an empty actual join to ""
# on every supported Bash instead of aborting the test only on Bash 3.x.
function bashunit::assert::join_to_slot() {
  local IFS=$'\n'
  local joined="$*"
  while [ "$joined" != "${joined%$'\n'}" ]; do
    joined="${joined%$'\n'}"
  done
  _BASHUNIT_ASSERT_JOINED_OUT=$joined
}

# Resolve assertion label: use custom label if provided, otherwise derive from test function name
function bashunit::assert::label() {
  bashunit::assert::label_to_slot "${1:-}"
  builtin echo "$_BASHUNIT_ASSERT_LABEL_OUT"
}

function bashunit::fail() {
  bashunit::assert::should_skip && return 0

  local message="${1:-${FUNCNAME[1]}}"

  bashunit::helper::find_test_function_name_to_slot
  bashunit::helper::normalize_test_function_name_to_slot "$_BASHUNIT_HELPER_TESTFN_OUT"
  local label=$_BASHUNIT_HELPER_NORMALIZED_OUT
  bashunit::assert::mark_failed
  bashunit::console_results::print_failure_message "${label}" "$message"
}

_BASHUNIT_ASSERT_BOOL_EXIT_OUT=0

##
# Runs the subject of assert_true / assert_false and leaves its exit code in
# _BASHUNIT_ASSERT_BOOL_EXIT_OUT.
#
# With more than one argument the arguments are passed through as arguments --
# no re-parsing, so a path containing a space survives. With exactly one they go
# through run_command_or_eval, which is the historical behaviour: a bare command
# word, or an `eval `-prefixed string. Keeping that split is what makes the
# variadic form purely additive.
#
# The `|| exit_code=$?` capture is deliberate: a bare failing command as a
# statement would abort the whole test under --strict (`set -e`).
##
function bashunit::assert::_run_bool_subject() {
  local exit_code=0

  if [ $# -gt 1 ]; then
    "$@" >/dev/null 2>&1 || exit_code=$?
  else
    bashunit::run_command_or_eval "$1" || exit_code=$?
  fi

  _BASHUNIT_ASSERT_BOOL_EXIT_OUT=$exit_code
}

_BASHUNIT_ASSERT_EXIT_DESC_OUT=""

##
# Describes a failing exit code for assert_true / assert_false. 127 and 126 are
# the two codes the shell reserves for "I could not run this at all", and a bare
# number tells the reader nothing: the most natural shell idiom,
# `assert_true "[ -d /tmp ]"`, hits 127 because the argument is run as a command
# word rather than evaluated, and the failure used to point nowhere near the
# cause.
#
# The wording avoided the literal phrase "command not found" because
# runner/diagnostics.sh used to classify a test as a runtime error by scanning
# its output for that exact string, which made every such failure report as both
# Failed and Error. That constraint is gone -- the classifier now requires a
# shell diagnostic's source-and-line prefix as well (#992). The phrasing stays
# as it is because it is already documented and released, not because it must.
# Arguments: $1 - exit code, $2 - the command as written
##
function bashunit::assert::_describe_exit_code() {
  case "$1" in
  127) _BASHUNIT_ASSERT_EXIT_DESC_OUT="unknown command: $2" ;;
  126) _BASHUNIT_ASSERT_EXIT_DESC_OUT="not executable: $2" ;;
  *) _BASHUNIT_ASSERT_EXIT_DESC_OUT="exit code: $1" ;;
  esac
}

function assert_true() {
  bashunit::assert::should_skip && return 0

  local actual="$1"

  # The literal values only mean themselves when they are the whole subject;
  # with arguments following, "true" is the command named true.
  if [ $# -eq 1 ]; then
    case "$actual" in
    "")
      bashunit::handle_bool_assertion_failure "true or 0" "$actual"
      return
      ;;
    "true" | "0")
      bashunit::state::add_assertions_passed
      return
      ;;
    "false" | "1")
      bashunit::handle_bool_assertion_failure "true or 0" "$actual"
      return
      ;;
    esac
  fi

  bashunit::assert::_run_bool_subject "$@"
  local exit_code=$_BASHUNIT_ASSERT_BOOL_EXIT_OUT
  actual="$*"

  if [ "$exit_code" -ne 0 ]; then
    bashunit::assert::_describe_exit_code "$exit_code" "$actual"
    bashunit::handle_bool_assertion_failure \
      "command or function with zero exit code" "$_BASHUNIT_ASSERT_EXIT_DESC_OUT"
  else
    bashunit::state::add_assertions_passed
  fi
}

function assert_false() {
  bashunit::assert::should_skip && return 0

  local actual="$1"

  # As in assert_true: the literal values only mean themselves when they are the
  # whole subject.
  if [ $# -eq 1 ]; then
    case "$actual" in
    "")
      bashunit::handle_bool_assertion_failure "false or 1" "$actual"
      return
      ;;
    "false" | "1")
      bashunit::state::add_assertions_passed
      return
      ;;
    "true" | "0")
      bashunit::handle_bool_assertion_failure "false or 1" "$actual"
      return
      ;;
    esac
  fi

  bashunit::assert::_run_bool_subject "$@"
  local exit_code=$_BASHUNIT_ASSERT_BOOL_EXIT_OUT
  actual="$*"

  # 127/126 mean the command never ran. Treating "did not run" as "returned
  # false" let a typo in the command name satisfy this assertion while testing
  # nothing, so those are failures here as well as in assert_true.
  case "$exit_code" in
  0 | 126 | 127)
    bashunit::assert::_describe_exit_code "$exit_code" "$actual"
    bashunit::handle_bool_assertion_failure \
      "command or function with non-zero exit code" "$_BASHUNIT_ASSERT_EXIT_DESC_OUT"
    ;;
  *) bashunit::state::add_assertions_passed ;;
  esac
}

function bashunit::run_command_or_eval() {
  local cmd="$1"

  case "$cmd" in
  eval\ * | eval)
    eval "${cmd#eval }" &>/dev/null
    ;;
  *[=[:space:]]* | "")
    # An alias name never contains "=" or whitespace, so this can't be an alias
    # invocation: run it directly. Guarding here also stops `alias -- "$cmd"`
    # below from *defining* an alias as a side effect when "$cmd" looks like
    # "name=value" (which would wrongly succeed).
    "$cmd" &>/dev/null
    ;;
  *)
    # Detect aliases with the `alias` builtin instead of forking
    # `command -v | grep`: it exits 0 only for a defined alias, matching the
    # old `^alias` check for functions/binaries/unknown commands (all non-zero).
    if alias -- "$cmd" >/dev/null 2>&1; then
      eval "$cmd" &>/dev/null
    else
      "$cmd" &>/dev/null
    fi
    ;;
  esac
  return $?
}

function bashunit::handle_bool_assertion_failure() {
  local expected="$1"
  local got="$2"
  bashunit::helper::find_test_function_name_to_slot
  bashunit::helper::normalize_test_function_name_to_slot "$_BASHUNIT_HELPER_TESTFN_OUT"
  local label=$_BASHUNIT_HELPER_NORMALIZED_OUT

  bashunit::assert::mark_failed
  bashunit::console_results::print_failed_test "$label" "$expected" "but got " "$got"
}

function assert_same() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  if [ "$expected" != "$actual" ]; then
    bashunit::assert::fail_with "${label_override:-}" "${expected}" "but got " "${actual}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_equals() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  bashunit::str::strip_ansi_to_slot "$actual"
  local actual_cleaned=$_BASHUNIT_STR_STRIPPED_OUT
  bashunit::str::strip_ansi_to_slot "$expected"
  local expected_cleaned=$_BASHUNIT_STR_STRIPPED_OUT

  if [ "$expected_cleaned" != "$actual_cleaned" ]; then
    bashunit::assert::fail_with "${label_override:-}" "${expected_cleaned}" "but got " "${actual_cleaned}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_not_equals() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  bashunit::str::strip_ansi_to_slot "$actual"
  local actual_cleaned=$_BASHUNIT_STR_STRIPPED_OUT
  bashunit::str::strip_ansi_to_slot "$expected"
  local expected_cleaned=$_BASHUNIT_STR_STRIPPED_OUT

  if [ "$expected_cleaned" = "$actual_cleaned" ]; then
    bashunit::assert::fail_with "${label_override:-}" "${expected_cleaned}" "to not be" "${actual_cleaned}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_empty() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local label_override="${2:-}"

  if [ "$expected" != "" ]; then
    bashunit::assert::fail_with "${label_override:-}" "to be empty" "but got " "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_not_empty() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local label_override="${2:-}"

  if [ "$expected" = "" ]; then
    bashunit::assert::fail_with "${label_override:-}" "to not be empty" "but got " "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_not_same() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  if [ "$expected" = "$actual" ]; then
    bashunit::assert::fail_with "${label_override:-}" "${expected}" "to not be" "${actual}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_contains() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi
  local IFS=$' \t\n'

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  local label_override=""
  bashunit::assert::join_to_slot "${actual_arr[@]+"${actual_arr[@]}"}"
  local actual=$_BASHUNIT_ASSERT_JOINED_OUT

  case "$actual" in
  *"$expected"*) ;;
  *)
    bashunit::assert::fail_with "${label_override:-}" "${actual}" "to contain" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

##
# Whether `shopt -s nocasematch` exists. Introduced in Bash 3.1; bashunit's
# floor is 3.0, so the caller keeps a tr-based fallback for that one version.
# Returns: 0 when nocasematch is available (Bash >= 3.1), 1 otherwise.
##
function bashunit::assert::_supports_nocasematch() {
  if [ "${BASH_VERSINFO[0]:-0}" -gt 3 ]; then
    return 0
  fi
  [ "${BASH_VERSINFO[0]:-0}" -eq 3 ] && [ "${BASH_VERSINFO[1]:-0}" -ge 1 ]
}

function assert_contains_ignore_case() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  # nocasematch (Bash 3.1+) folds case inside the `case` itself, which costs no
  # fork at all; the two `tr` pipelines below cost two. Measured on Bash 3.2:
  # 0.087ms per call versus 12.8ms. Both fold non-ASCII identically in a UTF-8
  # locale -- `ñü` matches `ÑÜ` either way -- which rules out the tempting
  # pure-bash A-Z loop, since that is ASCII-only and would silently stop
  # matching accented text that matches today.
  #
  # Prior state is saved and restored rather than blindly unset: nocasematch is
  # a global shell option and a user's test file may already have set it. `shopt
  # -q` is a builtin, so the save costs nothing.
  if bashunit::assert::_supports_nocasematch; then
    local nocase_was_set=1
    shopt -q nocasematch || nocase_was_set=0
    shopt -s nocasematch

    local matched=1
    case "$actual" in
    *"$expected"*) ;;
    *) matched=0 ;;
    esac

    [ "$nocase_was_set" -eq 1 ] || shopt -u nocasematch

    if [ "$matched" -eq 0 ]; then
      bashunit::assert::fail_with "${label_override:-}" "${actual}" "to contain" "${expected}"
      return
    fi

    bashunit::state::add_assertions_passed
    return
  fi

  # Bash 3.0 only: nocasematch does not exist, so fold with tr.
  local expected_lower
  local actual_lower
  expected_lower=$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')
  actual_lower=$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')

  case "$actual_lower" in
  *"$expected_lower"*) ;;
  *)
    bashunit::assert::fail_with "${label_override:-}" "${actual}" "to contain" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

function assert_not_contains() {
  local label_override=""
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi
  local IFS=$' \t\n'

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  bashunit::assert::join_to_slot "${actual_arr[@]+"${actual_arr[@]}"}"
  local actual=$_BASHUNIT_ASSERT_JOINED_OUT

  case "$actual" in
  *"$expected"*)
    bashunit::assert::fail_with "${label_override:-}" "${actual}" "to not contain" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

function assert_matches() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "pattern, actual" "$#"
    return 2
  fi
  local IFS=$' \t\n'

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  bashunit::assert::join_to_slot "${actual_arr[@]+"${actual_arr[@]}"}"
  local actual=$_BASHUNIT_ASSERT_JOINED_OUT

  if [ "$(printf '%s' "$actual" | "$GREP" -cE "$expected" || true)" -eq 0 ]; then
    # Retry with newlines collapsed for cross-line patterns
    if [ "$(printf '%s' "$actual" | tr '\n' ' ' | "$GREP" -cE "$expected" || true)" -eq 0 ]; then
      bashunit::helper::find_test_function_name_to_slot
      bashunit::helper::normalize_test_function_name_to_slot "$_BASHUNIT_HELPER_TESTFN_OUT"
      local label=$_BASHUNIT_HELPER_NORMALIZED_OUT
      bashunit::assert::mark_failed
      bashunit::console_results::print_failed_test "${label}" "${actual}" "to match" "${expected}"
      return
    fi
  fi

  bashunit::state::add_assertions_passed
}

function assert_not_matches() {
  local label_override=""
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "pattern, actual" "$#"
    return 2
  fi
  local IFS=$' \t\n'

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  bashunit::assert::join_to_slot "${actual_arr[@]+"${actual_arr[@]}"}"
  local actual=$_BASHUNIT_ASSERT_JOINED_OUT

  # Check both line-by-line and with newlines collapsed for cross-line patterns
  if [ "$(printf '%s' "$actual" | "$GREP" -cE "$expected" || true)" -gt 0 ] ||
    [ "$(printf '%s' "$actual" | tr '\n' ' ' | "$GREP" -cE "$expected" || true)" -gt 0 ]; then
    bashunit::assert::fail_with "${label_override:-}" "${actual}" "to not match" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_exec() {
  bashunit::assert::should_skip && return 0
  local label_override=""

  local cmd="$1"
  shift

  local expected_exit=0
  local expected_stdout=""
  local expected_stderr=""
  local stdout_needle=""
  local stdout_no_needle=""
  local stderr_needle=""
  local stderr_no_needle=""
  local stdin_input=""
  local check_stdout=false
  local check_stderr=false
  local check_stdout_contains=false
  local check_stdout_not_contains=false
  local check_stderr_contains=false
  local check_stderr_not_contains=false
  local check_stdin=false

  while [ $# -gt 0 ]; do
    case "$1" in
    --exit)
      expected_exit="$2"
      shift 2
      ;;
    --stdout)
      expected_stdout="$2"
      check_stdout=true
      shift 2
      ;;
    --stderr)
      expected_stderr="$2"
      check_stderr=true
      shift 2
      ;;
    --stdout-contains)
      stdout_needle="$2"
      check_stdout_contains=true
      shift 2
      ;;
    --stdout-not-contains)
      stdout_no_needle="$2"
      check_stdout_not_contains=true
      shift 2
      ;;
    --stderr-contains)
      stderr_needle="$2"
      check_stderr_contains=true
      shift 2
      ;;
    --stderr-not-contains)
      stderr_no_needle="$2"
      check_stderr_not_contains=true
      shift 2
      ;;
    --stdin)
      stdin_input="$2"
      check_stdin=true
      shift 2
      ;;
    *)
      shift
      ;;
    esac
  done

  local stdout_file stderr_file
  stdout_file=$("$MKTEMP")
  stderr_file=$("$MKTEMP")

  if $check_stdin; then
    local stdin_file
    stdin_file=$("$MKTEMP")
    printf '%s' "$stdin_input" >"$stdin_file"
    eval "$cmd" <"$stdin_file" >"$stdout_file" 2>"$stderr_file"
    local exit_code=$?
    rm -f "$stdin_file"
  else
    eval "$cmd" >"$stdout_file" 2>"$stderr_file"
    local exit_code=$?
  fi

  local stdout
  stdout=$(cat "$stdout_file")
  local stderr
  stderr=$(cat "$stderr_file")

  rm -f "$stdout_file" "$stderr_file"

  local expected_desc="exit: $expected_exit"
  local actual_desc="exit: $exit_code"
  local failed=0

  if [ "$exit_code" -ne "$expected_exit" ]; then
    failed=1
  fi

  if $check_stdout; then
    expected_desc="$expected_desc"$'\n'"stdout: $expected_stdout"
    actual_desc="$actual_desc"$'\n'"stdout: $stdout"
    if [ "$stdout" != "$expected_stdout" ]; then
      failed=1
    fi
  fi

  if $check_stdout_contains; then
    expected_desc="$expected_desc"$'\n'"stdout contains: $stdout_needle"
    actual_desc="$actual_desc"$'\n'"stdout: $stdout"
    case "$stdout" in
    *"$stdout_needle"*) ;;
    *) failed=1 ;;
    esac
  fi

  if $check_stdout_not_contains; then
    expected_desc="$expected_desc"$'\n'"stdout not contains: $stdout_no_needle"
    actual_desc="$actual_desc"$'\n'"stdout: $stdout"
    case "$stdout" in
    *"$stdout_no_needle"*) failed=1 ;;
    esac
  fi

  if $check_stderr; then
    expected_desc="$expected_desc"$'\n'"stderr: $expected_stderr"
    actual_desc="$actual_desc"$'\n'"stderr: $stderr"
    if [ "$stderr" != "$expected_stderr" ]; then
      failed=1
    fi
  fi

  if $check_stderr_contains; then
    expected_desc="$expected_desc"$'\n'"stderr contains: $stderr_needle"
    actual_desc="$actual_desc"$'\n'"stderr: $stderr"
    case "$stderr" in
    *"$stderr_needle"*) ;;
    *) failed=1 ;;
    esac
  fi

  if $check_stderr_not_contains; then
    expected_desc="$expected_desc"$'\n'"stderr not contains: $stderr_no_needle"
    actual_desc="$actual_desc"$'\n'"stderr: $stderr"
    case "$stderr" in
    *"$stderr_no_needle"*) failed=1 ;;
    esac
  fi

  if [ "$failed" -eq 1 ]; then
    bashunit::assert::fail_with "${label_override:-}" "$expected_desc" "but got " "$actual_desc"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_exit_code() {
  local actual_exit_code=${3-"$?"} # Capture $? before guard check
  local label_override=""
  bashunit::assert::should_skip && return 0

  local expected_exit_code="$1"

  # State the PASS condition and negate it. `[ -eq ]` exits 2 (not 1) on a
  # non-integer operand, so the old `[ -ne ]` form read that error as "equal"
  # and counted the assertion as passed. Negating makes unparseable input
  # fail closed, matching the `! [ -lt ]` form of the comparison assertions.
  if ! [ "$actual_exit_code" -eq "$expected_exit_code" ]; then
    bashunit::assert::fail_with "${label_override:-}" "${actual_exit_code}" "to be" "${expected_exit_code}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_successful_code() {
  local actual_exit_code=${3-"$?"} # Capture $? before guard check
  local label_override=""
  bashunit::assert::should_skip && return 0

  local expected_exit_code=0

  # Negated pass condition: see assert_exit_code.
  if ! [ "$actual_exit_code" -eq "$expected_exit_code" ]; then
    bashunit::assert::fail_with "${label_override:-}" \
      "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_unsuccessful_code() {
  local actual_exit_code=${3-"$?"} # Capture $? before guard check
  local label_override=""
  bashunit::assert::should_skip && return 0

  # Negated pass condition: see assert_exit_code.
  if ! [ "$actual_exit_code" -ne 0 ]; then
    bashunit::assert::fail_with "${label_override:-}" "${actual_exit_code}" "to be non-zero" "but was 0"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_general_error() {
  local actual_exit_code=${3-"$?"} # Capture $? before guard check
  local label_override=""
  bashunit::assert::should_skip && return 0

  local expected_exit_code=1

  # Negated pass condition: see assert_exit_code.
  if ! [ "$actual_exit_code" -eq "$expected_exit_code" ]; then
    bashunit::assert::fail_with "${label_override:-}" \
      "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  bashunit::state::add_assertions_passed
}

##
# Reports an error unless the command resolves through
# bashunit::is_command_available, so builtins and shell functions count as
# available exactly as they do for that helper. The command is resolved, never
# executed.
# Arguments: $1 - command, $2 - label override (optional)
##
function assert_command_available() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 1 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 1 "command" "$#"
    return 2
  fi

  local command="$1"
  local label_override="${2:-}"

  if ! bashunit::is_command_available "$command"; then
    bashunit::assert::fail_with "${label_override:-}" \
      "${command}" "to be available but was" "not found"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_command_not_found() {
  local actual_exit_code=${3-"$?"} # Capture $? before guard check
  local label_override=""
  bashunit::assert::should_skip && return 0

  local expected_exit_code=127

  # Negated pass condition: see assert_exit_code.
  if ! [ "$actual_exit_code" -eq "$expected_exit_code" ]; then
    bashunit::assert::fail_with "${label_override:-}" \
      "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_string_starts_with() {
  local label_override=""
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi
  local IFS=$' \t\n'

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  bashunit::assert::join_to_slot "${actual_arr[@]+"${actual_arr[@]}"}"
  local actual=$_BASHUNIT_ASSERT_JOINED_OUT

  case "$actual" in
  "$expected"*) ;;
  *)
    bashunit::assert::fail_with "${label_override:-}" "${actual}" "to start with" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

function assert_string_not_starts_with() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  case "$actual" in
  "$expected"*)
    bashunit::assert::fail_with "${label_override:-}" "${actual}" "to not start with" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

function assert_string_ends_with() {
  local label_override=""
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi
  local IFS=$' \t\n'

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  bashunit::assert::join_to_slot "${actual_arr[@]+"${actual_arr[@]}"}"
  local actual=$_BASHUNIT_ASSERT_JOINED_OUT

  case "$actual" in
  *"$expected") ;;
  *)
    bashunit::assert::fail_with "${label_override:-}" "${actual}" "to end with" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

function assert_string_not_ends_with() {
  local label_override=""
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi
  local IFS=$' \t\n'

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  bashunit::assert::join_to_slot "${actual_arr[@]+"${actual_arr[@]}"}"
  local actual=$_BASHUNIT_ASSERT_JOINED_OUT

  case "$actual" in
  *"$expected")
    bashunit::assert::fail_with "${label_override:-}" "${actual}" "to not end with" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

function assert_less_than() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  if ! [ "$actual" -lt "$expected" ]; then
    bashunit::assert::fail_with "${label_override:-}" "${actual}" "to be less than" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_less_or_equal_than() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  if ! [ "$actual" -le "$expected" ]; then
    bashunit::assert::fail_with "${label_override:-}" "${actual}" "to be less or equal than" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_greater_than() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  if ! [ "$actual" -gt "$expected" ]; then
    bashunit::assert::fail_with "${label_override:-}" "${actual}" "to be greater than" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_greater_or_equal_than() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  if ! [ "$actual" -ge "$expected" ]; then
    bashunit::assert::fail_with "${label_override:-}" "${actual}" "to be greater or equal than" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

##
# Asserts that a numeric value falls inside an inclusive range.
# Arguments: $1 - minimum, $2 - maximum, $3 - actual, $4 - label (optional)
# Returns: 0 after reporting the assertion, 2 for invalid input
##
function assert_between() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 3 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 3 "min, max, actual" "$#"
    return 2
  fi

  local min="$1"
  local max="$2"
  local actual="$3"
  local label_override="${4:-}"

  if ! bashunit::assert::_validate_range_args "${FUNCNAME[0]}" "$min" "$max" "$actual"; then
    return 2
  fi

  if ! bashunit::math::is_le "$min" "$actual"; then
    bashunit::assert::fail_with "$label_override" "$actual" "to be between" "$min and $max" \
      "Violated lower bound" "$min"
    return
  fi

  if ! bashunit::math::is_le "$actual" "$max"; then
    bashunit::assert::fail_with "$label_override" "$actual" "to be between" "$min and $max" \
      "Violated upper bound" "$max"
    return
  fi

  bashunit::state::add_assertions_passed
}

##
# Asserts that a numeric value falls outside an inclusive range.
# Arguments: $1 - minimum, $2 - maximum, $3 - actual, $4 - label (optional)
# Returns: 0 after reporting the assertion, 2 for invalid input
##
function assert_not_between() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 3 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 3 "min, max, actual" "$#"
    return 2
  fi

  local min="$1"
  local max="$2"
  local actual="$3"
  local label_override="${4:-}"

  if ! bashunit::assert::_validate_range_args "${FUNCNAME[0]}" "$min" "$max" "$actual"; then
    return 2
  fi

  if bashunit::math::is_le "$min" "$actual" && bashunit::math::is_le "$actual" "$max"; then
    bashunit::assert::fail_with "$label_override" "$actual" "to not be between" "$min and $max"
    return
  fi

  bashunit::state::add_assertions_passed
}

##
# Whether a value looks like a number (integer or decimal, optional sign).
# Returns: 0 when numeric, 1 otherwise.
##
function bashunit::assert::_is_numeric() {
  local value="$1"
  case "$value" in
  '' | *[!0-9.+-]*) return 1 ;;
  -*) value=${value#-} ;;
  +*) value=${value#+} ;;
  esac

  case "$value" in
  '' | '.' | *[+-]*) return 1 ;;
  *.*)
    local fraction=${value#*.}
    case "$fraction" in *.*) return 1 ;; esac
    ;;
  esac

  case "$value" in
  *[0-9]*) return 0 ;;
  esac
  return 1
}

##
# Validates the shared numeric-range contract.
# Arguments: $1 - assertion name, $2 - min, $3 - max, $4 - actual
# Returns: 0 when valid, 1 after emitting a usage error otherwise
##
function bashunit::assert::_validate_range_args() {
  local assertion=$1
  local min=$2
  local max=$3
  local actual=$4

  if ! bashunit::assert::_is_numeric "$min" ||
    ! bashunit::assert::_is_numeric "$max" ||
    ! bashunit::assert::_is_numeric "$actual"; then
    bashunit::assert::usage_error_detail "$assertion" \
      "expects numeric min, max, and actual values, got '$min', '$max', '$actual'"
    return 1
  fi

  if ! bashunit::math::is_le "$min" "$max"; then
    bashunit::assert::usage_error_detail "$assertion" "expects min <= max, got '$min' and '$max'"
    return 1
  fi
}

##
# Asserts the actual value is within +/- delta of the expected value:
# |actual - expected| <= delta. Supports floats via bashunit::math::calculate.
# Arguments: $1 - expected, $2 - actual, $3 - delta
##
function assert_within_delta() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 3 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 3 "expected, actual, delta" "$#"
    return 2
  fi

  local expected="$1"
  local actual="$2"
  local delta="$3"

  if ! bashunit::assert::_is_numeric "$expected" ||
    ! bashunit::assert::_is_numeric "$actual" ||
    ! bashunit::assert::_is_numeric "$delta"; then
    bashunit::assert::fail_with "" "${expected} ${actual} ${delta}" \
      "to all be numeric" "but got a non-numeric value"
    return
  fi

  # A leading `+` is valid to _is_numeric but not to bc, which returns an empty
  # string for `+5 - 5` and made the comparison below fail. Stripped once here so
  # both the fixed-point path and the bc/awk fallback see a plain number.
  expected=${expected#+}
  actual=${actual#+}
  delta=${delta#+}

  # Fork-free path: bring all three operands to one decimal scale, then compare
  # as integers. The bc/awk chain below costs a subshell plus a process, twice,
  # on a per-assertion path. bc also cannot parse a leading `+`, which
  # _is_numeric accepts, so `assert_within_delta +5 5 1` used to fail with an
  # empty comparison result rather than pass.
  local scale expected_places actual_places delta_places
  bashunit::math::decimals_to_slot "$expected"
  expected_places=$_BASHUNIT_MATH_DECIMALS_OUT
  bashunit::math::decimals_to_slot "$actual"
  actual_places=$_BASHUNIT_MATH_DECIMALS_OUT
  bashunit::math::decimals_to_slot "$delta"
  delta_places=$_BASHUNIT_MATH_DECIMALS_OUT
  scale=$expected_places
  if [ "$actual_places" -gt "$scale" ]; then
    scale=$actual_places
  fi
  if [ "$delta_places" -gt "$scale" ]; then
    scale=$delta_places
  fi

  local padded_expected padded_actual padded_delta
  bashunit::math::pad_to_slot "$expected" "$scale"
  padded_expected=$_BASHUNIT_MATH_PADDED_OUT
  bashunit::math::pad_to_slot "$actual" "$scale"
  padded_actual=$_BASHUNIT_MATH_PADDED_OUT
  bashunit::math::pad_to_slot "$delta" "$scale"
  padded_delta=$_BASHUNIT_MATH_PADDED_OUT

  if bashunit::math::scale_pair_to_slots "$padded_expected" "$padded_actual"; then
    local scaled_diff=$((_BASHUNIT_MATH_SCALED_L_OUT - _BASHUNIT_MATH_SCALED_R_OUT))
    if [ "$scaled_diff" -lt 0 ]; then
      scaled_diff=$((-scaled_diff))
    fi
    if bashunit::math::scale_pair_to_slots "$padded_delta" "$padded_expected"; then
      if [ "$scaled_diff" -gt "$_BASHUNIT_MATH_SCALED_L_OUT" ]; then
        bashunit::assert::fail_with "" "${actual}" "to be within ${delta} of" "${expected}"
        return
      fi

      bashunit::state::add_assertions_passed
      return
    fi
  fi

  local diff
  diff="$(bashunit::math::calculate "$expected - $actual")"
  case "$diff" in
  -*) diff="${diff#-}" ;;
  esac

  if [ "$(bashunit::math::calculate "$diff <= $delta")" != "1" ]; then
    bashunit::assert::fail_with "" "${actual}" "to be within ${delta} of" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_line_count() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "expected, actual" "$#"
    return 2
  fi
  local IFS=$' \t\n'

  local expected="$1"
  local -a input_arr
  input_arr=("${@:2}")
  local label_override=""
  local input_str
  input_str=$(printf '%s\n' ${input_arr+"${input_arr[@]}"})

  if [ -z "$input_str" ]; then
    local actual=0
  else
    # Count lines without forking: one line plus each real newline, plus each
    # literal "\n" (backslash-n) escape, which counts as an extra line break.
    local actual=1
    local _rest="$input_str"
    while [ "$_rest" != "${_rest#*$'\n'}" ]; do
      _rest="${_rest#*$'\n'}"
      actual=$((actual + 1))
    done
    _rest="$input_str"
    while [ "$_rest" != "${_rest#*\\n}" ]; do
      _rest="${_rest#*\\n}"
      actual=$((actual + 1))
    done
  fi

  if [ "$expected" != "$actual" ]; then
    bashunit::assert::fail_with "${label_override:-}" "${input_str}" \
      "to contain number of lines equal to" "${expected}" \
      "but found" "${actual}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function bashunit::format_to_regex() {
  local format="$1"
  local regex=""
  local i=0
  local len=${#format}

  while [ $i -lt "$len" ]; do
    local char="${format:$i:1}"
    if [ "$char" = "%" ] && [ $((i + 1)) -lt "$len" ]; then
      local next="${format:$((i + 1)):1}"
      case "$next" in
      d) regex="${regex}[0-9]+" ;;
      i) regex="${regex}[+-]?[0-9]+" ;;
      f) regex="${regex}[+-]?[0-9]*\\.?[0-9]+" ;;
      s) regex="${regex}[^ ]+" ;;
      x) regex="${regex}[0-9a-fA-F]+" ;;
      e) regex="${regex}[+-]?[0-9]*\\.?[0-9]+[eE][+-]?[0-9]+" ;;
      %) regex="${regex}%" ;;
      *)
        regex="${regex}%${next}"
        ;;
      esac
      i=$((i + 2))
    else
      case "$char" in
      . | '*' | '+' | '?' | '(' | ')' | '[' | ']' | '{' | '}' | '|' | '^' | '$')
        regex="${regex}\\${char}"
        ;;
      \\)
        regex="${regex}\\\\"
        ;;
      *)
        regex="${regex}${char}"
        ;;
      esac
      i=$((i + 1))
    fi
  done

  printf '%s' "^${regex}$"
}

function assert_string_matches_format() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "format, actual" "$#"
    return 2
  fi

  local format="$1"
  local actual="$2"
  local label_override="${3:-}"

  local regex
  regex="$(bashunit::format_to_regex "$format")"

  if [ "$(printf '%s' "$actual" | "$GREP" -cE "$regex" || true)" -eq 0 ]; then
    bashunit::assert::fail_with "${label_override:-}" "${actual}" "to match format" "${format}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_string_not_matches_format() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "format, actual" "$#"
    return 2
  fi

  local format="$1"
  local actual="$2"
  local label_override="${3:-}"

  local regex
  regex="$(bashunit::format_to_regex "$format")"

  if [ "$(printf '%s' "$actual" | "$GREP" -cE "$regex" || true)" -gt 0 ]; then
    bashunit::assert::fail_with "${label_override:-}" "${actual}" "to not match format" "${format}"
    return
  fi

  bashunit::state::add_assertions_passed
}
