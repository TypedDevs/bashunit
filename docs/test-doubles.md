# Test doubles

When creating tests, you might need to override existing function to be able to write isolated tests from external behaviour. To accomplish this, you can use mocks. You can also check that a function was called with certain arguments or even a number of times with a spy.

Temporary files created by spies are isolated per test run, so they work reliably when executing tests in parallel.

Spies record their calls in temporary files scoped to each test run.
This avoids clashes between processes and allows spies to work reliably when tests execute in parallel using `BASHUNIT_PARALLEL_RUN`.

## mock
> `mock "function" "body"`

Allows you to override the behavior of a callable.

::: code-group
```bash [Example]
function test_example() {
  mock ps echo hello world

  assert_same "hello world" "$(ps)"
}
```
:::

> `mock "function" "output"`

Allows you to override the output of a callable.

::: code-group
```bash [Example]
function test_example() {
  function code() {
    ps a | grep bash
  }

  mock ps<<EOF
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
  mock date echo "2024-05-01"

  function run() {
    date
  }

  assert_same "2024-05-01" "$(run)"
}
```
:::

## spy
> `spy "function"`

Overrides the original behavior of a callable to allow you to make various assertions about its calls.

::: code-group
```bash [Example]
function test_example() {
  spy ps

  ps foo bar

  assert_have_been_called_with "foo bar" ps
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
  spy ps

  ps

  assert_have_been_called ps
}

function test_failure() {
  spy ps

  assert_have_been_called ps
}
```
:::

## assert_have_been_called_with
> `assert_have_been_called_with "expected" "spy" [call_index]`

Reports an error if `spy` is not called with `expected`. When `call_index` is
provided, the assertion checks the arguments of that specific call (starting at
1). Without `call_index` it checks the last invocation.

::: code-group
```bash [Example]
function test_success() {
  spy ps

  ps foo
  ps bar

  assert_have_been_called_with "foo" ps 1
  assert_have_been_called_with "bar" ps 2
}

function test_failure() {
  spy ps

  ps bar

  assert_have_been_called_with "foo" ps 1
}
```
:::

## assert_have_been_called_times
> assert_have_been_called_times "expected" "spy"

Reports an error if `spy` is not called exactly `expected` times.

::: code-group
```bash [Example]
function test_success() {
  spy ps

  ps
  ps

  assert_have_been_called_times 2 ps
}

function test_failure() {
  spy ps

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
  spy ps

  assert_not_called ps
}

function test_failure() {
  spy ps

  ps

  assert_not_called ps
}
```
:::
