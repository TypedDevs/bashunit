#!/usr/bin/env bash

function my_cmd() { echo x; }

# The spy and the count swapped: assert_have_been_called_times takes the count
# first. Without a guard this reaches `[ 1 -ne my_cmd ]` and leaks a raw
# "integer expression expected" from inside bashunit.
function test_swapped_count_and_spy() {
  bashunit::spy my_cmd
  my_cmd >/dev/null
  assert_have_been_called_times my_cmd 1
}
