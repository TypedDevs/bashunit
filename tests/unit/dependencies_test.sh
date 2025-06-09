#!/usr/bin/env bash

function test_has_perl_search_path_for_perl() {
  spy command
  dependencies::has_perl

  assert_have_been_called_with "-v perl" command
}

function test_has_adjtimex() {
  spy command
  dependencies::has_adjtimex

  assert_have_been_called_with "-v adjtimex" command
}

function test_has_bc() {
  spy command

  dependencies::has_bc

  assert_have_been_called_with "-v bc" command
}

function test_has_awk() {
  spy command
  dependencies::has_awk

  assert_have_been_called_with "-v awk" command
}

function test_has_git() {
  spy command
  dependencies::has_git

  assert_have_been_called_with "-v git" command
}

function test_has_python() {
  spy command
  dependencies::has_python

  assert_have_been_called_with "-v python" command
}

function test_has_node() {
  spy command
  dependencies::has_node

  assert_have_been_called_with "-v node" command
}
