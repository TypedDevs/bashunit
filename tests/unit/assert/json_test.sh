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
