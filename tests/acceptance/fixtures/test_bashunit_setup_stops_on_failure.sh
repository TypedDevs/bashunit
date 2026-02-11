#!/usr/bin/env bash

# Test fixture for issue #517: When set_up fails, remaining commands should not execute

function set_up() {
        # This command will fail
        false
        # This should NOT execute - if it does, the marker file will be created
        touch "/tmp/bashunit_setup_marker_test"
}

function test_dummy() {
        assert_same "foo" "foo"
}
