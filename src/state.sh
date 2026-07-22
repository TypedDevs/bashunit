#!/usr/bin/env bash

# Cache base64 -w flag support (Alpine needs -w 0, macOS does not support -w).
# Scrape `base64 --help` once and match with a shell `case` instead of piping
# into a `grep` fork — same detection, one fewer fork per cold start.
_bashunit_base64_help="$(base64 --help 2>&1 || true)"
case "$_bashunit_base64_help" in
*-w*) _BASHUNIT_BASE64_WRAP_FLAG=true ;;
*) _BASHUNIT_BASE64_WRAP_FLAG=false ;;
esac
unset _bashunit_base64_help

# Wire sentinel for an empty base64 payload. base64 of "" is "", which gets lost
# in line parsing, so encode_base64 emits this token and both decode sites map it
# back to "". Single source of truth keeps the encode (helpers.sh) and decode
# (helpers.sh, runner.sh) sides byte-identical.
# shellcheck disable=SC2034 # read cross-file in helpers.sh and runner.sh
_BASHUNIT_BASE64_EMPTY_SENTINEL="_BASHUNIT_EMPTY_"

_BASHUNIT_TESTS_PASSED=0
_BASHUNIT_TESTS_FAILED=0
_BASHUNIT_TESTS_SKIPPED=0
_BASHUNIT_TESTS_INCOMPLETE=0
_BASHUNIT_TESTS_SNAPSHOT=0
_BASHUNIT_TESTS_RISKY=0
_BASHUNIT_ASSERTIONS_PASSED=0
_BASHUNIT_ASSERTIONS_FAILED=0
_BASHUNIT_ASSERTIONS_SKIPPED=0
_BASHUNIT_ASSERTIONS_INCOMPLETE=0
_BASHUNIT_ASSERTIONS_SNAPSHOT=0
_BASHUNIT_DUPLICATED_FUNCTION_NAMES=""
_BASHUNIT_FILE_WITH_DUPLICATED_FUNCTION_NAMES=""
_BASHUNIT_DUPLICATED_TEST_FUNCTIONS_FOUND=false
_BASHUNIT_TEST_OUTPUT=""
_BASHUNIT_TEST_TITLE=""
_BASHUNIT_TEST_EXIT_CODE=0
_BASHUNIT_TEST_HOOK_FAILURE=""
_BASHUNIT_TEST_HOOK_MESSAGE=""
_BASHUNIT_CURRENT_TEST_INTERPOLATED_NAME=""
_BASHUNIT_ASSERTION_FAILED_IN_TEST=0

function bashunit::state::get_tests_passed() {
  echo "$_BASHUNIT_TESTS_PASSED"
}

function bashunit::state::add_tests_passed() {
  ((_BASHUNIT_TESTS_PASSED++)) || true
}

function bashunit::state::get_tests_failed() {
  echo "$_BASHUNIT_TESTS_FAILED"
}

function bashunit::state::add_tests_failed() {
  ((_BASHUNIT_TESTS_FAILED++)) || true
}

function bashunit::state::get_tests_skipped() {
  echo "$_BASHUNIT_TESTS_SKIPPED"
}

function bashunit::state::add_tests_skipped() {
  ((_BASHUNIT_TESTS_SKIPPED++)) || true
}

function bashunit::state::get_tests_incomplete() {
  echo "$_BASHUNIT_TESTS_INCOMPLETE"
}

function bashunit::state::add_tests_incomplete() {
  ((_BASHUNIT_TESTS_INCOMPLETE++)) || true
}

function bashunit::state::get_tests_snapshot() {
  echo "$_BASHUNIT_TESTS_SNAPSHOT"
}

function bashunit::state::add_tests_snapshot() {
  ((_BASHUNIT_TESTS_SNAPSHOT++)) || true
}

function bashunit::state::get_tests_risky() {
  echo "$_BASHUNIT_TESTS_RISKY"
}

function bashunit::state::add_tests_risky() {
  ((_BASHUNIT_TESTS_RISKY++)) || true
}

