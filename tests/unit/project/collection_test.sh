#!/usr/bin/env bash

# Anti-drift contract for how `make test` finds tests.
#
# The Makefile used to collect with $(wildcard tests/*/*[tT]est.sh), which matches
# exactly one level. Once tests/unit/ mirrors the src/ module layout (#957), a
# nested test would be skipped by `make test` while `./bashunit tests/` still ran
# it -- CI green, quietly testing less. This file is itself nested, so the old
# glob would not even have collected it.

ROOT_DIR=""

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
}

function collection_from_make() {
  (cd "$ROOT_DIR" && make test/list 2>/dev/null | tail -n +2 | grep -v '^$' | LC_ALL=C sort)
}

function collection_from_disk() {
  (cd "$ROOT_DIR" && find tests -name '*[tT]est.sh' -not -path '*/fixtures/*' | LC_ALL=C sort)
}

# Every real test file must reach `make test`, however deeply it is nested.
function test_make_test_collects_every_test_file_on_disk() {
  assert_same "$(collection_from_disk)" "$(collection_from_make)"
}

# Fixtures are inputs to other tests, not tests. Four of them end in _test.sh, so
# a recursive glob without the fixtures/ exclusion collects and runs them.
function test_make_test_collects_no_fixture() {
  assert_not_contains "fixtures/" "$(collection_from_make)"
}

# The guard above is only meaningful if fixtures that would be caught still exist.
function test_fixtures_that_would_be_swept_in_still_exist() {
  local trap_files
  trap_files=$(cd "$ROOT_DIR" && find tests -path '*/fixtures/*' -name '*[tT]est.sh' | wc -l | tr -d ' ')

  assert_greater_than "0" "$trap_files"
}
