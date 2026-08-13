#!/usr/bin/env bash

# TAP version 13 report writer.

##
# Prepares a failure message for a TAP YAML diagnostic block: strips ANSI escape
# sequences, collapses newlines to spaces and doubles single quotes so the value
# is safe inside a YAML single-quoted scalar. Bash 3.0+ compatible.
##
function bashunit::reports::__tap_message() {
  bashunit::reports::__strip_ansi "$1" \
    | tr '\n' ' ' \
    | sed -e "s/'/''/g"
}

##
# Escapes a test description for a TAP `ok`/`not ok` line.
#
# TAP 13 reads an unescaped `#` as the start of a directive, so a passing test
# called "check # SKIP me" is reported as skipped and vanishes from the count
# (#1119). The backslash goes first, or an escape written by this function
# would itself be re-escaped.
##
function bashunit::reports::__tap_description() {
  local text="$1"
  text="${text//\\/\\\\}"
  printf '%s' "${text//#/\\#}"
}

##
# Writes results in TAP version 13 format (https://testanything.org).
# Passing/snapshot -> "ok", failed -> "not ok" with a YAML diagnostic,
# skipped/risky -> "# SKIP", incomplete -> "# TODO".
# Arguments: $1 - output file
##
function bashunit::reports::generate_report_tap() {
  local output_file="$1"
  local total="${#_BASHUNIT_REPORTS_TEST_NAMES[@]}"

  {
    echo "TAP version 13"
    echo "1..$total"

    local i seq=0
    for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
      seq=$((seq + 1))
      local name
      name="$(bashunit::reports::__tap_description "${_BASHUNIT_REPORTS_TEST_NAMES[$i]:-}")"
      local status="${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}"
      local failure_message="${_BASHUNIT_REPORTS_TEST_FAILURES[$i]:-}"

      case "$status" in
      failed)
        echo "not ok $seq - $name"
        echo "  ---"
        echo "  message: '$(bashunit::reports::__tap_message "$failure_message")'"
        echo "  ..."
        ;;
      skipped)
        echo "ok $seq - $name # SKIP"
        ;;
      risky)
        echo "ok $seq - $name # SKIP risky (no assertions)"
        ;;
      incomplete)
        echo "ok $seq - $name # TODO"
        ;;
      flaky)
        # `ok` because it passed; the TODO directive is how TAP consumers mark a
        # result that needs attention without failing the run.
        echo "ok $seq - $name # TODO flaky (retried ${_BASHUNIT_REPORTS_TEST_RETRIES[$i]:-0}/${BASHUNIT_RETRY:-0})"
        ;;
      *)
        echo "ok $seq - $name"
        ;;
      esac
    done
  } >"$output_file"
}
