#!/usr/bin/env bash
# shellcheck disable=SC2155

_BASHUNIT_REPORTS_TEST_FILES=()
_BASHUNIT_REPORTS_TEST_NAMES=()
_BASHUNIT_REPORTS_TEST_STATUSES=()
_BASHUNIT_REPORTS_TEST_DURATIONS=()
_BASHUNIT_REPORTS_TEST_ASSERTIONS=()
_BASHUNIT_REPORTS_TEST_FAILURES=()
_BASHUNIT_REPORTS_TEST_LINES=()

function bashunit::reports::add_test_snapshot() {
  bashunit::reports::add_test "$1" "$2" "$3" "$4" "snapshot"
}

function bashunit::reports::add_test_incomplete() {
  bashunit::reports::add_test "$1" "$2" "$3" "$4" "incomplete"
}

function bashunit::reports::add_test_skipped() {
  bashunit::reports::add_test "$1" "$2" "$3" "$4" "skipped"
}

function bashunit::reports::add_test_passed() {
  bashunit::reports::add_test "$1" "$2" "$3" "$4" "passed"
}

function bashunit::reports::add_test_risky() {
  bashunit::reports::add_test "$1" "$2" "$3" "$4" "risky"
}

function bashunit::reports::add_test_failed() {
  bashunit::reports::add_test "$1" "$2" "$3" "$4" "failed" "$5"
}

