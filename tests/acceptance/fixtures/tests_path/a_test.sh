#!/usr/bin/env bash

function test_assert_greater_and_less_than() {
        assert_greater_than 1 999
        assert_less_than 999 1
}

function test_assert_empty() {
        assert_empty ""
}
