#!/usr/bin/env bash

function tear_down_after_script() {
        false
}

function test_dummy() {
        assert_same "foo" "foo"
}
