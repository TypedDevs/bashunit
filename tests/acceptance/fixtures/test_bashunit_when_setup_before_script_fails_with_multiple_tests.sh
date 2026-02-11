#!/usr/bin/env bash

function set_up_before_script() {
        false
}

function test_asserting_foo_strings() {
        assert_same "foo" "foo"
}

function test_asserting_bar_strings() {
        assert_same "bar" "bar"
}
