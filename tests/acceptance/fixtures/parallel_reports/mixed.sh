#!/usr/bin/env bash

function test_one_passes() { assert_same "a" "a"; }
function test_two_passes() { assert_same "b" "b"; }
function test_three_fails() { assert_same "expected" "actual"; }
function test_four_skips() { bashunit::skip "on purpose"; }
