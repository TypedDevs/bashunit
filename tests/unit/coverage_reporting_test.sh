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

function test_coverage_check_threshold_passes_when_no_minimum() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_MIN=""
  bashunit::coverage::init

  assert_successful_code "bashunit::coverage::check_threshold"
}

function test_coverage_check_threshold_fails_when_below_minimum() {
  BASHUNIT_COVERAGE="true"
  BASHUNIT_COVERAGE_MIN="80"
  bashunit::coverage::init

  # Create a tracked file with some executable lines but no hits
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "line 1"
echo "line 2"
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  # Capture only the exit code, suppress output
  local result
  if bashunit::coverage::check_threshold >/dev/null 2>&1; then
    result="passed"
  else
    result="failed"
  fi

  assert_equals "failed" "$result"

  rm -f "$temp_file"
}

function test_coverage_report_lcov_generates_valid_format() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  # Create a test source file
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "line 1"
echo "line 2"
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  # Simulate some hits
  echo "${temp_file}:2" >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  # Generate report to temp file
  local report_file
  report_file=$(mktemp)
  bashunit::coverage::report_lcov "$report_file"

  local content
  content=$(cat "$report_file")

  # Line 1 (shebang) is not counted - only lines 2 and 3 are executable
  assert_contains "TN:" "$content"
  assert_contains "SF:${temp_file}" "$content"
  assert_contains "DA:2," "$content"
  assert_contains "DA:3," "$content"
  assert_contains "LF:2" "$content"
  assert_contains "end_of_record" "$content"

  rm -f "$temp_file" "$report_file"
}

function test_coverage_report_lcov_completes_under_set_e() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "line 1"
echo "line 2"
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  local report_file
  report_file=$(mktemp)

  # ((lineno++)) when lineno=0 returns exit code 1 under set -e
  # causing incomplete LCOV output (#618)
  (
    set -e
    bashunit::coverage::report_lcov "$report_file"
  )

  local content
  content=$(cat "$report_file")

  assert_contains "end_of_record" "$content"
  assert_contains "DA:2," "$content"
  assert_contains "DA:3," "$content"

  rm -f "$temp_file" "$report_file"
}

function test_coverage_report_text_shows_no_files_message() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  # Empty tracked files
  : >"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  local output
  output=$(bashunit::coverage::report_text)

  assert_contains "Total: 0/0 (0%)" "$output"
}

function test_coverage_get_tracked_files_returns_empty_when_no_file() {
  _BASHUNIT_COVERAGE_TRACKED_FILES=""

  local result
  result=$(bashunit::coverage::get_tracked_files)

  assert_empty "$result"
}

function test_coverage_get_tracked_files_returns_sorted_unique() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  {
    echo "/path/to/b.sh"
    echo "/path/to/a.sh"
    echo "/path/to/b.sh"
  } >>"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  local result
  result=$(bashunit::coverage::get_tracked_files | tr '\n' ' ')

  # Should be sorted and unique
  assert_equals "/path/to/a.sh /path/to/b.sh " "$result"
}

function test_coverage_get_file_stats_returns_formatted_string() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  # Create a test file with known content
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "line 1"
echo "line 2"
EOF

  # No hits recorded, so 0% coverage
  local result
  result=$(bashunit::coverage::get_file_stats "$temp_file")

  # Format: executable:hit:pct:class
  assert_matches "^2:0:0:low$" "$result"

  rm -f "$temp_file"
}

function test_coverage_get_hit_lines_returns_zero_when_no_data() {
  _BASHUNIT_COVERAGE_DATA_FILE=""

  local result
  result=$(bashunit::coverage::get_hit_lines "/path/to/file.sh")

  assert_equals "0" "$result"
}

function test_coverage_compute_file_coverage_returns_executable_and_hit_counts() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "line 1"
echo "line 2"
echo "line 3"
EOF

  {
    echo "${temp_file}:2"
    echo "${temp_file}:3"
  } >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local result
  result=$(bashunit::coverage::compute_file_coverage "$temp_file")

  assert_equals "3:2" "$result"

  rm -f "$temp_file"
}

function test_coverage_compute_file_coverage_zero_hits() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "line 1"
echo "line 2"
EOF

  local result
  result=$(bashunit::coverage::compute_file_coverage "$temp_file")

  assert_equals "2:0" "$result"

  rm -f "$temp_file"
}

function test_coverage_compute_file_coverage_ignores_non_executable_hits() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
# comment
echo "line 3"
EOF

  {
    echo "${temp_file}:1"
    echo "${temp_file}:2"
    echo "${temp_file}:3"
  } >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local result
  result=$(bashunit::coverage::compute_file_coverage "$temp_file")

  assert_equals "1:1" "$result"

  rm -f "$temp_file"
}

