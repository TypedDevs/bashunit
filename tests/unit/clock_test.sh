#!/bin/bash

function test_now_with_perl() {
  mock perl echo "1720705883457"

  assert_equals "1720705883457" "$(clock::now)"
}

function test_now_without_perl_no_osx() {
  export _OS="Linux"

  mock perl /dev/null
  mock date echo "1720705883457"

  assert_equals "1720705883457" "$(clock::now)"
}

function test_now_without_perl_and_osx() {
  export _OS="OSX"

  mock perl echo ""

  assert_equals "" "$(clock::now)"
}
