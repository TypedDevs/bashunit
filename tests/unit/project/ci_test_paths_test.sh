#!/usr/bin/env bash

# Anti-drift contract for the test paths in .github/workflows/tests.yml.
#
# The CI matrix used to slice tests/unit/ with alphabetical globs
# (tests/unit/[a-b]*_test.sh and friends). #960 moved every unit test into a
# per-module subdirectory, so those globs stopped matching anything -- and
# bashunit answers an argument that matches no file by falling back to its
# default path, i.e. the whole suite. Every macOS and Windows unit leg
# therefore ran all the tests instead of its fifth, on every run, staying green
# the entire time. Nothing was failing, so nothing pointed at it.
#
# The same rot had already cost coverage rather than time: the acceptance
# buckets were also hand-maintained globs, and tests/acceptance/worker_stderr_test.sh
# matched none of the three, so it never ran in CI at all after #891 added it.
#
# Both are now expressed as `--shard i/n <dir>`, which cannot silently select
# nothing. This test pins the property that mattered either way: a path CI runs
# must actually resolve to tests.

WORKFLOW=""
ROOT_DIR=""

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  WORKFLOW="$ROOT_DIR/.github/workflows/tests.yml"
}

# Without this the greps below would match nothing after a rename and every
# other assertion would compare empty against empty and pass -- the same
# vacuum that hid the bug this file is about.
function test_the_workflow_being_checked_exists() {
  assert_file_exists "$WORKFLOW"
}

# Each configured test_path, one per line, quotes stripped.
function ci_test_paths() {
  grep -oE 'test_path: "[^"]+"' "$WORKFLOW" | sed 's/test_path: "//; s/"$//'
}

# Both checks below collect what did NOT resolve and assert that set is empty,
# so an extractor that stops matching -- the `test_path:` key renamed, the
# workflow directory moved -- makes them pass by finding nothing to check.
# Proven by mutation: breaking the `test_path:` pattern leaves all three tests
# in this file green, and this file exists because CI path rot has shipped
# twice already (#960, and the coverage.yml case documented below).
#
# The floors sit under the current counts -- 18 `test_path:` keys, and 3
# distinct `tests/` references once the workflows are deduplicated (fewer than
# it looks, because most jobs share the same paths). They catch an extractor
# returning nothing, which is what rot looks like.
function test_the_extractors_still_find_the_paths_they_parse() {
  assert_greater_than 8 "$(cd "$ROOT_DIR" && ci_test_paths | wc -l)"
  assert_greater_than 1 "$(cd "$ROOT_DIR" && ci_referenced_test_paths | wc -l)"
}


function test_every_ci_test_path_resolves_to_at_least_one_test_file() {
  local unresolved=""
  local line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Drop flags and their values: what remains is the path or glob CI runs.
    local rest="$line"
    case "$rest" in
    --shard*)
      # `--shard i/n <path>`: drop the flag, then drop its i/n value. Done with
      # prefix stripping rather than `set -- $rest` so nothing has to rely on
      # word splitting here.
      rest="${rest#--shard }"
      rest="${rest#* }"
      ;;
    esac

    local found=0
    local token
    for token in $rest; do
      # Unquoted on purpose: these are globs and must expand here.
      local match
      for match in $token; do
        if [ -e "$match" ]; then
          found=1
          break
        fi
      done
      [ "$found" -eq 1 ] && break
    done

    if [ "$found" -eq 0 ]; then
      unresolved="$unresolved$line
"
    fi
  done <<EOF
$(cd "$ROOT_DIR" && ci_test_paths)
EOF

  assert_empty "$unresolved"
}

# The same rot hit a second workflow and this file did not catch it, because it
# only ever looked at tests.yml. coverage.yml globbed `tests/unit/*_test.sh` in a
# shell step rather than a `test_path:` key, so after #960 its `ls` failed and the
# nightly coverage run had been red for days -- unnoticed, because that workflow
# is deliberately non-blocking.
#
# This checks the property across every workflow and every shape: any tests/
# path or glob a workflow names must resolve to something on disk.
function ci_referenced_test_paths() {
  # Comment lines are dropped first: the workflows document the broken globs
  # they replaced, and those must not be read as live references.
  #
  # The match is anchored on a boundary so `sample_tests/pass_test.sh` -- a file
  # test-action.yml writes at runtime -- is not read as a `tests/` path. An
  # unanchored `tests/` matched its tail and reported it missing.
  "$GREP" -rhv '^[[:space:]]*#' "$ROOT_DIR"/.github/workflows/ --include='*.yml' 2>/dev/null |
    "$GREP" -oE '(^|[[:space:]"'"'"'=])tests/[A-Za-z0-9_*/.-]+' |
    sed 's/^[^t]//' | LC_ALL=C sort -u
}

function test_every_tests_path_named_by_any_workflow_resolves() {
  local unresolved=""
  local token
  while IFS= read -r token; do
    [ -z "$token" ] && continue
    case "$token" in
    */) continue ;;
    esac

    local found=0
    local match
    for match in $token; do
      if [ -e "$match" ]; then
        found=1
        break
      fi
    done

    if [ "$found" -eq 0 ]; then
      unresolved="$unresolved$token
"
    fi
  done <<EOF
$(cd "$ROOT_DIR" && ci_referenced_test_paths | "$GREP" -v '^tests/$')
EOF

  assert_empty "$unresolved"
}
