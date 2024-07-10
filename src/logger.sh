#!/bin/bash

TEST_NAMES=()
TEST_STATUSES=()
TEST_DURATIONS=()
TEST_ERRORS=()

function logger::test_snapshot() {
  logger::log "$1" "$2" "snapshot" "$3"
}

function logger::test_incomplete() {
  logger::log "$1" "$2" "incomplete" "$3"
}

function logger::test_skipped() {
  logger::log "$1" "$2" "skipped" "$3"
}

function logger::test_passed() {
  logger::log "$1" "$2" "passed" "$3"
}

function logger::test_failed() {
  logger::log "$1" "$2" "failed" "$3"
}

function logger::log() {
  local test_name="$1"
  local start_time="$2"
  local status="$3"
  local error_msg="${4:-}"

  local end_time
  end_time=$(clock::now)
  local duration=$((end_time - start_time))

  TEST_NAMES+=("$test_name")
  TEST_STATUSES+=("$status")
  TEST_DURATIONS+=("$duration")
  TEST_ERRORS+=("$error_msg")
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
    echo "  <testsuite name=\"bashunit\" tests=\"${#TEST_NAMES[@]}\" time=\"$time\""
    echo "             passed=\"$test_passed\" failures=\"$tests_failed\" incomplete=\"$tests_incomplete\""
    echo "             skipped=\"$tests_skipped\" snapshot=\"$tests_snapshot\">"

    for i in "${!TEST_NAMES[@]}"; do
      local name="${TEST_NAMES[$i]}"
      local status="${TEST_STATUSES[$i]}"
      local test_time="${TEST_DURATIONS[$i]}"
      local msg="${TEST_ERRORS[$i]}"

      echo "    <testcase name=\"$name\" time=\"$test_time\" status=\"$status\">"
      if [[ -n $msg ]]; then
        echo "      <message>$msg<message/>"
      fi
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
    echo "  <table>"
    echo "    <thead>"
    echo "      <tr>"
    echo "        <th>Test Name</th>"
    echo "        <th>Status</th>"
    echo "        <th>Time (ms)</th>"
    echo "        <th>Message</th>"
    echo "      </tr>"
    echo "    </thead>"
    echo "    <tbody>"

    for i in "${!TEST_NAMES[@]}"; do
      local name="${TEST_NAMES[$i]}"
      local status="${TEST_STATUSES[$i]}"
      local test_time="${TEST_DURATIONS[$i]}"
      local msg="${TEST_ERRORS[$i]}"

      echo "      <tr class=\"$status\">"
      echo "        <td>$name</td>"
      echo "        <td>$status</td>"
      echo "        <td>$test_time</td>"
      echo "        <td>$msg</td>"
      echo "      </tr>"
    done

    echo "    </tbody>"
    echo "  </table>"
    echo "</body>"
    echo "</html>"
  } > "$output_file"
}
