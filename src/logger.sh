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
  local message="${4:-}"
  local duration=$(($(date +%s) - start_time))

  TEST_NAMES+=("$test_name")
  TEST_STATUSES+=("$status")
  TEST_DURATIONS+=("$duration")
  TEST_ERRORS+=("$message")
}
