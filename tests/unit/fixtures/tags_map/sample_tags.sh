#!/usr/bin/env bash
# Fixture for tags-map scanner tests. Not run as a suite; scanned as text.

# @tag single
function test_single_tag() {
  return 0
}

# @tag first
# @tag second
function test_multiple_tags() {
  return 0
}

# @tag tagged
# a plain comment between the tag and the function
function test_tag_before_nontag_comment() {
  return 0
}

# @tag orphan

function test_blank_breaks_association() {
  return 0
}

# @tag arrow
test_arrow_style() {
  return 0
}

function test_no_tags() {
  return 0
}
