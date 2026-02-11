#!/usr/bin/env bash

function test_custom_title() {
        bashunit::set_test_title "🔥 handles invalid input with 💣"
        assert_true true
}

function test_default_title() {
        assert_true true
}
