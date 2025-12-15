#!/usr/bin/env bash
# shellcheck disable=SC2317

function set_up() {
  # Reset coverage state
  _BASHUNIT_COVERAGE_DATA_FILE=""
  _BASHUNIT_COVERAGE_TRACKED_FILES=""
  export BASHUNIT_COVERAGE="false"
  export BASHUNIT_COVERAGE_PATHS="src/"
  export BASHUNIT_COVERAGE_EXCLUDE="tests/*,vendor/*,*_test.sh,*Test.sh"
  export BASHUNIT_COVERAGE_REPORT=""
  export BASHUNIT_COVERAGE_MIN=""
}

function tear_down() {
  # Clean up any coverage temp files
  if [[ -n "$_BASHUNIT_COVERAGE_DATA_FILE" ]]; then
    local coverage_dir
    coverage_dir=$(dirname "$_BASHUNIT_COVERAGE_DATA_FILE")
    rm -rf "$coverage_dir" 2>/dev/null || true
  fi
  unset BASHUNIT_COVERAGE
  unset BASHUNIT_COVERAGE_PATHS
  unset BASHUNIT_COVERAGE_EXCLUDE
  unset BASHUNIT_COVERAGE_REPORT
  unset BASHUNIT_COVERAGE_MIN
}

function test_coverage_disabled_by_default() {
  assert_equals "false" "$BASHUNIT_COVERAGE"
}

function test_is_coverage_enabled_returns_false_when_disabled() {
  BASHUNIT_COVERAGE="false"
  assert_false "bashunit::env::is_coverage_enabled"
}

function test_is_coverage_enabled_returns_true_when_enabled() {
  BASHUNIT_COVERAGE="true"
  assert_true "bashunit::env::is_coverage_enabled"
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

  assert_false "bashunit::coverage::should_track '/path/to/my_test.sh'"
}

function test_coverage_should_track_excludes_vendor() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_PATHS=""
  BASHUNIT_COVERAGE_EXCLUDE="vendor/*"
  bashunit::coverage::init

  assert_false "bashunit::coverage::should_track '/project/vendor/lib.sh'"
}

function test_coverage_should_track_excludes_bashunit_src() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  assert_false "bashunit::coverage::should_track '/path/to/bashunit/src/runner.sh'"
}

function test_coverage_get_executable_lines_counts_correctly() {
  local temp_file
  temp_file=$(mktemp)

  cat > "$temp_file" << 'EOF'
#!/usr/bin/env bash

# This is a comment
function my_func() {
  echo "hello"
  echo "world"
}

my_func
EOF

  # Expected executable lines:
  # Line 1: shebang (counted)
  # Line 3: comment (not counted)
  # Line 4: function declaration (not counted)
  # Line 5: echo "hello" (counted)
  # Line 6: echo "world" (counted)
  # Line 7: } (not counted)
  # Line 9: my_func (counted)
  # Total: 4 executable lines

  local count
  count=$(bashunit::coverage::get_executable_lines "$temp_file")

  assert_equals "4" "$count"

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

  local content
  content=$(cat "$_BASHUNIT_COVERAGE_DATA_FILE")

  assert_contains "$test_file:10" "$content"
  assert_contains "$test_file:20" "$content"
}

function test_coverage_check_threshold_passes_when_no_minimum() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_MIN=""
  bashunit::coverage::init

  assert_successful_code "bashunit::coverage::check_threshold"
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

function test_coverage_default_paths_is_src() {
  assert_equals "src/" "$_BASHUNIT_DEFAULT_COVERAGE_PATHS"
}

function test_coverage_default_report_is_lcov() {
  assert_equals "coverage/lcov.info" "$_BASHUNIT_DEFAULT_COVERAGE_REPORT"
}

function test_coverage_default_threshold_low_is_50() {
  assert_equals "50" "$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_LOW"
}

function test_coverage_default_threshold_high_is_80() {
  assert_equals "80" "$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_HIGH"
}
