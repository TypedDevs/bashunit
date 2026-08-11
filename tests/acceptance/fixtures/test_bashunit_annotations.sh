#!/usr/bin/env bash

# Fixture for the per-test @timeout / @retry / @skip annotations.

# @skip needs a live database
function test_annotated_skip_never_runs() {
  assert_same "unreachable" "reached"
}

# @skip
test_annotated_skip_without_reason() {
  assert_same "unreachable" "reached"
}

# @tag slow
# @timeout 1
function test_annotated_timeout_kills_a_slow_test() {
  sleep 5
  assert_same "unreachable" "reached"
}

# @timeout 0
function test_annotated_timeout_zero_disables_the_global_one() {
  sleep 2
  assert_same "ok" "ok"
}

# @retry 2
function test_annotated_retry_recovers_a_flaky_test() {
  local counter_file="${BASHUNIT_ANNOTATIONS_COUNTER:?counter file required}"

  local attempts
  attempts=$(cat "$counter_file" 2>/dev/null || echo 0)
  attempts=$((attempts + 1))
  printf '%s' "$attempts" >"$counter_file"

  if [ "$attempts" -ge 3 ]; then
    assert_same "ok" "ok"
  else
    assert_same "pass-on-attempt-3" "failed-on-attempt-$attempts"
  fi
}

# @skip

# A blank line between the comment block and the function breaks the
# association, exactly as it does for @tag, so this test runs.
function test_a_blank_line_breaks_the_annotation_block() {
  assert_same "ok" "ok"
}