function bashunit::reports::add_test() {
  # Skip tracking when no report output is requested
  {
    [ -n "${BASHUNIT_LOG_JUNIT:-}" ] ||
      [ -n "${BASHUNIT_REPORT_HTML:-}" ] ||
      [ -n "${BASHUNIT_LOG_GHA:-}" ] ||
      [ -n "${BASHUNIT_REPORT_TAP:-}" ] ||
      [ -n "${BASHUNIT_REPORT_JSON:-}" ]
  } || return 0

  local file="$1"
  local test_name="$2"
  local duration="$3"
  local assertions="$4"
  local status="$5"
  local failure_message="${6:-}"

  # Capture the line number from the current test location ("file:line"),
  # but only when it belongs to this test's file, so a stale location from a
  # prior test never mislabels this entry.
  local line=""
  case "${_BASHUNIT_TEST_LOCATION:-}" in
    "$file":*) line="${_BASHUNIT_TEST_LOCATION##*:}" ;;
  esac

  _BASHUNIT_REPORTS_TEST_FILES[${#_BASHUNIT_REPORTS_TEST_FILES[@]}]="$file"
  _BASHUNIT_REPORTS_TEST_NAMES[${#_BASHUNIT_REPORTS_TEST_NAMES[@]}]="$test_name"
  _BASHUNIT_REPORTS_TEST_STATUSES[${#_BASHUNIT_REPORTS_TEST_STATUSES[@]}]="$status"
  _BASHUNIT_REPORTS_TEST_ASSERTIONS[${#_BASHUNIT_REPORTS_TEST_ASSERTIONS[@]}]="$assertions"
  _BASHUNIT_REPORTS_TEST_DURATIONS[${#_BASHUNIT_REPORTS_TEST_DURATIONS[@]}]="$duration"
  _BASHUNIT_REPORTS_TEST_FAILURES[${#_BASHUNIT_REPORTS_TEST_FAILURES[@]}]="$failure_message"
  _BASHUNIT_REPORTS_TEST_LINES[${#_BASHUNIT_REPORTS_TEST_LINES[@]}]="$line"
}

function bashunit::reports::__xml_escape() {
  local text="$1"
  # Strip ANSI escape sequences and control characters invalid in XML 1.0,
  # then escape XML special characters (& first to avoid double-escaping)
  echo "$text" \
    | sed -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
    | tr -d '\000-\010\013\014\016-\037' \
    | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&apos;/g"
}

# Escapes a string for embedding in a JSON string literal (pure Bash, no jq).
# Strips ANSI/control chars that cannot appear inline, keeps \t\r\n as escapes.
function bashunit::reports::__json_escape() {
  local text="$1"
  text=$(printf '%s' "$text" | sed -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' | tr -d '\000-\010\013\014\016-\037')
  # Backslash first so escapes added below are not doubled.
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  text="${text//$'\t'/\\t}"
  text="${text//$'\r'/\\r}"
  text="${text//$'\n'/\\n}"
  printf '%s' "$text"
}

function bashunit::reports::generate_junit_xml() {
  local output_file="$1"

  local tests_skipped=$(bashunit::state::get_tests_skipped)
  local tests_incomplete=$(bashunit::state::get_tests_incomplete)
  local tests_failed=$(bashunit::state::get_tests_failed)
  local time_ms=$(bashunit::clock::total_runtime_in_milliseconds)
  local time
  time=$(LC_ALL=C awk -v ms="$time_ms" 'BEGIN {printf "%.3f", ms/1000}')

  {
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    echo "<testsuites>"
    echo "  <testsuite name=\"bashunit\" tests=\"${#_BASHUNIT_REPORTS_TEST_NAMES[@]}\""
    echo "             failures=\"$tests_failed\" errors=\"0\""
    echo "             skipped=\"$(( tests_skipped + tests_incomplete ))\""
    echo "             time=\"$time\">"

    local i
    for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
      local file="${_BASHUNIT_REPORTS_TEST_FILES[$i]:-}"
      local name="${_BASHUNIT_REPORTS_TEST_NAMES[$i]:-}"
      local status="${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}"
      local test_time_ms="${_BASHUNIT_REPORTS_TEST_DURATIONS[$i]:-}"
      local failure_message="${_BASHUNIT_REPORTS_TEST_FAILURES[$i]:-}"
      local test_time
      test_time=$(LC_ALL=C awk -v ms="$test_time_ms" 'BEGIN {printf "%.3f", ms/1000}')

      echo "    <testcase file=\"$file\""
      echo "        name=\"$name\""
      echo "        time=\"$test_time\">"

      # Add failure element for failed tests with actual failure message
      if [ "$status" = "failed" ]; then
        local escaped_message
        escaped_message=$(bashunit::reports::__xml_escape "$failure_message")
        echo "      <failure message=\"Test failed\">$escaped_message</failure>"
      elif [ "$status" = "risky" ]; then
        echo "      <skipped message=\"Test has no assertions (risky)\"/>"
      elif [ "$status" = "skipped" ]; then
        echo "      <skipped/>"
      elif [ "$status" = "incomplete" ]; then
        echo "      <skipped message=\"Test incomplete\"/>"
      fi

      echo "    </testcase>"
    done

    echo "  </testsuite>"
    echo "</testsuites>"
  } >"$output_file"
}

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

function bashunit::reports::generate_report_json() {
  local output_file="$1"
  local total="${#_BASHUNIT_REPORTS_TEST_NAMES[@]}"

  local passed=0 failed=0 skipped=0 incomplete=0 duration_total=0
  local i
  for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
    duration_total=$((duration_total + ${_BASHUNIT_REPORTS_TEST_DURATIONS[$i]:-0}))
    case "${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}" in
    failed) failed=$((failed + 1)) ;;
    skipped) skipped=$((skipped + 1)) ;;
    incomplete) incomplete=$((incomplete + 1)) ;;
    # snapshot and risky ran without failing, so they count as passed here; the
    # per-test "status" field below preserves the exact category.
    *) passed=$((passed + 1)) ;;
    esac
  done

  {
    printf '{\n'
    printf '  "summary": { "total": %d, "passed": %d, "failed": %d,' \
      "$total" "$passed" "$failed"
    printf ' "skipped": %d, "incomplete": %d, "duration_ms": %d },\n' \
      "$skipped" "$incomplete" "$duration_total"
    printf '  "tests": [\n'
    local seq=0
    for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
      local file name status duration message sep
      file=$(bashunit::reports::__json_escape "${_BASHUNIT_REPORTS_TEST_FILES[$i]:-}")
      name=$(bashunit::reports::__json_escape "${_BASHUNIT_REPORTS_TEST_NAMES[$i]:-}")
      status="${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}"
      duration="${_BASHUNIT_REPORTS_TEST_DURATIONS[$i]:-0}"
      message=$(bashunit::reports::__json_escape "${_BASHUNIT_REPORTS_TEST_FAILURES[$i]:-}")
      sep=","
      [ "$seq" -eq "$((total - 1))" ] && sep=""
      printf '    { "file": "%s", "name": "%s", "status": "%s", "duration_ms": %d, "message": "%s" }%s\n' \
        "$file" "$name" "$status" "$duration" "$message" "$sep"
      seq=$((seq + 1))
    done
    printf '  ]\n'
    printf '}\n'
  } >"$output_file"
}

function bashunit::reports::__gha_encode() {
  local text="$1"
  # Strip ANSI escape sequences first (one sed call)
  text=$(printf '%s' "$text" | sed -e 's/\x1b\[[0-9;]*[a-zA-Z]//g')
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

function bashunit::reports::generate_report_html() {
  local output_file="$1"

  local test_passed=$(bashunit::state::get_tests_passed)
  local tests_skipped=$(bashunit::state::get_tests_skipped)
  local tests_incomplete=$(bashunit::state::get_tests_incomplete)
  local tests_snapshot=$(bashunit::state::get_tests_snapshot)
  local tests_failed=$(bashunit::state::get_tests_failed)
  local time=$(bashunit::clock::total_runtime_in_milliseconds)

  # Temporary file to store test cases by file (use mktemp for parallel safety)
  local temp_file
  temp_file=$(mktemp "${TMPDIR:-/tmp}/bashunit-report.XXXXXX")

  # Collect test cases by file
  : >"$temp_file" # Clear temp file if it exists
  local i
  for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
    local file="${_BASHUNIT_REPORTS_TEST_FILES[$i]:-}"
    local name="${_BASHUNIT_REPORTS_TEST_NAMES[$i]:-}"
    local status="${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}"
    local test_time="${_BASHUNIT_REPORTS_TEST_DURATIONS[$i]:-}"
    local test_case="$file|$name|$status|$test_time"

    echo "$test_case" >>"$temp_file"
  done

  {
    echo "<!DOCTYPE html>"
    echo "<html lang=\"en\">"
    echo "<head>"
    echo "  <meta charset=\"UTF-8\">"
    echo "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">"
    echo "  <title>Test Report</title>"
    echo "  <style>"
    echo "    body { font-family: Arial, sans-serif; }"
    echo "    table { width: 100%; border-collapse: collapse; }"
    echo "    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }"
    echo "    th { background-color: #f2f2f2; }"
    echo "    .passed { background-color: #dff0d8; }"
    echo "    .failed { background-color: #f2dede; }"
    echo "    .skipped { background-color: #fcf8e3; }"
    echo "    .incomplete { background-color: #d9edf7; }"
    echo "    .snapshot { background-color: #dfe6e9; }"
    echo "    .risky { background-color: #f5e6f5; }"
    echo "  </style>"
    echo "</head>"
    echo "<body>"
    echo "  <h1>Test Report</h1>"
    echo "  <table>"
    echo "    <thead>"
    echo "      <tr>"
    echo "        <th>Total Tests</th>"
    echo "        <th>Passed</th>"
    echo "        <th>Failed</th>"
    echo "        <th>Incomplete</th>"
    echo "        <th>Skipped</th>"
    echo "        <th>Snapshot</th>"
    echo "        <th>Time (ms)</th>"
    echo "      </tr>"
    echo "    </thead>"
    echo "    <tbody>"
    echo "      <tr>"
    echo "        <td>${#_BASHUNIT_REPORTS_TEST_NAMES[@]}</td>"
    echo "        <td>$test_passed</td>"
    echo "        <td>$tests_failed</td>"
    echo "        <td>$tests_incomplete</td>"
    echo "        <td>$tests_skipped</td>"
    echo "        <td>$tests_snapshot</td>"
    echo "        <td>$time</td>"
    echo "      </tr>"
    echo "    </tbody>"
    echo "  </table>"
    echo "  <p>Time: $time ms</p>"

    # Read the temporary file and group by file
    local current_file=""
    local file name status test_time
    while IFS='|' read -r file name status test_time; do
      if [ "$file" != "$current_file" ]; then
        if [ -n "$current_file" ]; then
          echo "    </tbody>"
          echo "  </table>"
        fi
        echo "  <h2>File: $file</h2>"
        echo "  <table>"
        echo "    <thead>"
        echo "      <tr>"
        echo "        <th>Test Name</th>"
        echo "        <th>Status</th>"
        echo "        <th>Time (ms)</th>"
        echo "      </tr>"
        echo "    </thead>"
        echo "    <tbody>"
        current_file="$file"
      fi
      echo "      <tr class=\"$status\">"
      echo "        <td>$name</td>"
      echo "        <td>$status</td>"
      echo "        <td>$test_time</td>"
      echo "      </tr>"
    done <"$temp_file"

    # Close the last table
    if [ -n "$current_file" ]; then
      echo "    </tbody>"
      echo "  </table>"
    fi

    echo "</body>"
    echo "</html>"
  } >"$output_file"

  # Clean up temporary file
  rm -f "$temp_file"
}
