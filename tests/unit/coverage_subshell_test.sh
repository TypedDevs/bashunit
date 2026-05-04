#!/usr/bin/env bash
# shellcheck disable=SC2317

# Subshell tracking edge cases.
# bashunit relies on `set -T` plus the DEBUG trap so child shell contexts
# inherit the recorder. These tests pin the documented behavior so future
# regressions surface as failing tests instead of silent gaps.

_ORIG_COVERAGE_DATA_FILE=""
_ORIG_COVERAGE_TRACKED_FILES=""
_ORIG_COVERAGE_TRACKED_CACHE_FILE=""
_ORIG_COVERAGE_TEST_HITS_FILE=""
_ORIG_COVERAGE=""
_ORIG_COVERAGE_PATHS=""
_ORIG_COVERAGE_EXCLUDE=""

# Whole-suite skip: enabling the DEBUG trap inside a parallel test
# worker process makes the worker fire the trap on every internal
# coordination command, which combines with file-I/O contention on
# /tmp to deadlock CI runners. The contracts tested here are
# deterministic in single-process mode, so the parallel run is not
# a useful execution context.
function _skip_when_parallel_or_windows() {
  if [ "${BASHUNIT_PARALLEL_RUN:-false}" = "true" ]; then
    bashunit::skip "subshell tracking tests require single-process execution"
    return 0
  fi
  case "$(uname -s 2>/dev/null)" in
  CYGWIN* | MINGW* | MSYS*)
    bashunit::skip "DEBUG trap + set -T behavior is unstable on Git Bash"
    return 0
    ;;
  esac
  return 1
}

function set_up() {
  _ORIG_COVERAGE_DATA_FILE="$_BASHUNIT_COVERAGE_DATA_FILE"
  _ORIG_COVERAGE_TRACKED_FILES="$_BASHUNIT_COVERAGE_TRACKED_FILES"
  _ORIG_COVERAGE_TRACKED_CACHE_FILE="$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
  _ORIG_COVERAGE_TEST_HITS_FILE="$_BASHUNIT_COVERAGE_TEST_HITS_FILE"
  _ORIG_COVERAGE="${BASHUNIT_COVERAGE:-}"
  _ORIG_COVERAGE_PATHS="${BASHUNIT_COVERAGE_PATHS:-}"
  _ORIG_COVERAGE_EXCLUDE="${BASHUNIT_COVERAGE_EXCLUDE:-}"

  _BASHUNIT_COVERAGE_DATA_FILE=""
  _BASHUNIT_COVERAGE_TRACKED_FILES=""
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE=""
  _BASHUNIT_COVERAGE_TEST_HITS_FILE=""
  export BASHUNIT_COVERAGE="true"
  export BASHUNIT_COVERAGE_PATHS="${TMPDIR:-/tmp}"
  export BASHUNIT_COVERAGE_EXCLUDE="*_test.sh"
}

function tear_down() {
  trap - DEBUG
  set +T

  if [ -n "$_BASHUNIT_COVERAGE_DATA_FILE" ] &&
    [ "$_BASHUNIT_COVERAGE_DATA_FILE" != "$_ORIG_COVERAGE_DATA_FILE" ]; then
    local coverage_dir
    coverage_dir=$(dirname "$_BASHUNIT_COVERAGE_DATA_FILE")
    rm -rf "$coverage_dir" 2>/dev/null || true
  fi

  _BASHUNIT_COVERAGE_DATA_FILE="$_ORIG_COVERAGE_DATA_FILE"
  _BASHUNIT_COVERAGE_TRACKED_FILES="$_ORIG_COVERAGE_TRACKED_FILES"
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE="$_ORIG_COVERAGE_TRACKED_CACHE_FILE"
  _BASHUNIT_COVERAGE_TEST_HITS_FILE="$_ORIG_COVERAGE_TEST_HITS_FILE"

  if [ -n "$_ORIG_COVERAGE" ]; then
    export BASHUNIT_COVERAGE="$_ORIG_COVERAGE"
  else
    unset BASHUNIT_COVERAGE
  fi
  if [ -n "$_ORIG_COVERAGE_PATHS" ]; then
    export BASHUNIT_COVERAGE_PATHS="$_ORIG_COVERAGE_PATHS"
  else
    unset BASHUNIT_COVERAGE_PATHS
  fi
  if [ -n "$_ORIG_COVERAGE_EXCLUDE" ]; then
    export BASHUNIT_COVERAGE_EXCLUDE="$_ORIG_COVERAGE_EXCLUDE"
  else
    unset BASHUNIT_COVERAGE_EXCLUDE
  fi
}

