#!/usr/bin/env bash

function test_has_perl_search_path_for_perl() {
  bashunit::spy command
  dependencies::has_perl

  assert_have_been_called_with command "-v perl"
}

function test_has_adjtimex() {
  bashunit::spy command
  dependencies::has_adjtimex

  assert_have_been_called_with command "-v adjtimex"
}

function test_has_bc() {
  bashunit::spy command

  dependencies::has_bc

  assert_have_been_called_with command "-v bc"
}

function test_has_awk() {
  bashunit::spy command
  dependencies::has_awk

  assert_have_been_called_with command "-v awk"
}

function test_has_git() {
  bashunit::spy command
  dependencies::has_git

  assert_have_been_called_with command "-v git"
}

function test_has_python() {
  bashunit::spy command
  dependencies::has_python

  assert_have_been_called_with command "-v python"
}

function test_has_node() {
  bashunit::spy command
  dependencies::has_node

  assert_have_been_called_with command "-v node"
}
