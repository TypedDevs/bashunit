#!/bin/bash

TEST_NAMES=()
TEST_STATUSES=()
TEST_DURATIONS=()

function logger::test_snapshot() {
  logger::log "$1" "$2" "$3" "snapshot"
}

function logger::test_incomplete() {
  logger::log "$1" "$2" "$3" "incomplete"
}

function logger::test_skipped() {
  logger::log "$1" "$2" "$3" "skipped"
}

function logger::test_passed() {
  logger::log "$1" "$2" "$3" "passed"
}

function logger::test_failed() {
  logger::log "$1" "$2" "$3" "failed"
}

function logger::log() {
  local file="$1"
  local test_name="$2"
  local start_time="$3"
  local status="$4"

  local end_time
  end_time=$(clock::now)
  local duration=$((end_time - start_time))

  TEST_FILES+=("$file")
  TEST_NAMES+=("$test_name")
  TEST_STATUSES+=("$status")
  TEST_DURATIONS+=("$duration")
}

function logger::generate_junit_xml() {
  local output_file="$1"
  local test_passed
  test_passed=$(state::get_tests_passed)
  local tests_skipped
  tests_skipped=$(state::get_tests_skipped)
  local tests_incomplete
  tests_incomplete=$(state::get_tests_incomplete)
  local tests_snapshot
  tests_snapshot=$(state::get_tests_snapshot)
  local tests_failed
  tests_failed=$(state::get_tests_failed)
  local time
  time=$(clock::runtime_in_milliseconds)

  {
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    echo "<testsuites>"
    echo "  <testsuite name=\"bashunit\" tests=\"${#TEST_NAMES[@]}\""
    echo "             passed=\"$test_passed\" failures=\"$tests_failed\" incomplete=\"$tests_incomplete\""
    echo "             skipped=\"$tests_skipped\" snapshot=\"$tests_snapshot\""
    echo "             time=\"$time\">"

    for i in "${!TEST_NAMES[@]}"; do
      local file="${TEST_FILES[$i]}"
      local name="${TEST_NAMES[$i]}"
      local status="${TEST_STATUSES[$i]}"
      local test_time="${TEST_DURATIONS[$i]}"

      echo "    <testcase file=\"$file\""
      echo "        name=\"$name\""
      echo "        status=\"$status\""
      echo "        time=\"$test_time\">"
      echo "    </testcase>"
    done

    echo "  </testsuite>"
    echo "</testsuites>"
  } > "$output_file"
}

function logger::generate_report_html() {
  local output_file="$1"
  local test_passed
  test_passed=$(state::get_tests_passed)
  local tests_skipped
  tests_skipped=$(state::get_tests_skipped)
  local tests_incomplete
  tests_incomplete=$(state::get_tests_incomplete)
  local tests_snapshot
  tests_snapshot=$(state::get_tests_snapshot)
  local tests_failed
  tests_failed=$(state::get_tests_failed)
  local time
  time=$(clock::runtime_in_milliseconds)

  # Temporary file to store test cases by file
  local temp_file="temp_test_cases.txt"

  # Collect test cases by file
  : > "$temp_file"  # Clear temp file if it exists
  for i in "${!TEST_NAMES[@]}"; do
    local file="${TEST_FILES[$i]}"
    local name="${TEST_NAMES[$i]}"
    local status="${TEST_STATUSES[$i]}"
    local test_time="${TEST_DURATIONS[$i]}"
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
    echo "        <td>${#TEST_NAMES[@]}</td>"
    echo "        <td>$test_passed</td>"
    echo "        <td>$tests_failed</td>"
    echo "        <td>$tests_incomplete</td>"
    echo "        <td>$tests_skipped</td>"
    echo "        <td>$tests_snapshot</td>"
    echo "        <td>${time}</td>"
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
