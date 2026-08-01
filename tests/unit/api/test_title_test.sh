#!/usr/bin/env bash

function test_set_test_title_delegates_to_state() {
  bashunit::spy bashunit::state::set_test_title

  bashunit::set_test_title "my custom title"

  assert_have_been_called_with bashunit::state::set_test_title "my custom title"
}

function test_set_test_title_delegates_empty_string() {
  bashunit::spy bashunit::state::set_test_title

  bashunit::set_test_title ""

  assert_have_been_called bashunit::state::set_test_title
}