# Helper: run a fixture under coverage tracking and return how many
# distinct hit lines were recorded for it.
function _run_fixture_under_coverage() {
  local fixture="$1"
  bashunit::coverage::init
  echo "$fixture" >>"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  bashunit::coverage::enable_trap
  # shellcheck disable=SC1090
  source "$fixture" >/dev/null 2>&1
  bashunit::coverage::disable_trap

  # When the suite itself runs in parallel mode, hits are flushed to a
  # per-PID data file. Aggregate so the assertion below sees them.
  bashunit::coverage::aggregate_parallel

  bashunit::coverage::get_all_line_hits "$fixture" | wc -l | tr -d ' '
}

function test_coverage_records_lines_inside_command_substitution() {
  _skip_when_parallel_or_windows && return 0
  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
result=$(echo "inside-subst")
echo "after $result"
EOF

  local hit_count
  hit_count=$(_run_fixture_under_coverage "$fixture")

  # Documented limitation: the outer line containing $(...) is recorded,
  # but the command inside the subshell does not propagate hits back to
  # the parent's coverage data file. Both outer lines should be hit.
  assert_equals "2" "$hit_count"

  rm -f "$fixture"
}

function test_coverage_records_explicit_subshell_block() {
  _skip_when_parallel_or_windows && return 0
  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
(
  echo "in subshell"
)
echo "after"
EOF

  local hit_count
  hit_count=$(_run_fixture_under_coverage "$fixture")

  # Documented limitation: writes from inside ( ... ) hit the in-memory
  # buffer of the subshell, which is discarded on subshell exit. Only
  # the outer `echo "after"` line is recorded back in the parent.
  assert_equals "1" "$hit_count"

  rm -f "$fixture"
}

function test_coverage_records_pipeline_lhs() {
  _skip_when_parallel_or_windows && return 0
  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
echo "one" | cat >/dev/null
echo "two"
EOF

  local hit_count
  hit_count=$(_run_fixture_under_coverage "$fixture")

  # Each pipeline source line is recorded once (the pipeline as a unit).
  assert_equals "2" "$hit_count"

  rm -f "$fixture"
}

function test_coverage_records_process_substitution_consumer() {
  _skip_when_parallel_or_windows && return 0
  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
while read -r _line; do
  : "$_line"
done < <(echo "a")
echo "after"
EOF

  local hit_count
  hit_count=$(_run_fixture_under_coverage "$fixture")

  # Consumer side of <(...) is tracked: the `while` line, the loop body,
  # and the trailing echo (3 distinct hit lines).
  assert_equals "3" "$hit_count"

  rm -f "$fixture"
}

function test_coverage_records_lines_inside_function_called_from_subshell() {
  _skip_when_parallel_or_windows && return 0
  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
function _sub_helper() {
  echo "in helper"
}
result=$(_sub_helper)
echo "after $result"
EOF

  local hit_count
  hit_count=$(_run_fixture_under_coverage "$fixture")

  # Documented limitation: the function body runs inside the $(...)
  # subshell, so its hits are lost. Only the caller line and trailing
  # echo are recorded in the parent's data file.
  assert_equals "2" "$hit_count"

  rm -f "$fixture"
}
