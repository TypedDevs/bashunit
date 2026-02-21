# Test doubles

When creating tests, you might need to override existing function to be able to write isolated tests from external behaviour. To accomplish this, you can use mocks. You can also check that a function was called with certain arguments or even a number of times with a spy.

Temporary files created by spies are isolated per test run, so they work reliably when executing tests in parallel.

Spies record their calls in temporary files scoped to each test run.
This avoids clashes between processes and allows spies to work reliably when tests execute in parallel using `BASHUNIT_PARALLEL_RUN`.

## bashunit::mock
> `bashunit::mock "function" "body"`

Allows you to override the behavior of a callable.

::: code-group
```bash [Example]
function test_example() {
  bashunit::mock ps echo hello world

  assert_same "hello world" "$(ps)"
}
```
:::

> `bashunit::mock "function" <<< "output"`

Allows you to override the output of a callable. When the mocked output fits on
a single line you can use a here-string:

```bash
bashunit::mock uname <<< "Linux"
```

For multi-line output rely on a here-document:

```bash
bashunit::mock ps <<EOF
PID TTY          TIME CMD
13525 pts/7    00:00:01 bash
24162 pts/7    00:00:00 ps
EOF
```

::: code-group
```bash [Example]
function test_example() {
  function code() {
    ps a | grep bash
  }

  bashunit::mock ps<<EOF
PID TTY          TIME CMD
13525 pts/7    00:00:01 bash
24162 pts/7    00:00:00 ps
EOF

  assert_same "13525 pts/7    00:00:01 bash" "$(code)"
}
```

:::
Mocked functions are also available inside subshells:

::: code-group
```bash [Example]
function test_example() {
  bashunit::mock date echo "2024-05-01"

  function run() {
    date
  }

  assert_same "2024-05-01" "$(run)"
}
```
:::

All arguments passed to the original call are forwarded to the mocked function, so you can mock different behavior depending on the arguments.

::: code-group
```bash [Example]
mockTool() {
  if [[ "$1" == "--version" ]]; then
    echo "1.2.3"
    return 0
  else
    echo "tool: '$1' is not a valid command."
    return 1
  fi
}

test_example() {
  local output
  bashunit::mock tool mockTool

  output="$(tool --version)"
  assert_successful_code
  assert_same "1.2.3" "${output}"

  output="$(tool foo)"
  assert_general_error
  assert_contains "is not a valid command" "${output}"
}

```
:::

## bashunit::spy
> `bashunit::spy "function"`

Overrides the original behavior of a callable to allow you to make various assertions about its calls.

::: code-group
```bash [Example]
function test_example() {
  bashunit::spy ps

  ps foo bar

  assert_have_been_called_with ps "foo bar"
  assert_have_been_called ps
}
```
:::

## assert_have_been_called
> `assert_have_been_called "spy"`

Reports an error if `spy` is not called.

::: code-group
```bash [Example]
function test_success() {
  bashunit::spy ps

  ps

  assert_have_been_called ps
}

function test_failure() {
  bashunit::spy ps

  assert_have_been_called ps
}
```
:::

## assert_have_been_called_with
> `assert_have_been_called_with spy expected [call_index]`

Reports an error if `spy` is not called with `expected`. When `call_index` is provided, the assertion checks the arguments of that specific call (starting at 1). Without `call_index` it checks the last invocation. Arguments are joined with spaces before comparison.

::: code-group
```bash [Example]
function test_success() {
  bashunit::spy ps

  ps foo
  ps bar

  assert_have_been_called_with ps "foo" 1
  assert_have_been_called_with ps "bar" 2
}

function test_failure() {
  bashunit::spy ps

  ps bar

  assert_have_been_called_with ps "foo" 1
}
```
:::


## assert_have_been_called_nth_with
> `assert_have_been_called_nth_with "nth" "spy" "expected"`

Reports an error if the `nth` invocation of `spy` was not called with `expected`. The index starts at 1. Reports an error if `spy` was called fewer than `nth` times.

::: code-group
```bash [Example]
function test_success() {
  bashunit::spy ps

  ps first
  ps second
  ps third

  assert_have_been_called_nth_with 1 ps "first"
  assert_have_been_called_nth_with 2 ps "second"
  assert_have_been_called_nth_with 3 ps "third"
}

function test_failure() {
  bashunit::spy ps

  ps first

  assert_have_been_called_nth_with 1 ps "wrong"
}
```
:::

## assert_have_been_called_times
> assert_have_been_called_times "expected" "spy"

Reports an error if `spy` is not called exactly `expected` times.

::: code-group
```bash [Example]
function test_success() {
  bashunit::spy ps

  ps
  ps

  assert_have_been_called_times 2 ps
}

function test_failure() {
  bashunit::spy ps

  ps
  ps

  assert_have_been_called_times 1 ps
}
```
:::

## assert_not_called
> `assert_not_called "spy"`

Reports an error if `spy` has been executed at least once.

::: code-group
```bash [Example]
function test_success() {
  bashunit::spy ps

  assert_not_called ps
}

function test_failure() {
  bashunit::spy ps

  ps

  assert_not_called ps
}
```
:::
