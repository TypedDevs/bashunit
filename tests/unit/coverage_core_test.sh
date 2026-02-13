#!/usr/bin/env bash
# shellcheck disable=SC2317

# Save original coverage state to restore after tests
_ORIG_COVERAGE_DATA_FILE=""
_ORIG_COVERAGE_TRACKED_FILES=""
_ORIG_COVERAGE_TRACKED_CACHE_FILE=""
_ORIG_COVERAGE=""
_ORIG_COVERAGE_PATHS=""
_ORIG_COVERAGE_EXCLUDE=""
_ORIG_COVERAGE_REPORT=""
_ORIG_COVERAGE_MIN=""

function set_up() {
  # Save original coverage state
  _ORIG_COVERAGE_DATA_FILE="$_BASHUNIT_COVERAGE_DATA_FILE"
  _ORIG_COVERAGE_TRACKED_FILES="$_BASHUNIT_COVERAGE_TRACKED_FILES"
  _ORIG_COVERAGE_TRACKED_CACHE_FILE="$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
  _ORIG_COVERAGE="${BASHUNIT_COVERAGE:-}"
  _ORIG_COVERAGE_PATHS="${BASHUNIT_COVERAGE_PATHS:-}"
  _ORIG_COVERAGE_EXCLUDE="${BASHUNIT_COVERAGE_EXCLUDE:-}"
  _ORIG_COVERAGE_REPORT="${BASHUNIT_COVERAGE_REPORT:-}"
  _ORIG_COVERAGE_MIN="${BASHUNIT_COVERAGE_MIN:-}"

  # Reset coverage state for testing
  _BASHUNIT_COVERAGE_DATA_FILE=""
  _BASHUNIT_COVERAGE_TRACKED_FILES=""
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE=""
  export BASHUNIT_COVERAGE="false"
  export BASHUNIT_COVERAGE_PATHS="src/"
  export BASHUNIT_COVERAGE_EXCLUDE="tests/*,vendor/*,*_test.sh,*Test.sh"
  export BASHUNIT_COVERAGE_REPORT=""
  export BASHUNIT_COVERAGE_MIN=""
}

function tear_down() {
  # Clean up any coverage temp files created by tests
  if [[ -n "$_BASHUNIT_COVERAGE_DATA_FILE" && "$_BASHUNIT_COVERAGE_DATA_FILE" != "$_ORIG_COVERAGE_DATA_FILE" ]]; then
    local coverage_dir
    coverage_dir=$(dirname "$_BASHUNIT_COVERAGE_DATA_FILE")
    rm -rf "$coverage_dir" 2>/dev/null || true
  fi

  # Restore original coverage state
  _BASHUNIT_COVERAGE_DATA_FILE="$_ORIG_COVERAGE_DATA_FILE"
  _BASHUNIT_COVERAGE_TRACKED_FILES="$_ORIG_COVERAGE_TRACKED_FILES"
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE="$_ORIG_COVERAGE_TRACKED_CACHE_FILE"
  if [[ -n "$_ORIG_COVERAGE" ]]; then
    export BASHUNIT_COVERAGE="$_ORIG_COVERAGE"
  else
    unset BASHUNIT_COVERAGE
  fi
  if [[ -n "$_ORIG_COVERAGE_PATHS" ]]; then
    export BASHUNIT_COVERAGE_PATHS="$_ORIG_COVERAGE_PATHS"
  else
    unset BASHUNIT_COVERAGE_PATHS
  fi
  if [[ -n "$_ORIG_COVERAGE_EXCLUDE" ]]; then
    export BASHUNIT_COVERAGE_EXCLUDE="$_ORIG_COVERAGE_EXCLUDE"
  else
    unset BASHUNIT_COVERAGE_EXCLUDE
  fi
  if [[ -n "$_ORIG_COVERAGE_REPORT" ]]; then
    export BASHUNIT_COVERAGE_REPORT="$_ORIG_COVERAGE_REPORT"
  else
    unset BASHUNIT_COVERAGE_REPORT
  fi
  if [[ -n "$_ORIG_COVERAGE_MIN" ]]; then
    export BASHUNIT_COVERAGE_MIN="$_ORIG_COVERAGE_MIN"
  else
    unset BASHUNIT_COVERAGE_MIN
  fi
}

function test_coverage_disabled_by_default() {
  assert_equals "false" "$BASHUNIT_COVERAGE"
}

function test_is_coverage_enabled_returns_false_when_disabled() {
  BASHUNIT_COVERAGE="false"
  # Use subshell to capture exit code without triggering errexit
  local result
  result=$(bashunit::env::is_coverage_enabled && echo "true" || echo "false")
  assert_equals "false" "$result"
}

