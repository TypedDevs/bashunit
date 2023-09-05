#!/bin/bash

function test_successful_assertEquals() {
  assertEquals "$(printf "✔️  ${COLOR_PASSED}Passed${COLOR_DEFAULT}: Successful assertEquals")" "$(assertEquals "1" "1")"
}

function test_unsuccessful_assertEquals() {
  assertEquals "$(printf "❌  ${COLOR_FAILED}Failed${COLOR_DEFAULT}: Unsuccessful assertEquals
 Expected '1'
 but got  '2'")" "$(assertEquals "1" "2")"
}

function testCamelCase() {
  assertEquals "$(printf "✔️  ${COLOR_PASSED}Passed${COLOR_DEFAULT}: CamelCase")" "$(assertEquals "1" "1")"
}

function test_successful_assertContains() {
  assertEquals "$(printf "✔️  ${COLOR_PASSED}Passed${COLOR_DEFAULT}: Successful assertContains")" "$(assertContains "Linux" "GNU/Linux")"
}

function test_unsuccessful_assertContains() {
  assertEquals "$(printf "❌  ${COLOR_FAILED}Failed${COLOR_DEFAULT}: Unsuccessful assertContains
 Expected   'GNU/Linux'
 to contain 'Unix'")" "$(assertContains "Unix" "GNU/Linux")"
}
