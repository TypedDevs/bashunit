#!/usr/bin/env bash
# shellcheck disable=SC2317

# Tests for the branch-point extractor and branch-hit computation.
# See adrs/adr-007-branch-coverage-mvp.md for the design.

_ORIG_COVERAGE_DATA_FILE=""
_ORIG_COVERAGE_TRACKED_FILES=""
_ORIG_COVERAGE_TRACKED_CACHE_FILE=""
_ORIG_COVERAGE_TEST_HITS_FILE=""
_ORIG_COVERAGE=""

function set_up() {
  _ORIG_COVERAGE_DATA_FILE="$_BASHUNIT_COVERAGE_DATA_FILE"
  _ORIG_COVERAGE_TRACKED_FILES="$_BASHUNIT_COVERAGE_TRACKED_FILES"
  _ORIG_COVERAGE_TRACKED_CACHE_FILE="$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
  _ORIG_COVERAGE_TEST_HITS_FILE="$_BASHUNIT_COVERAGE_TEST_HITS_FILE"
  _ORIG_COVERAGE="${BASHUNIT_COVERAGE:-}"

  _BASHUNIT_COVERAGE_DATA_FILE=""
  _BASHUNIT_COVERAGE_TRACKED_FILES=""
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE=""
  _BASHUNIT_COVERAGE_TEST_HITS_FILE=""
  export BASHUNIT_COVERAGE="true"
}

function tear_down() {
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
}

# extract_branches output format:
#   <decision_line>|<kind>|<arm_start>:<arm_end>[,<arm_start>:<arm_end>]...
# kind ∈ {if, case}

function test_extract_branches_finds_simple_if_else() {
  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "x" ]; then
  echo "x"
else
  echo "not x"
fi
EOF

  local result
  result=$(bashunit::coverage::extract_branches "$fixture")

  # Decision on line 2 with two arms: then (line 3) and else (line 5)
  assert_contains "2|if|3:3,5:5" "$result"

  rm -f "$fixture"
}

function test_extract_branches_finds_if_elif_else_chain() {
  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "a" ]; then
  echo "a"
elif [ "$1" = "b" ]; then
  echo "b"
else
  echo "other"
fi
EOF

  local result
  result=$(bashunit::coverage::extract_branches "$fixture")

  # Three arms: then (line 3), elif body (line 5), else (line 7)
  assert_contains "2|if|3:3,5:5,7:7" "$result"

  rm -f "$fixture"
}

function test_extract_branches_finds_case_patterns() {
  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
#!/usr/bin/env bash
case "$1" in
a)
  echo "got a"
  ;;
b)
  echo "got b"
  ;;
*)
  echo "other"
  ;;
esac
EOF

  local result
  result=$(bashunit::coverage::extract_branches "$fixture")

  # case decision on line 2, three pattern arms with bodies on 4, 7, 10
  assert_contains "2|case|4:4,7:7,10:10" "$result"

  rm -f "$fixture"
}

function test_extract_branches_returns_nothing_for_no_branches() {
  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
#!/usr/bin/env bash
echo "no branches here"
echo "still none"
EOF

  local result
  result=$(bashunit::coverage::extract_branches "$fixture")

  assert_empty "$result"

  rm -f "$fixture"
}

function test_extract_branches_handles_if_without_else() {
  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "x" ]; then
  echo "x"
fi
EOF

  local result
  result=$(bashunit::coverage::extract_branches "$fixture")

  # MVP scope: only the explicit then arm is reported. Implicit-else
  # (synthetic fall-through outcome) is deferred per ADR-007.
  assert_contains "2|if|3:3" "$result"

  rm -f "$fixture"
}

function test_compute_branch_hits_marks_taken_arm() {
  bashunit::coverage::init

  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "x" ]; then
  echo "taken"
else
  echo "not-taken"
fi
EOF

  echo "$fixture" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"
  # Hit only the `then` arm body
  echo "${fixture}:3" >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local result
  result=$(bashunit::coverage::compute_branch_hits "$fixture")

  # Format: decision_line|block|arm_index|taken_count
  assert_contains "2|0|0|1" "$result"
  assert_contains "2|0|1|0" "$result"

  rm -f "$fixture"
}

function test_compute_branch_hits_marks_all_arms_zero_when_unhit() {
  bashunit::coverage::init

  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "x" ]; then
  echo "x"
else
  echo "y"
fi
EOF

  echo "$fixture" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"

  local result
  result=$(bashunit::coverage::compute_branch_hits "$fixture")

  assert_contains "2|0|0|0" "$result"
  assert_contains "2|0|1|0" "$result"

  rm -f "$fixture"
}

function test_compute_branch_hits_assigns_distinct_blocks_per_decision() {
  bashunit::coverage::init

  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "x" ]; then
  echo "first"
fi
if [ "$2" = "y" ]; then
  echo "second"
fi
EOF

  echo "$fixture" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"
  echo "${fixture}:3" >>"$_BASHUNIT_COVERAGE_DATA_FILE"
  echo "${fixture}:6" >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local result
  result=$(bashunit::coverage::compute_branch_hits "$fixture")

  # Two decisions -> two distinct block ids (0 and 1)
  assert_contains "2|0|0|1" "$result"
  assert_contains "5|1|0|1" "$result"

  rm -f "$fixture"
}
