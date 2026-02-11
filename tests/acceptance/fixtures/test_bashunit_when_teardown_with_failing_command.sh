#!/usr/bin/env bash

function tear_down() {
        false
}

function test_dummy() {
        assert_same "foo" "foo"
}
