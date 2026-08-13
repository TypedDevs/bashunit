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
# kind ∈ {if, case, loop}
# A loop is a single-arm branch: the body range, taken iff the loop ran at
# least once (any executable body line was hit).

function test_extract_branches_finds_while_loop() {
  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
#!/usr/bin/env bash
while [ "$i" -lt 3 ]; do
  echo "$i"
done
EOF

  local result
  result=$(bashunit::coverage::extract_branches "$fixture")

  assert_contains "2|loop|3:3" "$result"

  rm -f "$fixture"
}

function test_extract_branches_finds_for_loop() {
  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
#!/usr/bin/env bash
for x in 1 2 3; do
  echo "$x"
done
EOF

  local result
  result=$(bashunit::coverage::extract_branches "$fixture")

  assert_contains "2|loop|3:3" "$result"

  rm -f "$fixture"
}

function test_extract_branches_finds_until_loop() {
  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
#!/usr/bin/env bash
until [ "$ok" = "yes" ]; do
  ok=$(check)
done
EOF

  local result
  result=$(bashunit::coverage::extract_branches "$fixture")

  assert_contains "2|loop|3:3" "$result"

  rm -f "$fixture"
}

function test_extract_branches_finds_nested_loops() {
  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
#!/usr/bin/env bash
for x in 1 2; do
  while [ "$x" -gt 0 ]; do
    echo hi
    x=$((x - 1))
  done
done
EOF

  local result
  result=$(bashunit::coverage::extract_branches "$fixture")

  # Inner while (line 3) body on 4-5; outer for (line 2) body on 3-6.
  assert_contains "3|loop|4:5" "$result"
  assert_contains "2|loop|3:6" "$result"

  rm -f "$fixture"
}

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

function test_compute_branch_hits_marks_loop_body_taken_when_iterated() {
  bashunit::coverage::init

  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
#!/usr/bin/env bash
while [ "$i" -lt 3 ]; do
  echo "$i"
done
EOF

  echo "$fixture" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"
  # The loop body (line 3) ran at least once.
  echo "${fixture}:3" >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local result
  result=$(bashunit::coverage::compute_branch_hits "$fixture")

  # Single-arm loop branch on line 2, arm taken.
  assert_contains "2|0|0|1" "$result"

  rm -f "$fixture"
}

function test_compute_branch_hits_marks_loop_body_not_taken_on_zero_iterations() {
  bashunit::coverage::init

  local fixture
  fixture=$(mktemp)
  cat >"$fixture" <<'EOF'
#!/usr/bin/env bash
while [ "$i" -lt 3 ]; do
  echo "$i"
done
EOF

  echo "$fixture" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"
  # No hits recorded: the loop never iterated (zero-iteration branch uncovered).

  local result
  result=$(bashunit::coverage::compute_branch_hits "$fixture")

  assert_contains "2|0|0|0" "$result"

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

# --- per-arm execution counts (#1061) ---------------------------------------

# BRDA's fourth field is an execution count to an LCOV consumer, so reporting 1
# for an arm taken 5,000 times and 1 for one grazed by a single test loses the
# distinction that makes branch data useful.
function test_an_arm_reports_how_many_times_it_ran() {
  # _arm_taken reads src_lines from the caller's scope: Bash 3.0 cannot pass an
  # array into a function, nor take a compound assignment on a `local`.
  local -a src_lines
  # shellcheck disable=SC2034
  src_lines=("if true; then" "  echo one" "fi")
  _BASHUNIT_COVERAGE_HITS_BY_LINE=()
  _BASHUNIT_COVERAGE_HITS_BY_LINE[2]=10

  bashunit::coverage::_arm_taken 2 2

  assert_same "10" "$_BASHUNIT_ARM_TAKEN_OUT"
}

function test_an_arm_never_taken_reports_zero() {
  local -a src_lines
  # shellcheck disable=SC2034  # read from the caller's scope by _arm_taken
  src_lines=("if true; then" "  echo one" "fi")
  _BASHUNIT_COVERAGE_HITS_BY_LINE=()

  bashunit::coverage::_arm_taken 2 2

  assert_same "0" "$_BASHUNIT_ARM_TAKEN_OUT"
}

# Documented rule: the FIRST executable line's count. Entering an arm executes
# that line once per entry, while a later line can run more often (a loop) or
# fewer times (an early return).
function test_an_arm_counts_its_first_executable_line_not_the_maximum() {
  local -a src_lines
  # shellcheck disable=SC2034  # read from the caller's scope by _arm_taken
  src_lines=("if true; then" "  echo entry" "  while :; do" "    echo inner" "  done" "fi")
  _BASHUNIT_COVERAGE_HITS_BY_LINE=()
  _BASHUNIT_COVERAGE_HITS_BY_LINE[2]=3
  _BASHUNIT_COVERAGE_HITS_BY_LINE[4]=30

  bashunit::coverage::_arm_taken 2 5

  assert_same "3" "$_BASHUNIT_ARM_TAKEN_OUT"
}

function test_an_arm_skips_non_executable_lines_when_counting() {
  local -a src_lines
  # shellcheck disable=SC2034  # read from the caller's scope by _arm_taken
  src_lines=("if true; then" "  # a comment" "  echo real" "fi")
  _BASHUNIT_COVERAGE_HITS_BY_LINE=()
  _BASHUNIT_COVERAGE_HITS_BY_LINE[3]=7

  bashunit::coverage::_arm_taken 2 3

  assert_same "7" "$_BASHUNIT_ARM_TAKEN_OUT"
}
