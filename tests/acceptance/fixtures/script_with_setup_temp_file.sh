#!/usr/bin/env bash

function set_up_before_script() {
        SCRIPT_TEMP_FILE=$(bashunit::temp_file "script-setup")
        SCRIPT_TEMP_DIR=$(bashunit::temp_dir "script-setup")
        echo "Script temp file created: $SCRIPT_TEMP_FILE" >"$SCRIPT_TEMP_FILE"
        echo "Script temp dir created: $SCRIPT_TEMP_DIR" >"$SCRIPT_TEMP_DIR/marker.txt"
}

function test_simple_passing_test() {
        assert_equals "1" "1"
}

function test_another_simple_test() {
        assert_file_exists "$SCRIPT_TEMP_FILE"
        assert_directory_exists "$SCRIPT_TEMP_DIR"
}