function bashunit::state::get_assertions_passed() {
  echo "$_BASHUNIT_ASSERTIONS_PASSED"
}

function bashunit::state::add_assertions_passed() {
  ((_BASHUNIT_ASSERTIONS_PASSED++)) || true
}

function bashunit::state::get_assertions_failed() {
  echo "$_BASHUNIT_ASSERTIONS_FAILED"
}

function bashunit::state::add_assertions_failed() {
  ((_BASHUNIT_ASSERTIONS_FAILED++)) || true
}

function bashunit::state::get_assertions_skipped() {
  echo "$_BASHUNIT_ASSERTIONS_SKIPPED"
}

function bashunit::state::add_assertions_skipped() {
  ((_BASHUNIT_ASSERTIONS_SKIPPED++)) || true
}

function bashunit::state::get_assertions_incomplete() {
  echo "$_BASHUNIT_ASSERTIONS_INCOMPLETE"
}

function bashunit::state::add_assertions_incomplete() {
  ((_BASHUNIT_ASSERTIONS_INCOMPLETE++)) || true
}

function bashunit::state::get_assertions_snapshot() {
  echo "$_BASHUNIT_ASSERTIONS_SNAPSHOT"
}

function bashunit::state::add_assertions_snapshot() {
  ((_BASHUNIT_ASSERTIONS_SNAPSHOT++)) || true
}

function bashunit::state::is_duplicated_test_functions_found() {
  echo "$_BASHUNIT_DUPLICATED_TEST_FUNCTIONS_FOUND"
}

function bashunit::state::set_duplicated_test_functions_found() {
  _BASHUNIT_DUPLICATED_TEST_FUNCTIONS_FOUND=true
}

function bashunit::state::get_duplicated_function_names() {
  echo "$_BASHUNIT_DUPLICATED_FUNCTION_NAMES"
}

function bashunit::state::set_duplicated_function_names() {
  _BASHUNIT_DUPLICATED_FUNCTION_NAMES="$1"
}

function bashunit::state::get_file_with_duplicated_function_names() {
  echo "$_BASHUNIT_FILE_WITH_DUPLICATED_FUNCTION_NAMES"
}

function bashunit::state::set_file_with_duplicated_function_names() {
  _BASHUNIT_FILE_WITH_DUPLICATED_FUNCTION_NAMES="$1"
}

function bashunit::state::add_test_output() {
  _BASHUNIT_TEST_OUTPUT="$_BASHUNIT_TEST_OUTPUT$1"
}

function bashunit::state::set_test_exit_code() {
  _BASHUNIT_TEST_EXIT_CODE="$1"
}

function bashunit::state::set_test_title() {
  _BASHUNIT_TEST_TITLE="$1"
}

function bashunit::state::reset_test_title() {
  _BASHUNIT_TEST_TITLE=""
}

function bashunit::state::set_current_test_interpolated_function_name() {
  _BASHUNIT_CURRENT_TEST_INTERPOLATED_NAME="$1"
}

function bashunit::state::reset_current_test_interpolated_function_name() {
  _BASHUNIT_CURRENT_TEST_INTERPOLATED_NAME=""
}

function bashunit::state::set_test_hook_failure() {
  _BASHUNIT_TEST_HOOK_FAILURE="$1"
}

function bashunit::state::set_test_hook_message() {
  _BASHUNIT_TEST_HOOK_MESSAGE="$1"
}

function bashunit::state::mark_assertion_failed_in_test() {
  _BASHUNIT_ASSERTION_FAILED_IN_TEST=1
}

function bashunit::state::set_duplicated_functions_merged() {
  bashunit::state::set_duplicated_test_functions_found
  bashunit::state::set_file_with_duplicated_function_names "$1"
  bashunit::state::set_duplicated_function_names "$2"
}

