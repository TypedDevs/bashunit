#!/usr/bin/env bash
# shellcheck disable=SC2155

_REPORTS_TEST_FILES=()
_REPORTS_TEST_NAMES=()
_REPORTS_TEST_STATUSES=()
_REPORTS_TEST_DURATIONS=()
_REPORTS_TEST_ASSERTIONS=()

function reports::add_test_snapshot() {
  reports::add_test "$1" "$2" "$3" "$4" "snapshot"
}

function reports::add_test_incomplete() {
  reports::add_test "$1" "$2" "$3" "$4" "incomplete"
}

function reports::add_test_skipped() {
  reports::add_test "$1" "$2" "$3" "$4" "skipped"
}

function reports::add_test_passed() {
  reports::add_test "$1" "$2" "$3" "$4" "passed"
}

function reports::add_test_failed() {
  reports::add_test "$1" "$2" "$3" "$4" "failed"
}

function reports::add_test() {
  local file="$1"
  local test_name="$2"
  local duration="$3"
  local assertions="$4"
  local status="$5"

  _REPORTS_TEST_FILES+=("$file")
  _REPORTS_TEST_NAMES+=("$test_name")
  _REPORTS_TEST_STATUSES+=("$status")
  _REPORTS_TEST_ASSERTIONS+=("$assertions")
  _REPORTS_TEST_DURATIONS+=("$duration")
}

function reports::generate_junit_xml() {
  local output_file="$1"

  local test_passed=$(state::get_tests_passed)
  local tests_skipped=$(state::get_tests_skipped)
  local tests_incomplete=$(state::get_tests_incomplete)
  local tests_snapshot=$(state::get_tests_snapshot)
  local tests_failed=$(state::get_tests_failed)
  local time=$(clock::total_runtime_in_milliseconds)

  {
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    echo "<testsuites>"
    echo "  <testsuite name=\"bashunit\" tests=\"${#_REPORTS_TEST_NAMES[@]}\""
    echo "             passed=\"$test_passed\" failures=\"$tests_failed\" incomplete=\"$tests_incomplete\""
    echo "             skipped=\"$tests_skipped\" snapshot=\"$tests_snapshot\""
    echo "             time=\"$time\">"

    for i in "${!_REPORTS_TEST_NAMES[@]}"; do
      local file="${_REPORTS_TEST_FILES[$i]}"
      local name="${_REPORTS_TEST_NAMES[$i]}"
      local assertions="${_REPORTS_TEST_ASSERTIONS[$i]}"
      local status="${_REPORTS_TEST_STATUSES[$i]}"
      local test_time="${_REPORTS_TEST_DURATIONS[$i]}"

      echo "    <testcase file=\"$file\""
      echo "        name=\"$name\""
      echo "        status=\"$status\""
      echo "        assertions=\"$assertions\""
      echo "        time=\"$test_time\">"
      echo "    </testcase>"
    done

    echo "  </testsuite>"
    echo "</testsuites>"
  } > "$output_file"
}

function reports::generate_report_html() {
  local output_file="$1"

  local test_passed=$(state::get_tests_passed)
  local tests_skipped=$(state::get_tests_skipped)
  local tests_incomplete=$(state::get_tests_incomplete)
  local tests_snapshot=$(state::get_tests_snapshot)
  local tests_failed=$(state::get_tests_failed)
  local time=$(clock::total_runtime_in_milliseconds)

  # Temporary file to store test cases by file
  local temp_file="temp_test_cases.txt"

  # Collect test cases by file
  : > "$temp_file"  # Clear temp file if it exists
  for i in "${!_REPORTS_TEST_NAMES[@]}"; do
    local file="${_REPORTS_TEST_FILES[$i]}"
    local name="${_REPORTS_TEST_NAMES[$i]}"
    local status="${_REPORTS_TEST_STATUSES[$i]}"
    local test_time="${_REPORTS_TEST_DURATIONS[$i]}"
    local test_case="$file|$name|$status|$test_time"

    echo "$test_case" >> "$temp_file"
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
    echo "        <td>${#_REPORTS_TEST_NAMES[@]}</td>"
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
    done < "$temp_file"

    # Close the last table
    if [ -n "$current_file" ]; then
      echo "    </tbody>"
      echo "  </table>"
    fi

    echo "</body>"
    echo "</html>"
  } > "$output_file"

  # Clean up temporary file
  rm -f "$temp_file"
}
