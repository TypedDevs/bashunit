#!/bin/bash

TEST_NAMES=()
TEST_STATUSES=()
TEST_DURATIONS=()
TEST_ERRORS=()

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
  local junit_file="$1"

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local hostname
  hostname=$(hostname)

  {
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    echo "<testsuites>"
    echo "  <testsuite name=\"bashunit\" tests=\"${#TEST_NAMES[@]}\" timestamp=\"$timestamp\" hostname=\"$hostname\">"

    for i in "${!TEST_NAMES[@]}"; do
      local test_name="${TEST_NAMES[$i]}"
      local status="${TEST_STATUSES[$i]}"
      local duration="${TEST_DURATIONS[$i]}"
      local error_msg="${TEST_ERRORS[$i]}"

      echo "    <testcase name=\"$test_name\" time=\"$duration\" status=\"$status\">"
      if [[ "$status" == "failed" ]]; then
        echo "      <failure message=\"$error_msg\"/>"
      fi
      echo "    </testcase>"
    done

    echo "  </testsuite>"
    echo "</testsuites>"
  } > "$junit_file"
}
