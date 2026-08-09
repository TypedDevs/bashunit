#!/usr/bin/env bash
# shellcheck disable=SC2317

# Tag expressions: AND (&&) and negation (!) inside a single --tag value.
# Repeated --tag flags arrive here comma-joined and keep OR semantics between
# them, so existing usage is unchanged (#1008).

function matches() { # $1 fn tags, $2 include, $3 exclude
  local exit_code=0
  bashunit::helper::function_matches_tags "$1" "${2:-}" "${3:-}" || exit_code=$?
  echo "$exit_code"
}

function test_a_plain_tag_still_matches() {
  assert_same "0" "$(matches "slow,db" "slow")"
}

function test_a_plain_tag_still_rejects_a_non_match() {
  assert_same "1" "$(matches "slow,db" "api")"
}

function test_repeated_tags_keep_or_semantics() {
  assert_same "0" "$(matches "db" "api,db")"
}

function test_and_requires_every_term() {
  assert_same "0" "$(matches "slow,db" "slow&&db")"
}

function test_and_rejects_when_one_term_is_missing() {
  assert_same "1" "$(matches "slow" "slow&&db")"
}

function test_negation_selects_tests_without_the_tag() {
  assert_same "0" "$(matches "db" '!slow')"
}

function test_negation_rejects_tests_carrying_the_tag() {
  assert_same "1" "$(matches "slow,db" '!slow')"
}

function test_negation_matches_an_untagged_test() {
  assert_same "0" "$(matches "" '!slow')"
}

function test_and_combined_with_negation() {
  assert_same "0" "$(matches "db,fast" 'db&&!slow')"
}

function test_and_combined_with_negation_rejects() {
  assert_same "1" "$(matches "db,slow" 'db&&!slow')"
}

function test_or_between_expressions() {
  assert_same "0" "$(matches "api" 'db&&slow,api')"
}

# --exclude-tag is a separate flag and keeps winning over any include match.
function test_exclude_still_wins_over_an_expression_match() {
  assert_same "1" "$(matches "slow,db" "slow&&db" "db")"
}

function test_exclude_still_wins_over_a_negation_match() {
  assert_same "1" "$(matches "db" '!slow' "db")"
}

function test_whitespace_around_terms_is_tolerated() {
  assert_same "0" "$(matches "slow,db" " slow && db ")"
}

function test_an_untagged_test_is_rejected_by_a_positive_expression() {
  assert_same "1" "$(matches "" "slow&&db")"
}
