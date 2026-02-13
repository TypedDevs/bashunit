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

# === Coverage class tests ===

function test_coverage_get_coverage_class_returns_high() {
  local result
  export BASHUNIT_COVERAGE_THRESHOLD_HIGH=80
  export BASHUNIT_COVERAGE_THRESHOLD_LOW=50
  result=$(bashunit::coverage::get_coverage_class 85)
  assert_equals "high" "$result"
}

function test_coverage_get_coverage_class_returns_medium() {
  local result
  export BASHUNIT_COVERAGE_THRESHOLD_HIGH=80
  export BASHUNIT_COVERAGE_THRESHOLD_LOW=50
  result=$(bashunit::coverage::get_coverage_class 65)
  assert_equals "medium" "$result"
}

function test_coverage_get_coverage_class_returns_low() {
  local result
  export BASHUNIT_COVERAGE_THRESHOLD_HIGH=80
  export BASHUNIT_COVERAGE_THRESHOLD_LOW=50
  result=$(bashunit::coverage::get_coverage_class 30)
  assert_equals "low" "$result"
}

function test_coverage_get_coverage_class_boundary_high() {
  local result
  export BASHUNIT_COVERAGE_THRESHOLD_HIGH=80
  export BASHUNIT_COVERAGE_THRESHOLD_LOW=50
  result=$(bashunit::coverage::get_coverage_class 80)
  assert_equals "high" "$result"
}

function test_coverage_get_coverage_class_boundary_low() {
  local result
  export BASHUNIT_COVERAGE_THRESHOLD_HIGH=80
  export BASHUNIT_COVERAGE_THRESHOLD_LOW=50
  result=$(bashunit::coverage::get_coverage_class 50)
  assert_equals "medium" "$result"
}

# === Percentage calculation tests ===

function test_coverage_calculate_percentage_basic() {
  local result
  result=$(bashunit::coverage::calculate_percentage 5 10)
  assert_equals "50" "$result"
}

function test_coverage_calculate_percentage_full_coverage() {
  local result
  result=$(bashunit::coverage::calculate_percentage 100 100)
  assert_equals "100" "$result"
}

function test_coverage_calculate_percentage_zero_hits() {
  local result
  result=$(bashunit::coverage::calculate_percentage 0 50)
  assert_equals "0" "$result"
}

function test_coverage_calculate_percentage_zero_executable() {
  local result
  result=$(bashunit::coverage::calculate_percentage 0 0)
  assert_equals "0" "$result"
}

# === HTML escape tests ===

function test_coverage_html_escape_ampersand() {
  local result
  result=$(bashunit::coverage::html_escape 'foo & bar')
  assert_equals 'foo &amp; bar' "$result"
}

function test_coverage_html_escape_less_than() {
  local result
  result=$(bashunit::coverage::html_escape 'x < y')
  assert_equals 'x &lt; y' "$result"
}

function test_coverage_html_escape_greater_than() {
  local result
  result=$(bashunit::coverage::html_escape 'x > y')
  assert_equals 'x &gt; y' "$result"
}

function test_coverage_html_escape_combined() {
  local result
  # shellcheck disable=SC2016 # Single quotes intentional - testing literal string escaping
  result=$(bashunit::coverage::html_escape 'if [[ $a < $b && $c > $d ]]; then')
  # shellcheck disable=SC2016
  assert_equals 'if [[ $a &lt; $b &amp;&amp; $c &gt; $d ]]; then' "$result"
}

# === Path to filename tests ===

function test_coverage_path_to_filename_converts_slashes() {
  cd /tmp || return
  local result
  result=$(bashunit::coverage::path_to_filename '/tmp/src/lib/utils.sh')
  assert_equals 'src_lib_utils_sh' "$result"
}

function test_coverage_path_to_filename_handles_dots() {
  cd /tmp || return
  local result
  result=$(bashunit::coverage::path_to_filename '/tmp/test.spec.sh')
  assert_equals 'test_spec_sh' "$result"
}

# === Extract functions tests ===

function test_coverage_extract_functions_finds_basic_function() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
function my_func() {
  echo "hello"
}
EOF

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_contains "my_func" "$result"

  rm -f "$temp_file"
}

function test_coverage_extract_functions_finds_namespaced_function() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
function bashunit::helper::do_thing() {
  echo "hello"
}
EOF

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_contains "bashunit::helper::do_thing" "$result"

  rm -f "$temp_file"
}

function test_coverage_extract_functions_finds_multiple_functions() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
function func_one() {
  echo "one"
}
function func_two() {
  echo "two"
}
EOF

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_contains "func_one" "$result"
  assert_contains "func_two" "$result"

  rm -f "$temp_file"
}

# === Line hits tests ===

function test_coverage_get_line_hits_returns_zero_when_no_file() {
  _BASHUNIT_COVERAGE_DATA_FILE=""

  local result
  result=$(bashunit::coverage::get_line_hits "/path/to/file.sh" 10)

  assert_equals "0" "$result"
}

function test_coverage_get_line_hits_counts_correctly() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local test_file="/test/script.sh"
  {
    echo "${test_file}:5"
    echo "${test_file}:5"
    echo "${test_file}:5"
  } >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local result
  result=$(bashunit::coverage::get_line_hits "$test_file" 5)

  assert_equals "3" "$result"
}
