#!/usr/bin/env bash

# GitHub Actions workflow-commands log writer.

function bashunit::reports::__gha_encode() {
  local text="$1"
  text=$(bashunit::reports::__strip_ansi "$text")
  # Percent-encode reserved chars per GHA workflow-commands spec.
  # Bash 3.0+ parameter expansion avoids extra awk/sed calls.
  # Order matters: encode '%' first so the sequences we inject stay literal.
  # `[%]`, not `%`: Bash 3.0 reads the `%` right after `//` as the anchor-to-end
  # syntax with an empty pattern, appending the replacement instead of
  # substituting -- `100% and 50%` came out as `100% and 50%%25`, so an
  # annotation reached GitHub unencoded (#1121). Same trap as #1119 with `#`.
  text="${text//[%]/%25}"
  text="${text//$'\r'/%0D}"
  text="${text//$'\n'/%0A}"
  printf '%s' "$text"
}

##
# A property VALUE carries a stricter rule than the message: GitHub splits the
# property list on `,` and a key from its value on `=`, and the spec also
# reserves `:`. A `set_test_title` holding a comma therefore ended the title
# there and turned the remainder into an invented property.
#
# Built on the message encoder, so `%` is already encoded first and the `%3A`
# and `%2C` added here stay literal -- and it inherits the `[%]` workaround for
# Bash 3.0 reading a bare `%` after `//` as anchor-to-end (#1121).
##
function bashunit::reports::__gha_encode_property() {
  local text
  text=$(bashunit::reports::__gha_encode "$1")
  text="${text//:/%3A}"
  text="${text//,/%2C}"
  printf '%s' "$text"
}

# Echoes GitHub Actions workflow-command annotations to stdout.
# Arguments: $1 - "failed-only" to emit just errors (default: all reportable).
function bashunit::reports::print_gha_annotations() {
  local only="${1:-all}"

  local i
  for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
    local file="${_BASHUNIT_REPORTS_TEST_FILES[$i]:-}"
    local name="${_BASHUNIT_REPORTS_TEST_NAMES[$i]:-}"
    local status="${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}"
    local failure_message="${_BASHUNIT_REPORTS_TEST_FAILURES[$i]:-}"
    local line="${_BASHUNIT_REPORTS_TEST_LINES[$i]:-}"
    local level="" message=""

    case "$status" in
      failed)
        level="error"
        message="$failure_message"
        ;;
      risky)
        level="warning"
        message="Test has no assertions (risky)"
        ;;
      flaky)
        level="warning"
        message="Test passed only after ${_BASHUNIT_REPORTS_TEST_RETRIES[$i]:-0} retries: $failure_message"
        ;;
      incomplete)
        level="notice"
        message="Test incomplete"
        ;;
      *)
        continue
        ;;
    esac

    if [ "$only" = "failed-only" ] && [ "$status" != "failed" ]; then
      continue
    fi

    # `line` is an integer this file produced, so it needs no encoding; `file`
    # and `name` are user-supplied and do.
    local location="file=$(bashunit::reports::__gha_encode_property "$file")"
    if [ -n "$line" ]; then
      location="${location},line=${line}"
    fi

    local encoded_message encoded_name
    encoded_message=$(bashunit::reports::__gha_encode "$message")
    encoded_name=$(bashunit::reports::__gha_encode_property "$name")
    echo "::${level} ${location},title=${encoded_name}::${encoded_message}"
  done
}

function bashunit::reports::generate_gha_log() {
  local output_file="$1"

  bashunit::reports::print_gha_annotations all >"$output_file"
}
