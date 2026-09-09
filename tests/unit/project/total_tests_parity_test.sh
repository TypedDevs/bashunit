#!/usr/bin/env bash

# The "Running N tests" header counts a file's tests from the provider scan
# instead of sourcing the file a second time and re-running every data provider
# (#1347). A static scan cannot see a function that eval, a nested source or a
# condition defines, and files like that keep the sourcing path -- but nothing
# at runtime checks that the two paths agree on the files that do not.
#
# This is that check, over every test file in the repo: for each file the static
# path claims, its count must equal what sourcing the file produces. A
# disagreement means the header lies about how many tests are about to run.

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
}

# Both counts for every repo test file, compared in a shell that has sourced
# nothing but src/. The comparison cannot run in this one: the sourcing path
# asks `compgen -A function`, which would also see the test functions of
# whichever file is currently running -- every file would come out four tests
# short, and a real mismatch would hide in the noise.
#
# Reports each offender, so a failure names the file instead of just a number.
# Arguments: $1 - the --filter value
function _parity_mismatches() {
  local filter=$1

  (
    cd "$ROOT_DIR" || return 1
    find tests -name '*[tT]est.sh' -type f -print0 |
      xargs -0 bash -c '
        BASHUNIT_ROOT_DIR="$PWD"
        export BASHUNIT_ROOT_DIR
        # find_total_tests needs "data_set", so globals come first.
        # shellcheck source=/dev/null
        source src/api/globals.sh
        # shellcheck source=/dev/null
        source src/helper/index.sh
        filter=$1
        shift
        for file in "$@"; do
          bashunit::helper::build_provider_map "$file"
          bashunit::helper::_can_count_statically || continue
          bashunit::helper::_count_tests_statically "$filter"
          static=$_BASHUNIT_HELPER_FILE_COUNT_OUT
          bashunit::helper::_count_tests_by_sourcing "$file" "$filter"
          sourced=$_BASHUNIT_HELPER_FILE_COUNT_OUT
          if [ "$static" != "$sourced" ]; then
            echo "$file: static=$static sourced=$sourced"
          fi
        done
      ' bash "$filter"
  )
}

function test_static_and_sourced_counts_agree_on_every_test_file() {
  assert_empty "$(_parity_mismatches "")"
}

function test_static_and_sourced_counts_agree_under_a_filter() {
  assert_empty "$(_parity_mismatches "should")"
}

function test_static_and_sourced_counts_agree_under_an_exclude_filter() {
  local original=${BASHUNIT_EXCLUDE_FILTER:-}
  export BASHUNIT_EXCLUDE_FILTER="should"

  local mismatches
  mismatches="$(_parity_mismatches "")"

  export BASHUNIT_EXCLUDE_FILTER="$original"
  assert_empty "$mismatches"
}

# A check that cannot fail proves nothing: the static path must actually be
# claiming files, or the three tests above would pass over an empty set.
function test_the_static_path_claims_most_of_the_suite() {
  local file
  local claimed=0
  local total=0
  local files
  files="$(find "$ROOT_DIR/tests" -name '*[tT]est.sh' -type f)"

  while IFS= read -r file; do
    [ -z "$file" ] && continue
    total=$((total + 1))
    bashunit::helper::build_provider_map "$file"
    if bashunit::helper::_can_count_statically; then
      claimed=$((claimed + 1))
    fi
  done <<<"$files"

  assert_greater_than 0 "$total"
  assert_greater_than $((total / 2)) "$claimed"
}
