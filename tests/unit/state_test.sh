#!/bin/bash

function test_add_and_get_tests_passed() {
    local tests_passed=$(
        _TESTS_PASSED=0

        state::add_tests_passed
        state::get_tests_passed
    )

    assertEquals "1" "$tests_passed"
}

function test_add_and_get_tests_failed() {
    local tests_failed=$(
        _TESTS_FAILED=0

        State::addTestsFailed
        State::getTestsFailed
    )

    assertEquals "1" "$tests_failed"
}

function test_add_and_get_assertions_passed() {
    local assertions_passed=$(
        _ASSERTIONS_PASSED=0

        State::addAssertionsPassed
        State::getAssertionsPassed
    )

    assertEquals "1" "$assertions_passed"
}

function test_add_and_get_assertions_failed() {
    local assertions_failed=$(
        _ASSERTIONS_FAILED=0

        State::addAssertionsFailed
        State::getAssertionsFailed
    )

    assertEquals "1" "$assertions_failed"
}

function test_set_and_is_duplicated_test_functions_found() {
    local duplicated_test_functions_found=$(
        _DUPLICATED_TEST_FUNCTIONS_FOUND=false

        State::setDuplicatedTestFunctionsFound
        State::isDuplicatedTestFunctionsFound
    )

    assertEquals "true" "$duplicated_test_functions_found"
}

function test_initialize_assertions_count() {
    local export_assertions_count=$(
        _ASSERTIONS_PASSED=10
        _ASSERTIONS_FAILED=5

        State::initializeAssertionsCount
        State::exportAssertionsCount
    )

    assertEquals "##ASSERTIONS_FAILED=0##ASSERTIONS_PASSED=0##" "$export_assertions_count"
}

function test_export_assertions_count() {
    local export_assertions_count=$(
        _ASSERTIONS_PASSED=10
        _ASSERTIONS_FAILED=5

        State::exportAssertionsCount
    )

    assertEquals "##ASSERTIONS_FAILED=5##ASSERTIONS_PASSED=10##" "$export_assertions_count"
}