function test_is_coverage_enabled_returns_true_when_enabled() {
  BASHUNIT_COVERAGE="true"
  local result
  result=$(bashunit::env::is_coverage_enabled && echo "true" || echo "false")
  assert_equals "true" "$result"
}

function test_coverage_init_creates_temp_files() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  assert_not_empty "$_BASHUNIT_COVERAGE_DATA_FILE"
  assert_not_empty "$_BASHUNIT_COVERAGE_TRACKED_FILES"
  assert_file_exists "$_BASHUNIT_COVERAGE_DATA_FILE"
  assert_file_exists "$_BASHUNIT_COVERAGE_TRACKED_FILES"
}

function test_coverage_init_does_nothing_when_disabled() {
  BASHUNIT_COVERAGE="false"
  bashunit::coverage::init

  assert_empty "$_BASHUNIT_COVERAGE_DATA_FILE"
}

function test_coverage_should_track_excludes_test_files() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_PATHS=""
  BASHUNIT_COVERAGE_EXCLUDE="*_test.sh"
  bashunit::coverage::init

  # Use subshell to capture exit code without triggering errexit
  local result
  result=$(bashunit::coverage::should_track '/path/to/my_test.sh' && echo "tracked" || echo "excluded")
  assert_equals "excluded" "$result"
}

function test_coverage_should_track_excludes_vendor() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_PATHS=""
  BASHUNIT_COVERAGE_EXCLUDE="vendor/*"
  bashunit::coverage::init

  local result
  result=$(bashunit::coverage::should_track '/project/vendor/lib.sh' && echo "tracked" || echo "excluded")
  assert_equals "excluded" "$result"
}

function test_coverage_should_track_excludes_bashunit_src() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local result
  result=$(bashunit::coverage::should_track '/path/to/bashunit/src/runner.sh' && echo "tracked" || echo "excluded")
  assert_equals "excluded" "$result"
}

function test_coverage_get_executable_lines_counts_correctly() {
  local temp_file
  temp_file=$(mktemp)

  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash

# This is a comment
function my_func() {
  echo "hello"
  echo "world"
}

my_func
EOF

  # Expected executable lines:
  # Line 1: shebang (not counted - it's a comment)
  # Line 3: comment (not counted)
  # Line 4: function declaration (not counted)
  # Line 5: echo "hello" (counted)
  # Line 6: echo "world" (counted)
  # Line 7: } (not counted)
  # Line 9: my_func (counted)
  # Total: 3 executable lines

  local count
  count=$(bashunit::coverage::get_executable_lines "$temp_file")

  assert_equals "3" "$count"

  rm -f "$temp_file"
}

function test_coverage_record_line_writes_to_file() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_PATHS="/"
  BASHUNIT_COVERAGE_EXCLUDE=""
  bashunit::coverage::init

  local test_file="/some/path/script.sh"
  bashunit::coverage::record_line "$test_file" "10"
  bashunit::coverage::record_line "$test_file" "20"
  bashunit::coverage::record_line "$test_file" "10"

  # In parallel mode, data is written to a per-process file
  local data_file="$_BASHUNIT_COVERAGE_DATA_FILE"
  if bashunit::parallel::is_enabled; then
    data_file="${_BASHUNIT_COVERAGE_DATA_FILE}.$$"
  fi

  local content
  content=$(cat "$data_file")

  assert_contains "$test_file:10" "$content"
  assert_contains "$test_file:20" "$content"
}

function test_coverage_cleanup_removes_temp_files() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local coverage_dir
  coverage_dir=$(dirname "$_BASHUNIT_COVERAGE_DATA_FILE")

  assert_directory_exists "$coverage_dir"

  bashunit::coverage::cleanup

  assert_directory_not_exists "$coverage_dir"
}

function test_coverage_default_paths_is_empty_for_auto_discovery() {
  assert_equals "" "$_BASHUNIT_DEFAULT_COVERAGE_PATHS"
}

function test_coverage_should_track_caches_decisions() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_PATHS="/"
  BASHUNIT_COVERAGE_EXCLUDE=""
  bashunit::coverage::init

  local test_file="/some/path/script.sh"

  # First call should cache the decision
  bashunit::coverage::should_track "$test_file"

  # Verify cache file contains the decision
  # In parallel mode, cache is written to per-process file
  local cache_file="$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
  if bashunit::parallel::is_enabled; then
    cache_file="${cache_file}.$$"
  fi

  local cache_content
  cache_content=$(cat "$cache_file")

  assert_contains "${test_file}:" "$cache_content"
}
