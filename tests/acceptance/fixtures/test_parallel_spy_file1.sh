#!/usr/bin/env bash

function test_spy_file1() {
  spy date
  date
  assert_have_been_called_times 1 date
}
