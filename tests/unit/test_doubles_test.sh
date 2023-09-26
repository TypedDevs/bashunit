#!/bin/bash

function tearDown() {
  unset code
  unset _ps
}

function setUp() {
  function code() {
      # shellcheck disable=SC2009
      # shellcheck disable=SC2317
      ps a | grep apache
    }
}

function test_successful_mock() {
  mock ps<<EOF
  PID TTY          TIME CMD
  13525 pts/7    00:00:01 bash
  24162 pts/7    00:00:00 ps
  8387 ?            0:00 /usr/sbin/apache2 -k start
EOF

  assertEmpty "$(assertSuccessfulCode "$(code)")"
}

function test_successful_override_ps_with_echo_with_mock() {
  mock ps echo hello world
  assertEquals "hello world" "$(ps)"
}

function test_successful_spy() {
  spy ps
  ps a_random_parameter_1 a_random_parameter_2

  assertHaveBeenCalledWith "a_random_parameter_1 a_random_parameter_2" ps
  assertHaveBeenCalled ps
}

function test_unsuccessful_spy_called() {
  spy ps

  assertEquals\
    "$(Console::printFailedTest "Unsuccessful spy called" "ps" "has not been called at least" "once")"\
    "$(assertHaveBeenCalled ps)"
}


function test_successful_spy_called_times() {
  spy ps

  ps
  ps

  assertHaveBeenCalledTimes 2 ps
}

