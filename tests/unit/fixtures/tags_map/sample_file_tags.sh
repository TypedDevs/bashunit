#!/usr/bin/env bash

# @tags integration db

# A plain comment between the file tags and the first test.

function test_only_file_tags() {
  :
}

# @tag slow
function test_file_and_function_tags() {
  :
}

# @tag db
function test_duplicate_between_file_and_function() {
  :
}
