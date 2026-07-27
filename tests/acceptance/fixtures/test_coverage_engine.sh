#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/coverage_engine_source.sh"

function test_coverage_engine_fixture_branch() {
  coverage_engine_fixture::branch 20
  assert_equals "big" "$COVERAGE_ENGINE_FIXTURE_OUT"

  coverage_engine_fixture::branch 1
  assert_equals "small" "$COVERAGE_ENGINE_FIXTURE_OUT"
}

function test_coverage_engine_fixture_loop() {
  coverage_engine_fixture::loop
  assert_equals "1" "$COVERAGE_ENGINE_FIXTURE_OUT"
}

function test_coverage_engine_fixture_pick() {
  coverage_engine_fixture::pick a
  assert_equals "A" "$COVERAGE_ENGINE_FIXTURE_OUT"

  coverage_engine_fixture::pick zz
  assert_equals "other" "$COVERAGE_ENGINE_FIXTURE_OUT"
}

function test_coverage_engine_fixture_piped() {
  coverage_engine_fixture::piped
  assert_equals "one" "$COVERAGE_ENGINE_FIXTURE_OUT"
}

function test_coverage_engine_fixture_continued() {
  coverage_engine_fixture::continued
  assert_contains "a b" "$COVERAGE_ENGINE_FIXTURE_OUT"
}