function test_coverage_precompute_file_stats_populates_cache() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "line 1"
echo "line 2"
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  bashunit::coverage::precompute_file_stats

  assert_equals "1" "$_BASHUNIT_COVERAGE_STATS_COUNT"
  assert_equals "$temp_file" "${_BASHUNIT_COVERAGE_STATS_FILES[0]}"
  assert_equals "2" "${_BASHUNIT_COVERAGE_STATS_EXEC[0]}"

  rm -f "$temp_file"
}

function test_coverage_get_cached_stats_returns_same_as_get_file_stats() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "line 1"
echo "line 2"
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  bashunit::coverage::precompute_file_stats

  local cached direct
  cached=$(bashunit::coverage::get_cached_stats "$temp_file")
  direct=$(bashunit::coverage::get_file_stats "$temp_file")

  assert_equals "$direct" "$cached"

  rm -f "$temp_file"
}

function test_coverage_get_cached_stats_falls_back_when_not_cached() {
  _BASHUNIT_COVERAGE_STATS_COUNT=0

  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "line 1"
echo "line 2"
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  local cached direct
  cached=$(bashunit::coverage::get_cached_stats "$temp_file")
  direct=$(bashunit::coverage::get_file_stats "$temp_file")

  assert_equals "$direct" "$cached"

  rm -f "$temp_file"
}

function test_coverage_report_lcov_includes_function_records() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
function alpha() {
  echo "in alpha"
}
function beta() {
  echo "in beta"
}
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  # Hit alpha body (line 3) only; beta body (line 6) not hit
  echo "${temp_file}:3" >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local report_file
  report_file=$(mktemp)
  bashunit::coverage::report_lcov "$report_file"

  local content
  content=$(cat "$report_file")

  assert_contains "FN:2,alpha" "$content"
  assert_contains "FN:5,beta" "$content"
  assert_contains "FNDA:1,alpha" "$content"
  assert_contains "FNDA:0,beta" "$content"
  assert_contains "FNF:2" "$content"
  assert_contains "FNH:1" "$content"

  rm -f "$temp_file" "$report_file"
}

function test_coverage_report_text_includes_function_summary_when_enabled() {
  BASHUNIT_COVERAGE="true"
  export BASHUNIT_COVERAGE_SHOW_FUNCTIONS="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
function alpha() {
  echo "alpha"
}
function beta() {
  echo "beta"
}
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"
  echo "${temp_file}:3" >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local output
  output=$(bashunit::coverage::report_text)

  assert_contains "alpha" "$output"
  assert_contains "beta" "$output"
  assert_contains "Functions" "$output"

  unset BASHUNIT_COVERAGE_SHOW_FUNCTIONS
  rm -f "$temp_file"
}

function test_coverage_report_text_omits_function_summary_by_default() {
  BASHUNIT_COVERAGE="true"
  unset BASHUNIT_COVERAGE_SHOW_FUNCTIONS
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
function only_fn() {
  echo "x"
}
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  local output
  output=$(bashunit::coverage::report_text)

  assert_not_contains "only_fn" "$output"

  rm -f "$temp_file"
}

function test_coverage_html_renders_test_attribution_tooltip() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "covered line"
EOF

  echo "${temp_file}:2" >>"$_BASHUNIT_COVERAGE_DATA_FILE"
  echo "${temp_file}:2|tests/unit/sample_test.sh:test_should_do_thing" \
    >>"$_BASHUNIT_COVERAGE_TEST_HITS_FILE"

  local out_html
  out_html=$(mktemp)
  bashunit::coverage::generate_file_html "$temp_file" "$out_html"

  local content
  content=$(cat "$out_html")

  assert_contains 'class="hits-tooltip"' "$content"
  assert_contains "Tests hitting this line" "$content"
  assert_contains "sample_test.sh" "$content"
  assert_contains "test_should_do_thing" "$content"
  assert_contains 'class="hits-badge has-tooltip"' "$content"

  rm -f "$temp_file" "$out_html"
}

function test_coverage_html_tooltip_dedupes_repeated_test_hits() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "covered"
EOF

  echo "${temp_file}:2" >>"$_BASHUNIT_COVERAGE_DATA_FILE"
  # Same test recorded multiple times (typical for loops)
  {
    echo "${temp_file}:2|tests/unit/dup_test.sh:test_one"
    echo "${temp_file}:2|tests/unit/dup_test.sh:test_one"
    echo "${temp_file}:2|tests/unit/dup_test.sh:test_one"
  } >>"$_BASHUNIT_COVERAGE_TEST_HITS_FILE"

  local out_html
  out_html=$(mktemp)
  bashunit::coverage::generate_file_html "$temp_file" "$out_html"

  local count
  count=$(grep -c "test_one</span>" "$out_html" || true)

  # Tooltip should list test_one exactly once despite multiple records
  assert_equals "1" "$count"

  rm -f "$temp_file" "$out_html"
}