function bashunit::state::initialize_assertions_count() {
  _BASHUNIT_ASSERTIONS_PASSED=0
  _BASHUNIT_ASSERTIONS_FAILED=0
  _BASHUNIT_ASSERTIONS_SKIPPED=0
  _BASHUNIT_ASSERTIONS_INCOMPLETE=0
  _BASHUNIT_ASSERTIONS_SNAPSHOT=0
  _BASHUNIT_TEST_OUTPUT=""
  _BASHUNIT_TEST_TITLE=""
  _BASHUNIT_TEST_HOOK_FAILURE=""
  _BASHUNIT_TEST_HOOK_MESSAGE=""
  _BASHUNIT_ASSERTION_FAILED_IN_TEST=0
}

# base64-encodes a field, writing the result into _BASHUNIT_STATE_ENCODED_OUT.
# Empty values (the common case for title/hook message, and output on a passing
# test) encode to an empty field with no base64 fork (#762). base64 of "" is ""
# anyway, so this stays wire-compatible.
_BASHUNIT_STATE_ENCODED_OUT=""
function bashunit::state::encode_field() {
  local value=$1
  if [ -z "$value" ]; then
    _BASHUNIT_STATE_ENCODED_OUT=""
    return
  fi
  if [ "$_BASHUNIT_BASE64_WRAP_FLAG" = true ]; then
    # Alpine requires the -w 0 option to avoid wrapping
    _BASHUNIT_STATE_ENCODED_OUT=$(echo -n "$value" | base64 -w 0)
  else
    _BASHUNIT_STATE_ENCODED_OUT=$(echo -n "$value" | base64)
  fi
}

function bashunit::state::export_subshell_context() {
  local encoded_test_output
  local encoded_test_title
  local encoded_test_hook_message

  bashunit::state::encode_field "$_BASHUNIT_TEST_OUTPUT"
  encoded_test_output=$_BASHUNIT_STATE_ENCODED_OUT
  bashunit::state::encode_field "$_BASHUNIT_TEST_TITLE"
  encoded_test_title=$_BASHUNIT_STATE_ENCODED_OUT
  bashunit::state::encode_field "$_BASHUNIT_TEST_HOOK_MESSAGE"
  encoded_test_hook_message=$_BASHUNIT_STATE_ENCODED_OUT

  # Emit the encoded result payload with `printf` (a builtin) instead of a
  # `cat <<EOF` heredoc: this runs once per test, so avoiding the fork removes
  # one process per test. The `\`-continued string keeps the per-field layout
  # and produces the exact same single line the heredoc did.
  local payload="\
##ASSERTIONS_FAILED=$_BASHUNIT_ASSERTIONS_FAILED\
##ASSERTIONS_PASSED=$_BASHUNIT_ASSERTIONS_PASSED\
##ASSERTIONS_SKIPPED=$_BASHUNIT_ASSERTIONS_SKIPPED\
##ASSERTIONS_INCOMPLETE=$_BASHUNIT_ASSERTIONS_INCOMPLETE\
##ASSERTIONS_SNAPSHOT=$_BASHUNIT_ASSERTIONS_SNAPSHOT\
##TEST_EXIT_CODE=$_BASHUNIT_TEST_EXIT_CODE\
##TEST_HOOK_FAILURE=$_BASHUNIT_TEST_HOOK_FAILURE\
##TEST_HOOK_MESSAGE=$encoded_test_hook_message\
##TEST_TITLE=$encoded_test_title\
##TEST_OUTPUT=$encoded_test_output##"
  printf '%s\n' "$payload"
}

function bashunit::state::calculate_total_assertions() {
  local input="$1"
  local total=0

  local numbers
  numbers=$(echo "$input" | grep -oE '##ASSERTIONS_\w+=[0-9]+' | grep -oE '[0-9]+')

  local number
  for number in $numbers; do
    total=$((total + number))
  done

  echo $total
}

