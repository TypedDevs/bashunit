#!/bin/bash

function test_successful_assertEquals() {
  assertEquals "$(printf "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: Successful assertEquals")" "$(assertEquals "1" "1")"
}

function test_unsuccessful_assertEquals() {
  assertEquals "$(printf "\
${COLOR_FAILED}✗ Failed${COLOR_DEFAULT}: Unsuccessful assertEquals
    ${COLOR_FAINT}Expected${COLOR_DEFAULT} ${COLOR_BOLD}'1'${COLOR_DEFAULT}
    ${COLOR_FAINT}but got${COLOR_DEFAULT} ${COLOR_BOLD}'2'${COLOR_DEFAULT}
")" "$(assertEquals "1" "2")"
}

function testCamelCase() {
  assertEquals "$(printf "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: CamelCase")" "$(assertEquals "1" "1")"
}

function test_multiple_asserts() {
  assertEquals "1" "1" "1 equals 1"
  assertEquals "2" "2" "2 equals 2"
  assertEquals "3" "3" "3 equals 3"
}

function test_successful_assertContains() {
  assertEquals "$(printf "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: Successful assertContains")" "$(assertContains "Linux" "GNU/Linux")"
}

function test_unsuccessful_assertContains() {
  assertEquals "$(printf "\
${COLOR_FAILED}✗ Failed${COLOR_DEFAULT}: Unsuccessful assertContains
    ${COLOR_FAINT}Expected${COLOR_DEFAULT} ${COLOR_BOLD}'GNU/Linux'${COLOR_DEFAULT}
    ${COLOR_FAINT}to contain${COLOR_DEFAULT} ${COLOR_BOLD}'Unix'${COLOR_DEFAULT}
")" "$(assertContains "Unix" "GNU/Linux")"
}

function test_successful_assertNotContains() {
  assertEquals "$(printf "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: Successful assertNotContains")" "$(assertNotContains "Linus" "GNU/Linux")"
}

function test_unsuccessful_assertNotContains() {
  assertEquals "$(printf "\
${COLOR_FAILED}✗ Failed${COLOR_DEFAULT}: Unsuccessful assertNotContains
    ${COLOR_FAINT}Expected${COLOR_DEFAULT} ${COLOR_BOLD}'GNU/Linux'${COLOR_DEFAULT}
    ${COLOR_FAINT}to not contain${COLOR_DEFAULT} ${COLOR_BOLD}'Linux'${COLOR_DEFAULT}
")" "$(assertNotContains "Linux" "GNU/Linux")"
}

function test_successful_assertMatches() {
  assertEquals "$(printf "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: Successful assertMatches")" "$(assertMatches ".*Linu*" "GNU/Linux")"
}

function test_unsuccessful_assertMatches() {
  assertEquals "$(printf "\
${COLOR_FAILED}✗ Failed${COLOR_DEFAULT}: Unsuccessful assertMatches
    ${COLOR_FAINT}Expected${COLOR_DEFAULT} ${COLOR_BOLD}'GNU/Linux'${COLOR_DEFAULT}
    ${COLOR_FAINT}to match${COLOR_DEFAULT} ${COLOR_BOLD}'.*Pinux*'${COLOR_DEFAULT}
")" "$(assertMatches ".*Pinux*" "GNU/Linux")"
}

function test_successful_assertNotMatches() {
  assertEquals "$(printf "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: Successful assertNotMatches")" "$(assertNotMatches ".*Pinux*" "GNU/Linux")"
}

function test_unsuccessful_assertNotMatches() {
  assertEquals "$(printf "\
${COLOR_FAILED}✗ Failed${COLOR_DEFAULT}: Unsuccessful assertNotMatches
    ${COLOR_FAINT}Expected${COLOR_DEFAULT} ${COLOR_BOLD}'GNU/Linux'${COLOR_DEFAULT}
    ${COLOR_FAINT}to not match${COLOR_DEFAULT} ${COLOR_BOLD}'.*Linu*'${COLOR_DEFAULT}
")" "$(assertNotMatches ".*Linu*" "GNU/Linux")"
}
