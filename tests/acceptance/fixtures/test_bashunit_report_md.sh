#!/usr/bin/env bash

function test_md_pass() {
  assert_same "ok" "ok"
}

# The rendered name carries every Markdown-hostile character the table and
# headings must survive; the message lands inside the fenced block.
function test_md_fail_with_specials() {
  bashunit::set_test_title 'md |name* _with_ `specials`'
  assert_same 'expected value' 'actual value'
}
