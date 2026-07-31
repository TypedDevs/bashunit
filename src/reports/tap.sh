#!/usr/bin/env bash

# TAP version 13 report writer.

##
# Prepares a failure message for a TAP YAML diagnostic block: strips ANSI escape
# sequences, collapses newlines to spaces and doubles single quotes so the value
# is safe inside a YAML single-quoted scalar. Bash 3.0+ compatible.
##
function bashunit::reports::__tap_message() {
  echo "$1" \
    | sed -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
    | tr '\n' ' ' \
    | sed -e "s/'/''/g"
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
      local name="${_BASHUNIT_REPORTS_TEST_NAMES[$i]:-}"
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
      *)
        echo "ok $seq - $name"
        ;;
      esac
    done
  } >"$output_file"
}
