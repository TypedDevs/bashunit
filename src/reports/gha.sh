#!/usr/bin/env bash

# GitHub Actions workflow-commands log writer.

function bashunit::reports::__gha_encode() {
  local text="$1"
  text=$(bashunit::reports::__strip_ansi "$text")
  # Percent-encode reserved chars per GHA workflow-commands spec.
  # Bash 3.0+ parameter expansion avoids extra awk/sed calls.
  # Order matters: encode '%' first so the sequences we inject stay literal.
  text="${text//%/%25}"
  text="${text//$'\r'/%0D}"
  text="${text//$'\n'/%0A}"
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

    local location="file=${file}"
    if [ -n "$line" ]; then
      location="${location},line=${line}"
    fi

    local encoded_message
    encoded_message=$(bashunit::reports::__gha_encode "$message")
    echo "::${level} ${location},title=${name}::${encoded_message}"
  done
}

function bashunit::reports::generate_gha_log() {
  local output_file="$1"

  bashunit::reports::print_gha_annotations all >"$output_file"
}
