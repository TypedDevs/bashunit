#!/usr/bin/env bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="tests/acceptance/fixtures/test_bashunit_random_order.sh"
}

# Prints the dispatch order of tests as a space-separated list of names.
function order_of() {
  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" "$@" "$FIXTURE" |
    grep "Passed:" | sed 's/.*Passed: //' | awk '{print $1}' | xargs
}

function test_default_order_is_unchanged_without_the_flag() {
  assert_same "Alpha Bravo Charlie Delta Echo Foxtrot Golf Hotel" "$(order_of)"
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
  output="$(./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --random-order --seed 42 "$FIXTURE")"

  assert_contains "Randomized with seed: 42" "$output"
}

function test_random_order_prints_a_generated_seed_when_none_given() {
  local output
  output="$(./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --random-order "$FIXTURE")"

  assert_contains "Randomized with seed:" "$output"
}

function test_random_order_composes_with_parallel() {
  local output
  output="$(./bashunit --parallel --no-color --env "$TEST_ENV_FILE" \
    --random-order --seed 42 "$FIXTURE")"

  assert_contains "8 passed" "$output"
}
