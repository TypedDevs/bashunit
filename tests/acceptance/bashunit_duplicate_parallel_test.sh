#!/usr/bin/env bash
set -euo pipefail

# Bash silently discards the first of two same-named function definitions, so a
# duplicated test function means one test never runs. The check that catches
# that lived inside the per-file loop, which --parallel backgrounds -- so the
# state it set died with the subshell and the check was off in the mode CI uses
# (#1147). Same boundary as the provider counter in #1145.

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function duplicate_fixture() {
  local fixture
  fixture="$(bashunit::temp_file duplicate_fns).sh"
  # Written with printf rather than a heredoc so this file does not itself
  # contain two same-named definitions for its own duplicate check to find.
  printf '%s\n' '#!/usr/bin/env bash' >"$fixture"
  printf 'function %s() { assert_same 1 1; }\n' test_twice >>"$fixture"
  printf 'function %s() { assert_same 2 2; }\n' test_twice >>"$fixture"
  printf '%s' "$fixture"
}

function run_mode() { # $1 = --parallel | --no-parallel, $2 = fixture
  local code=0
  local out
  out="$(./bashunit "$1" --env "$TEST_ENV_FILE" "$2" 2>&1)" || code=$?
  printf '%s\n%s' "$code" "$(printf '%s' "$out" | strip_ansi)"
}

function test_parallel_reports_duplicates_like_sequential() {
  local fixture result
  fixture="$(duplicate_fixture)"
  result="$(run_mode --parallel "$fixture")"

  assert_same 1 "${result%%$'\n'*}"
  assert_contains "Duplicate test functions found" "$result"
}

function test_sequential_still_reports_duplicates() {
  local fixture result
  fixture="$(duplicate_fixture)"
  result="$(run_mode --no-parallel "$fixture")"

  assert_same 1 "${result%%$'\n'*}"
  assert_contains "Duplicate test functions found" "$result"
}

# The report named the function but not where it was defined, so finding the
# second definition in a long file was a manual hunt. The awk pass already
# walks every line.
function test_the_report_names_the_lines_of_each_definition() {
  local fixture result
  fixture="$(duplicate_fixture)"
  result="$(run_mode --no-parallel "$fixture")"

  assert_contains "test_twice" "$result"
  assert_contains "lines 2, 3" "$result"
}

function test_a_file_without_duplicates_is_unaffected() {
  local fixture
  fixture="$(bashunit::temp_file no_duplicate_fns).sh"
  printf '%s\n' '#!/usr/bin/env bash
function test_alpha() { assert_same 1 1; }
function test_beta() { assert_same 2 2; }' >"$fixture"

  local result
  result="$(run_mode --parallel "$fixture")"

  assert_same 0 "${result%%$'\n'*}"
  assert_not_contains "Duplicate" "$result"
}
