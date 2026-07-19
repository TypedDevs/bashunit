#!/usr/bin/env bash

# Tests for tools/coverage_percent.sh: extract a single rounded coverage
# percentage from an LCOV report by summing the per-section LH/LF records.

# cwd-relative (repo root), not $BASHUNIT_ROOT_DIR: under `build.sh --verify`
# the running binary's root dir has no tools/ (#834).
COVERAGE_PERCENT_SCRIPT="tools/coverage_percent.sh"

function test_coverage_percent_sums_lh_over_lf() {
  local lcov
  lcov=$(mktemp)
  cat >"$lcov" <<'EOF'
TN:
SF:/repo/src/a.sh
DA:1,1
LF:100
LH:25
end_of_record
EOF

  assert_equals "25" "$(bash "$COVERAGE_PERCENT_SCRIPT" "$lcov")"
  rm -f "$lcov"
}

function test_coverage_percent_aggregates_multiple_sections() {
  local lcov
  lcov=$(mktemp)
  cat >"$lcov" <<'EOF'
SF:/repo/src/a.sh
LF:100
LH:40
end_of_record
SF:/repo/src/b.sh
LF:100
LH:60
end_of_record
EOF

  # (40 + 60) / (100 + 100) = 50%
  assert_equals "50" "$(bash "$COVERAGE_PERCENT_SCRIPT" "$lcov")"
  rm -f "$lcov"
}

function test_coverage_percent_rounds_to_nearest_integer() {
  local lcov
  lcov=$(mktemp)
  cat >"$lcov" <<'EOF'
SF:/repo/src/a.sh
LF:3
LH:2
end_of_record
EOF

  # 2/3 = 66.6% -> 67
  assert_equals "67" "$(bash "$COVERAGE_PERCENT_SCRIPT" "$lcov")"
  rm -f "$lcov"
}

function test_coverage_percent_is_zero_when_no_lines_found() {
  local lcov
  lcov=$(mktemp)
  cat >"$lcov" <<'EOF'
TN:
end_of_record
EOF

  assert_equals "0" "$(bash "$COVERAGE_PERCENT_SCRIPT" "$lcov")"
  rm -f "$lcov"
}

function test_coverage_percent_is_zero_for_missing_file() {
  assert_equals "0" "$(bash "$COVERAGE_PERCENT_SCRIPT" "/no/such/lcov.info")"
}
