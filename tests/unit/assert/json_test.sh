#!/usr/bin/env bash
# shellcheck disable=SC2329

_JQ_AVAILABLE=false
if command -v jq >/dev/null 2>&1; then
  _JQ_AVAILABLE=true
fi

function test_successful_assert_json_key_exists() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  assert_empty "$(assert_json_key_exists ".name" '{"name":"bashunit","version":"1.0"}')"
}

function test_successful_assert_json_key_exists_nested() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  assert_empty "$(assert_json_key_exists ".data.id" '{"data":{"id":42}}')"
}

function test_unsuccessful_assert_json_key_exists() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local json='{"name":"bashunit"}'

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert json key exists" \
      "$json" "to have key" ".missing")" \
    "$(assert_json_key_exists ".missing" "$json")"
}

function test_successful_assert_json_contains() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  assert_empty "$(assert_json_contains ".name" "bashunit" '{"name":"bashunit","version":"1.0"}')"
}

function test_successful_assert_json_contains_numeric() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  assert_empty "$(assert_json_contains ".count" "42" '{"count":42}')"
}

function test_unsuccessful_assert_json_contains_wrong_value() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local json='{"name":"bashunit"}'

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert json contains wrong value" \
      "other" "but got " "bashunit")" \
    "$(assert_json_contains ".name" "other" "$json")"
}

function test_unsuccessful_assert_json_contains_missing_key() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local json='{"name":"bashunit"}'

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert json contains missing key" \
      "$json" "to have key" ".missing")" \
    "$(assert_json_contains ".missing" "value" "$json")"
}

function test_successful_assert_json_equals() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  assert_empty "$(assert_json_equals '{"b":2,"a":1}' '{"a":1,"b":2}')"
}

function test_unsuccessful_assert_json_equals() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local expected='{"a":1}'
  local actual='{"a":2}'

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert json equals" \
      "$expected" "but got " "$actual")" \
    "$(assert_json_equals "$expected" "$actual")"
}

# jq -S silently produces empty output (not a parse-error message) on invalid
# JSON; without checking its exit code, two differently-invalid or identically
# unparseable inputs both sort to "" and compare equal, turning "not JSON at
# all" into a false pass.
function test_unsuccessful_assert_json_equals_when_expected_is_invalid_json() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local expected='not json'
  local actual='{"a":1}'

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert json equals when expected is invalid json" \
      "$expected" "but got " "$actual")" \
    "$(assert_json_equals "$expected" "$actual")"
}

function test_unsuccessful_assert_json_equals_when_both_sides_are_invalid_json() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local expected='not json'
  local actual='also not json'

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert json equals when both sides are invalid json" \
      "$expected" "but got " "$actual")" \
    "$(assert_json_equals "$expected" "$actual")"
}

function test_successful_assert_json_key_not_exists() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  assert_empty "$(assert_json_key_not_exists ".password" '{"name":"bashunit"}')"
}

function test_unsuccessful_assert_json_key_not_exists_when_key_is_present() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local json='{"password":"secret"}'

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert json key not exists when key is present" \
      "$json" "to not have key" ".password")" \
    "$(assert_json_key_not_exists ".password" "$json")"
}

function test_unsuccessful_assert_json_key_not_exists_when_value_is_null() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local json='{"password":null}'

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert json key not exists when value is null" \
      "$json" "to not have key" ".password")" \
    "$(assert_json_key_not_exists ".password" "$json")"
}

function test_unsuccessful_assert_json_key_not_exists_when_json_is_invalid() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local json='not json'

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert json key not exists when json is invalid" \
      "$json" "to be valid JSON" "")" \
    "$(assert_json_key_not_exists ".password" "$json")"
}

function test_successful_assert_json_length_for_array() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  assert_empty "$(assert_json_length 3 ".items" '{"items":[1,2,3]}')"
}

function test_successful_assert_json_length_for_object() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  assert_empty "$(assert_json_length 2 ".item" '{"item":{"name":"bashunit","version":1}}')"
}

function test_successful_assert_json_length_for_string() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  assert_empty "$(assert_json_length 8 ".name" '{"name":"bashunit"}')"
}

function test_unsuccessful_assert_json_length() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert json length" "2" "but got " "3")" \
    "$(assert_json_length 2 ".items" '{"items":[1,2,3]}')"
}

function test_unsuccessful_assert_json_length_when_path_is_missing() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local json='{"items":[]}'

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert json length when path is missing" \
      "$json" "to have path" ".missing")" \
    "$(assert_json_length 0 ".missing" "$json")"
}

function test_unsuccessful_assert_json_length_when_json_is_invalid() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local json='not json'

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert json length when json is invalid" \
      "$json" "to be valid JSON" "")" \
    "$(assert_json_length 0 ".items" "$json")"
}

function test_unsuccessful_assert_json_length_when_value_has_no_collection_length() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local json='{"item":null}'

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert json length when value has no collection length" \
      "$json" "to have a measurable length at path" ".item")" \
    "$(assert_json_length 0 ".item" "$json")"
}

function test_assert_json_length_rejects_non_numeric_expected_length() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local output exit_code=0

  output=$(assert_json_length nope ".items" '{"items":[]}' 2>&1) || exit_code=$?

  assert_same 2 "$exit_code"
  assert_same \
    "bashunit: assertion usage error: assert_json_length expects a non-negative integer length, got 'nope'" \
    "$output"
}

function test_new_json_assertions_use_the_existing_missing_jq_behavior() {
  local existing not_exists length
  existing=$(PATH="" assert_json_key_exists ".name" '{}')
  not_exists=$(PATH="" assert_json_key_not_exists ".name" '{}')
  length=$(PATH="" assert_json_length 0 ".items" '{}')

  assert_same "$existing" "$not_exists"
  assert_same "$existing" "$length"
}
