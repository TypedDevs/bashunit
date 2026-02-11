#!/usr/bin/env bash

function set_up_before_script() {
        false
        true
}

function test_dummy() {
        assert_same "foo" "foo"
}
