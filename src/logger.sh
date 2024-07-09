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
    echo "  <testsuite name=\"bashunit\" tests=\"${#TEST_NAMES[@]}\" passed=\"$test_passed\" failures=\"$tests_failed\" incomplete=\"$tests_incomplete\" skipped=\"$tests_skipped\" snapshot=\"$tests_snapshot\" time=\"$time\">"

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
