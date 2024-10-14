#!/bin/bash

function test_error() {
  invalid_function_name arg1 arg2
  assert_true 0
}
