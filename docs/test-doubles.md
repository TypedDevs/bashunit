---
description: "Create test doubles in bashunit: use mocks to override functions and spies to assert calls and arguments, with parallel-safe isolation per test."
---

# Test doubles

Test doubles let you override an existing function to write tests isolated from external behaviour: use mocks to replace a function's output, and spies to assert that a function was called, with which arguments, and how many times.

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
A lone all-digits argument is an exit code, not an implementation — the same convention `bashunit::spy` uses. The mock then produces no output and returns that code, which is all an error-path test usually needs:

::: code-group
```bash [Example]
function test_example() {
  bashunit::mock curl 1

  local code=0
  curl https://example.com || code=$?

  assert_same "1" "$code"
}
```
:::

To produce output *and* a non-zero exit code, pass a function: `bashunit::mock curl my_failing_curl`.

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

## bashunit::unmock
> `bashunit::unmock "function"`

Removes a double: it drops the function override — restoring the real command — and deletes the state files a spy recorded its calls in. It is a no-op for a name that was never mocked or spied.

::: code-group
```bash [Example]
function test_example() {
  bashunit::mock ls echo "mocked"
  assert_same "mocked" "$(ls)"

  bashunit::unmock ls

  assert_not_same "mocked" "$(ls)"
}
```
:::

### Lifecycle of a double

You rarely need to call it, because doubles are cleaned up for you:

- A double created **inside a test** is removed after that test. There is no need to unmock in `tear_down`, and nothing leaks into the next test.
- A double created in **`set_up_before_script`** stays in place for every test in the file — that is the point of declaring it there.

Each test runs in its own subshell, so `bashunit::unmock` only affects the test that calls it. Calling it on a `set_up_before_script` double suspends that double for the current test; the following tests still see it.

Reach for it when a single test needs the real command back after exercising the mocked path, or when it needs a spy's recorded calls to start over mid-test. Re-declaring a double does not require it: a second `bashunit::mock` or `bashunit::spy` on the same command replaces the first.

## Sandbox mode

> `bashunit test --sandbox`
> `bashunit test --sandbox-allow <cmd,...>`

A double only protects the command you remembered to double. A typo in the
mock name, or a `bashunit::unmock` earlier in the file, and the test reaches
the real `curl` — and passes, slowly and differently in CI.

Under `--sandbox` a test may only run commands it **mocked** or the run
**allowed**. Anything else fails the test with a message naming it:

::: code-group
```bash [Example]
function test_fetches_the_user() {
  curl "https://api.example.com/user/1"   # not mocked
}
```
```[Output]
✗ Error: Fetches the user
    Sandbox: 'curl' is not mocked and not allowed. Mock it with
    bashunit::mock, or run with --sandbox-allow curl.
```
:::

Mock it and the same test passes, because a mock is a shell function and
functions win over anything on `PATH`:

```bash
bashunit::mock curl echo '{"id":1}'
```

Notes:

- **Shell builtins are unaffected** (`echo`, `printf`, `[`, `test`, `read`),
  and so is everything bashunit itself needs while a test runs — the baseline
  allowlist covers `awk`, `sed`, `grep`, `cat`, `date`, `mktemp`, `git` and
  friends. The point is to constrain the test's reach to *services*, not to
  take coreutils away from it.
- `--sandbox-allow curl,jq` widens the allowlist; the flag is repeatable.
- `bashunit::unmock curl` inside a sandboxed test puts the block back, rather
  than handing the test the real command.
- A command invoked by **absolute path** (`/usr/bin/curl`) is not blocked, and
  neither is one that appears in `PATH` after the run started. See
  [ADR-012](https://github.com/TypedDevs/bashunit/blob/main/adrs/adr-012-sandbox-mode.md)
  for the mechanism and what it cannot see.
- Off by default. Enable it per run, or with `BASHUNIT_SANDBOX=true` in
  `.bashunitrc`.

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

::: tip Failures list the recorded calls
When a call assertion fails, the recorded calls are printed below the failure, so you can tell "called with other arguments" from "called in another order" or "called more often than expected" without re-running:

```
✗ Failed: My test
    Expected 'first'
    but got  'second'
    Recorded calls to 'touch' (2):
      1: first
      2: second
```

Long logs stop after 10 entries and end with `… and N more`.
:::

::: tip Call assertions require a registered spy
Every `assert_have_been_called*` / `assert_not_called` assertion fails when the name it targets was never passed to `bashunit::spy` — or was removed by `bashunit::unmock`, or belongs to a previous test:

```
✗ Failed: My test
    Expected 'tuoch'
    was never registered as a spy; call it first with 'bashunit::spy tuoch'
```

Without that check a typo would report zero calls, so `assert_not_called tuoch` would pass while asserting nothing. Spies are cleared between tests, so spy inside the test that asserts on them.
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

Only one call is compared, and the failure says which one (`compared 'the last of 2 calls'`). To match any recorded call, use [assert_have_been_called_with_any](#assert-have-been-called-with-any).

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


## assert_have_been_called_with_any
> `assert_have_been_called_with_any spy expected`

Reports an error if **no** recorded call of `spy` received `expected`. Use it when the requirement is "this side effect happened" rather than "this side effect happened last": `assert_have_been_called_with` only compares one call, so it breaks as soon as an unrelated call is added after it.

Arguments are joined with spaces, like `assert_have_been_called_with`.

::: code-group
```bash [Example]
function test_success() {
  bashunit::spy ps

  ps first
  ps second

  assert_have_been_called_with_any ps "first"
}

function test_failure() {
  bashunit::spy ps

  ps first
  ps second

  assert_have_been_called_with_any ps "third"
}
```
:::

## assert_have_been_called_with_args
> `assert_have_been_called_with_args spy expected...`

Reports an error if the last invocation of `spy` did not receive exactly these arguments. Arguments are compared one by one instead of being joined with spaces, so an argument containing a space cannot be confused with two arguments — the check `assert_have_been_called_with` cannot make.

There is no `call_index` parameter: a trailing number could not be told apart from a numeric argument.

::: code-group
```bash [Example]
function test_success() {
  bashunit::spy touch

  touch "a b"

  assert_have_been_called_with_args touch "a b"
}

function test_failure() {
  bashunit::spy touch

  touch "a b"

  # passes with assert_have_been_called_with, fails here
  assert_have_been_called_with_args touch "a" "b"
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
> `assert_have_been_called_times "expected" "spy"`

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

## Related

- [Assertions](/assertions) — the built-in assertion reference
- [Custom asserts](/custom-asserts) — build your own domain-specific assertions
- [Common patterns](/common-patterns) — real-world testing patterns
