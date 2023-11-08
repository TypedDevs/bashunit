#!/bin/bash

function test_error() {
  invalid_function_name
  assert_general_error
}
