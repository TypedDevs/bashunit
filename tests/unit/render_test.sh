#!/bin/bash

function test_render_result_total_tests() {
  assertContains "TODO" "$(renderResult 5 1 2)"
}
