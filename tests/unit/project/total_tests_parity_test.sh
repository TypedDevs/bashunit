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
  PARITY_MISMATCHES="$(_parity_mismatches)"
}

# Both counts for every repo test file, compared in a shell that has sourced
# nothing but src/. The comparison cannot run in this one: the sourcing path
# asks `compgen -A function`, which would also see the test functions of
# whichever file is currently running -- every file would come out four tests
# short, and a real mismatch would hide in the noise.
#
# One walk checks every case, since sourcing each file is the slow part. Each
# offender is reported as "<case> <file>: ..." so a failure names the file.
function _parity_mismatches() {
  (
    cd "$ROOT_DIR" || return 1
    find tests -name '*[tT]est.sh' -type f -print0 |
      xargs -0 bash -c '
        BASHUNIT_ROOT_DIR="$PWD"
        export BASHUNIT_ROOT_DIR BASHUNIT_EXCLUDE_FILTER
        # find_total_tests needs "data_set", so globals come first.
        # shellcheck source=/dev/null
        source src/api/globals.sh
        # shellcheck source=/dev/null
        source src/helper/index.sh

        function compare() { # $1 = case, $2 = file, $3 = filter
          bashunit::helper::_count_tests_statically "$3"
          static=$_BASHUNIT_HELPER_FILE_COUNT_OUT
          bashunit::helper::_count_tests_by_sourcing "$2" "$3"
          sourced=$_BASHUNIT_HELPER_FILE_COUNT_OUT
          if [ "$static" != "$sourced" ]; then
            echo "$1 $2: static=$static sourced=$sourced"
          fi
        }

        for file in "$@"; do
          bashunit::helper::build_provider_map "$file"
          bashunit::helper::_can_count_statically || continue
          BASHUNIT_EXCLUDE_FILTER=""
          compare all "$file" ""
          compare filter "$file" "should"
          BASHUNIT_EXCLUDE_FILTER="should"
          compare exclude "$file" ""
        done
      ' bash
  )
}

# Prints the mismatches of one case.
function _mismatches_of() { # $1 = case
  local line
  while IFS= read -r line; do
    case "$line" in "$1 "*) echo "$line" ;; esac
  done <<<"$PARITY_MISMATCHES"
}

function test_static_and_sourced_counts_agree_on_every_test_file() {
  assert_empty "$(_mismatches_of all)"
}

function test_static_and_sourced_counts_agree_under_a_filter() {
  assert_empty "$(_mismatches_of filter)"
}

function test_static_and_sourced_counts_agree_under_an_exclude_filter() {
  assert_empty "$(_mismatches_of exclude)"
}

# Provider-mapped files always need execution to count their rows.
function test_the_static_path_claims_most_provider_free_files() {
  local file
  local claimed=0
  local total=0
  local files
  files="$(find "$ROOT_DIR/tests" -name '*[tT]est.sh' -type f)"

  while IFS= read -r file; do
    [ -z "$file" ] && continue
    bashunit::helper::build_provider_map "$file"
    if [ "${#_BASHUNIT_PROVIDER_MAP_FNS[@]}" -ne 0 ]; then
      continue
    fi
    total=$((total + 1))
    if bashunit::helper::_can_count_statically; then
      claimed=$((claimed + 1))
    fi
  done <<<"$files"

  assert_greater_than 0 "$total"
  assert_greater_than $((total / 2)) "$claimed"
}
