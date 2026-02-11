#!/usr/bin/env bash

function test_error() {
        set -e
        invalid_function_name arg1 arg2 &>/dev/null
}