function test_coverage_html_omits_tooltip_when_no_test_data() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "no tests recorded"
EOF

  echo "${temp_file}:2" >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local out_html
  out_html=$(mktemp)
  bashunit::coverage::generate_file_html "$temp_file" "$out_html"

  local content
  content=$(cat "$out_html")

  assert_not_contains "Tests hitting this line" "$content"
  assert_not_contains 'class="hits-badge has-tooltip"' "$content"

  rm -f "$temp_file" "$out_html"
}

function test_coverage_html_index_contains_overall_metrics() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "a"
echo "b"
echo "c"
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"
  {
    echo "${temp_file}:2"
    echo "${temp_file}:3"
  } >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local out_dir
  out_dir=$(mktemp -d)

  bashunit::coverage::report_html "$out_dir" >/dev/null

  assert_file_exists "$out_dir/index.html"

  local index
  index=$(cat "$out_dir/index.html")

  assert_contains "Code Coverage Report" "$index"
  assert_contains "Overall Code Coverage" "$index"
  # 2 of 3 executable lines hit -> 66%
  assert_contains "66%" "$index"
  assert_contains "$(basename "$temp_file")" "$index"

  rm -rf "$out_dir"
  rm -f "$temp_file"
}

function test_coverage_html_index_creates_per_file_pages() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "covered"
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"
  echo "${temp_file}:2" >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local out_dir
  out_dir=$(mktemp -d)

  bashunit::coverage::report_html "$out_dir" >/dev/null

  # Per-file HTML page exists under files/
  local file_pages
  file_pages=$(find "$out_dir/files/" -maxdepth 1 -type f -name '*.html' | wc -l | tr -d ' ')
  assert_equals "1" "$file_pages"

  rm -rf "$out_dir"
  rm -f "$temp_file"
}

function test_coverage_html_file_page_marks_covered_and_uncovered_rows() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "covered"
echo "uncovered"
EOF

  echo "${temp_file}:2" >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local out_html
  out_html=$(mktemp)
  bashunit::coverage::generate_file_html "$temp_file" "$out_html"

  local content
  content=$(cat "$out_html")

  assert_contains 'class="covered line-anchor"' "$content"
  assert_contains 'class="uncovered line-anchor"' "$content"
  # Line 1 (shebang) is non-executable -> no covered/uncovered class
  assert_contains 'id="line-1" class=" line-anchor"' "$content"

  rm -f "$temp_file" "$out_html"
}

function test_coverage_html_file_page_escapes_special_chars() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "<tag> & 'quote'"
EOF

  local out_html
  out_html=$(mktemp)
  bashunit::coverage::generate_file_html "$temp_file" "$out_html"

  local content
  content=$(cat "$out_html")

  assert_contains "&lt;tag&gt;" "$content"
  assert_contains "&amp;" "$content"
  # Raw <tag> must not appear in the code cell content
  assert_not_contains '<td class="code">echo "<tag>' "$content"

  rm -f "$temp_file" "$out_html"
}

function test_coverage_report_text_lists_uncovered_hotspots_when_enabled() {
  BASHUNIT_COVERAGE="true"
  export BASHUNIT_COVERAGE_SHOW_UNCOVERED="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "covered"
echo "uncovered-1"
echo "uncovered-2"
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"
  echo "${temp_file}:2" >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local output
  output=$(bashunit::coverage::report_text)

  assert_contains "Uncovered" "$output"
  # Lines 3 and 4 are uncovered, rendered as a compressed range "3-4"
  assert_contains "3-4" "$output"

  unset BASHUNIT_COVERAGE_SHOW_UNCOVERED
  rm -f "$temp_file"
}

function test_coverage_report_text_uncovered_renders_singletons_separately() {
  BASHUNIT_COVERAGE="true"
  export BASHUNIT_COVERAGE_SHOW_UNCOVERED="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "uncovered-2"
echo "covered-3"
echo "uncovered-4"
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"
  echo "${temp_file}:3" >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local output
  output=$(bashunit::coverage::report_text)

  # Non-consecutive uncovered lines stay as individual entries
  assert_contains "2,4" "$output"

  unset BASHUNIT_COVERAGE_SHOW_UNCOVERED
  rm -f "$temp_file"
}

function test_coverage_report_text_omits_uncovered_section_by_default() {
  BASHUNIT_COVERAGE="true"
  unset BASHUNIT_COVERAGE_SHOW_UNCOVERED
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "uncovered"
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  local output
  output=$(bashunit::coverage::report_text)

  assert_not_contains "Uncovered" "$output"

  rm -f "$temp_file"
}

function test_coverage_report_text_skips_uncovered_section_when_no_misses() {
  BASHUNIT_COVERAGE="true"
  export BASHUNIT_COVERAGE_SHOW_UNCOVERED="true"
  bashunit::coverage::init

  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "covered"
EOF

  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"
  echo "${temp_file}:2" >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local output
  output=$(bashunit::coverage::report_text)

  assert_not_contains "Uncovered" "$output"

  unset BASHUNIT_COVERAGE_SHOW_UNCOVERED
  rm -f "$temp_file"
}
