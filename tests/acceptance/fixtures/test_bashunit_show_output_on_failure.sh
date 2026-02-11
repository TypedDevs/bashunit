#!/usr/bin/env bash

function test_with_output_before_error() {
        echo "Debug: Starting test"
        echo "Info: About to run command"
        nonexistent_command_xyz
}
