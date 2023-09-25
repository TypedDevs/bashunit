#!/bin/bash

function tearDown() {
  unset code
  unset _ps
  rm /tmp/fake_params 2> /dev/null
}

function setUp() {
  function code() {
      # shellcheck disable=SC2009
      # shellcheck disable=SC2317
      ps a | grep apache
    }
}

function test_successful_fake() {
  fake ps<<EOF
  PID TTY          TIME CMD
  13525 pts/7    00:00:01 bash
  24162 pts/7    00:00:00 ps
  8387 ?            0:00 /usr/sbin/apache2 -k start
EOF

  assertEmpty "$(assertSuccessfulCode "$(code)")"
}

function test_successful_override_ps_with_echo_with_fake() {
  fake ps echo hello world
  assertEquals "hello world" "$(ps)"
}

function test_successful_parameters_of_fake_function() {
  function code() {
    # shellcheck disable=SC2009
    ps ax | grep apache
  }

  # shellcheck disable=SC2016
  fake ps 'echo ${FAKE_PARAMS[@]} >/tmp/fake_params'

  code || true

  assertEquals ax "$(head -n1 /tmp/fake_params)"
}

function test_unsuccessful_parameters_of_fake_function() {


  # shellcheck disable=SC2016
  fake ps 'echo ${FAKE_PARAMS[@]} >/tmp/fake_params'

  code || true

  assertEquals\
    "$(Console::printFailedTest "Unsuccessful parameters of fake function" "ax" "but got" "a")"\
    "$(assertEquals ax "$(head -n1 /tmp/fake_params)")"
}
