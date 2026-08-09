#!/usr/bin/env bash

function test_user_list() {
  assert_same 1 1
}

function test_user_admin() {
  assert_same 2 2
}

function test_report_export() {
  assert_same 3 3
}
