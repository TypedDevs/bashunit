#!/usr/bin/env bash

# Encoding the per-test result payload a capture subshell hands back, plus the base64 capability probe.

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
# (helpers.sh, runner/payload.sh) sides byte-identical.
_BASHUNIT_BASE64_EMPTY_SENTINEL="_BASHUNIT_EMPTY_"

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

