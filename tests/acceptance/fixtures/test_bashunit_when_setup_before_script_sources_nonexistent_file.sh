#!/usr/bin/env bash

function set_up_before_script() {
        # shellcheck disable=SC1091
        source ./this_file_does_not_exist.sh
}

function test_dummy() {
        assert_same "foo" "foo"
}