function bashunit::state::print_line() {
  # shellcheck disable=SC2034
  local type=$1
  local line=$2

  ((_BASHUNIT_TOTAL_TESTS_COUNT++)) || true

  bashunit::state::add_test_output "[$type]$line"

  if bashunit::env::is_no_progress_enabled; then
    return
  fi

  if bashunit::env::is_tap_output_enabled; then
    bashunit::state::print_tap_line "$type" "$line"
    return
  fi

  if ! bashunit::env::is_simple_output_enabled; then
    printf "%s\n" "$line"
    return
  fi

  local char
  case "$type" in
  successful) char="." ;;
  failure) char="${_BASHUNIT_COLOR_FAILED}F${_BASHUNIT_COLOR_DEFAULT}" ;;
  failed) char="${_BASHUNIT_COLOR_FAILED}F${_BASHUNIT_COLOR_DEFAULT}" ;;
  failed_snapshot) char="${_BASHUNIT_COLOR_FAILED}F${_BASHUNIT_COLOR_DEFAULT}" ;;
  skipped) char="${_BASHUNIT_COLOR_SKIPPED}S${_BASHUNIT_COLOR_DEFAULT}" ;;
  incomplete) char="${_BASHUNIT_COLOR_INCOMPLETE}I${_BASHUNIT_COLOR_DEFAULT}" ;;
  snapshot) char="${_BASHUNIT_COLOR_SNAPSHOT}N${_BASHUNIT_COLOR_DEFAULT}" ;;
  risky) char="${_BASHUNIT_COLOR_RISKY}R${_BASHUNIT_COLOR_DEFAULT}" ;;
  error) char="${_BASHUNIT_COLOR_FAILED}E${_BASHUNIT_COLOR_DEFAULT}" ;;
  *) char="?" && bashunit::log "warning" "unknown test type '$type'" ;;
  esac

  if bashunit::parallel::is_enabled; then
    printf "%s" "$char"
  else
    if ((_BASHUNIT_TOTAL_TESTS_COUNT % 50 == 0)); then
      printf "%s\n" "$char"
    else
      printf "%s" "$char"
    fi
  fi
}

function bashunit::state::print_tap_line() {
  local type=$1
  local line=$2

  local clean_line
  clean_line=$(printf "%s" "$line" | sed 's/\x1B\[[0-9;]*[mK]//g')
  local test_name="${clean_line#*: }"
  test_name="${test_name%%$'\n'*}"
  # Strip trailing whitespace and duration
  test_name=$(printf "%s" "$test_name" | \
    sed 's/[[:space:]]*[0-9][0-9]*m\{0,1\}[[:space:]]*[0-9.]*[ms]*[[:space:]]*$//')

  case "$type" in
  successful)
    printf "ok %d - %s\n" "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    ;;
  failure | failed | failed_snapshot | error)
    printf "not ok %d - %s\n" "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    local detail_line
    printf "  ---\n"
    while IFS= read -r detail_line; do
      detail_line=$(printf "%s" "$detail_line" | sed 's/\x1B\[[0-9;]*[mK]//g')
      if [ -n "$detail_line" ] \
        && [ "$(echo "$detail_line" | "$GREP" -cF "Failed:" || true)" -eq 0 ] \
        && [ "$(echo "$detail_line" | "$GREP" -cF "Error:" || true)" -eq 0 ]; then
        local trimmed="${detail_line#"${detail_line%%[![:space:]]*}"}"
        printf "  %s\n" "$trimmed"
      fi
    done <<< "$clean_line"
    printf "  ...\n"
    ;;
  skipped)
    local skip_name="${test_name%%   *}"
    local skip_reason="${test_name#"$skip_name"}"
    skip_reason="${skip_reason#"${skip_reason%%[![:space:]]*}"}"
    if [ -n "$skip_reason" ]; then
      printf "ok %d - %s # SKIP %s\n" \
        "$_BASHUNIT_TOTAL_TESTS_COUNT" "$skip_name" "$skip_reason"
    else
      printf "ok %d - %s # SKIP\n" \
        "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    fi
    ;;
  incomplete)
    printf "ok %d - %s # TODO incomplete\n" \
      "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    ;;
  snapshot)
    printf "ok %d - %s # snapshot\n" \
      "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    ;;
  risky)
    printf "ok %d - %s # RISKY no assertions\n" \
      "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    ;;
  *)
    printf "not ok %d - %s\n" \
      "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    ;;
  esac
}
