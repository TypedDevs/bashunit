#!/usr/bin/env bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  D="tests/acceptance/fixtures"
  FILES="$D/test_shard_a.sh $D/test_shard_b.sh $D/test_shard_c.sh $D/test_shard_d.sh"
}

# Runs the four shard fixtures through a shard and prints which ran, sorted.
function shard_run() {
  local order_file
  order_file="$(mktemp)"
  # shellcheck disable=SC2086
  BASHUNIT_TEST_ORDER_FILE="$order_file" \
    ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$@" $FILES >/dev/null 2>&1
  sort "$order_file" | tr '\n' ' ' | sed 's/ *$//'
  rm -f "$order_file"
}

function test_shard_1_of_2_runs_its_slice() {
  assert_same "a c" "$(shard_run --shard 1/2)"
}

function test_shard_2_of_2_runs_its_slice() {
  assert_same "b d" "$(shard_run --shard 2/2)"
}

function test_shards_are_disjoint_and_cover_the_whole_suite() {
  local union
  union="$(printf '%s %s' "$(shard_run --shard 1/2)" "$(shard_run --shard 2/2)" |
    tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ *$//')"

  assert_same "a b c d" "$union"
}

function test_shard_rejects_index_greater_than_total() {
  # shellcheck disable=SC2086
  assert_general_error \
    "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --shard 3/2 $FILES 2>&1)"
}

function test_shard_rejects_non_numeric_input() {
  # shellcheck disable=SC2086
  assert_general_error \
    "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --shard x/2 $FILES 2>&1)"
}

function test_shard_composes_with_parallel() {
  local order_file count
  order_file="$(mktemp)"
  # shellcheck disable=SC2086
  BASHUNIT_TEST_ORDER_FILE="$order_file" \
    ./bashunit --parallel --env "$TEST_ENV_FILE" --shard 1/2 $FILES >/dev/null 2>&1
  count=$(tr -cd 'a-d' <"$order_file" | wc -c | tr -d ' ')
  rm -f "$order_file"

  assert_same "2" "$count"
}
