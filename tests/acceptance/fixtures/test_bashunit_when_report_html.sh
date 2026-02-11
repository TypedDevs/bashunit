#!/usr/bin/env bash

function test_success() {
        assert_same 1 1
}

function test_fail() {
        assert_empty "non empty"
}

function test_skipped() {
        bashunit::skip
}

function test_todo() {
        bashunit::todo
}
