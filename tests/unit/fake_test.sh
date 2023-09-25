function test_successful_fake() {
  function code() {
    ps a | grep apache
  }

  fake ps<<EOF
  PID TTY          TIME CMD
  13525 pts/7    00:00:01 bash
  24162 pts/7    00:00:00 ps
  8387 ?            0:00 /usr/sbin/apache2 -k start
EOF

  assertEmpty "$(assertSuccessfulCode "$(code)")"
  unset code
}

function test_successful_override_ps_with_echo_with_fake() {
  fake ps echo hello world
  assertEquals "hello world" "$(ps)"
}

function test_successful_parameters_of_fake_function() {
  function code() {
    ps ax | grep apache
  }

  # shellcheck disable=SC2016
  fake ps 'echo ${FAKE_PARAMS[@]} >/tmp/fake_params'

  code || true

  assertEquals ax "$(head -n1 /tmp/fake_params)"
  unset code
  unset _ps
}

function test_unsuccessful_parameters_of_fake_function() {
  function code() {
    ps a | grep apache
  }

  # shellcheck disable=SC2016
  fake ps 'echo ${FAKE_PARAMS[@]} >/tmp/fake_params'

  code || true

  assertEquals\
    "$(Console::printFailedTest "Unsuccessful parameters of fake function" "ax" "but got" "a")"\
    "$(assertEquals ax "$(head -n1 /tmp/fake_params)")"

  unset code
  unset _ps
}


function tearDown() {
  rm /tmp/fake_params 2> /dev/null
}
