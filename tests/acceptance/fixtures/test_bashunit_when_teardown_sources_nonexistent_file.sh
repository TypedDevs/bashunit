#!/usr/bin/env bash

function tear_down() {
        # shellcheck disable=SC1091
        source ./this_file_does_not_exist.sh
}

function test_dummy() {
        assert_same "foo" "foo"
}
