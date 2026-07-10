#!/usr/bin/env bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="tests/acceptance/fixtures/test_bashunit_random_order.sh"
}

# Runs the fixture and prints the recorded dispatch order (space-separated),
# read from a file so it is independent of console output/color/locale.
function order_of() {
  local order_file
  order_file="$(mktemp)"
  BASHUNIT_TEST_ORDER_FILE="$order_file" \
    ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$@" "$FIXTURE" >/dev/null 2>&1
  tr '\n' ' ' <"$order_file" | sed 's/ *$//'
  rm -f "$order_file"
}

function test_default_order_is_unchanged_without_the_flag() {
  assert_same "alpha bravo charlie delta echo foxtrot golf hotel" "$(order_of)"
}

function test_random_order_is_reproducible_with_a_given_seed() {
  local first second
  first="$(order_of --random-order --seed 42)"
  second="$(order_of --random-order --seed 42)"

  assert_same "$first" "$second"
}

function test_random_order_reorders_tests() {
  assert_not_equals "$(order_of)" "$(order_of --random-order --seed 42)"
}

function test_random_order_prints_the_seed_for_replay() {
  local output
  output="$(BASHUNIT_TEST_ORDER_FILE="$(mktemp)" \
    ./bashunit --no-parallel --env "$TEST_ENV_FILE" --random-order --seed 42 "$FIXTURE")"

  assert_contains "Randomized with seed:" "$output"
}

function test_random_order_prints_a_generated_seed_when_none_given() {
  local output
  output="$(BASHUNIT_TEST_ORDER_FILE="$(mktemp)" \
    ./bashunit --no-parallel --env "$TEST_ENV_FILE" --random-order "$FIXTURE")"

  assert_contains "Randomized with seed:" "$output"
}

function test_random_order_composes_with_parallel() {
  local output
  output="$(BASHUNIT_TEST_ORDER_FILE="$(mktemp)" \
    ./bashunit --parallel --env "$TEST_ENV_FILE" --random-order --seed 42 "$FIXTURE")"

  assert_contains "8 passed" "$output"
}
