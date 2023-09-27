# Assertions

When creating tests, you'll need to verify your commands and functions.
We provide assertions for these checks.
Below is their documentation.

## assert_equals
> `assert_equals "expected" "actual"`

Reports an error if the two variables `expected` and `actual` are not equal.

[assert_not_equals](#assert_not_equals) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assert_equals "foo" "foo"
}

function test_failure() {
  assert_equals "foo" "bar"
}
```

## assert_contains
> `assert_contains "needle" "haystack"`

Reports an error if `needle` is not a substring of `haystack`.

[assert_not_contains](#assert_not_contains) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assert_contains "foo" "foobar"
}

function test_failure() {
  assert_contains "baz" "foobar"
}
```

## assert_empty
> `assert_empty "actual"`

Reports an error if `actual` is not empty.

[assert_not_empty](#assert_not_empty) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assert_empty ""
}

function test_failure() {
  assert_empty "foo"
}
```

## assert_matches
> `assert_matches "pattern" "value"`

Reports an error if `value` does not match the regular expression `pattern`.

[assertNotMatches](#assertnotmatches) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assert_matches "^foo" "foobar"
}

function test_failure() {
  assert_matches "^bar" "foobar"
}
```

## assertExitCode
> `assertExitCode "expected" ["callable"]`

Reports an error if the exit code of `callable` is not equal to `expected`.

If `callable` is not provided, it takes the last executed command or function instead.

[assertSuccessfulCode](#assertsuccessfulcode), [assertGeneralError](#assertgeneralerror) and [assertCommandNotFound](#assertcommandnotfound)
are more semantic versions of this assertion, for which you don't need to specify an exit code.

*Example:*
```bash
function test_success_with_callable() {
  function foo() {
    return 1
  }

  assertExitCode "1" "$(foo)"
}

function test_success_without_callable() {
  function foo() {
    return 1
  }

  foo # function took instead `callable`

  assertExitCode "1"
}

function test_failure() {
  function foo() {
    return 1
  }

  assertExitCode "0" "$(foo)"
}
```

## assertArrayContains
> `assertArrayContains "needle" "haystack"`

Reports an error if `needle` is not an element of `haystack`.

[assertArrayNotContains](#assertarraynotcontains) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  local haystack=(foo bar baz)

  assertArrayContains "bar" "${haystack[@]}"
}

function test_failure() {
  local haystack=(foo bar baz)

  assertArrayContains "foobar" "${haystack[@]}"
}
```

## assertSuccessfulCode
> `assertSuccessfulCode ["callable"]`

Reports an error if the exit code of `callable` is not successful (`0`).

If `callable` is not provided, it takes the last executed command or function instead.

[assertExitCode](#assertexitcode) is the full version of this assertion where you can specify the expected exit code.

*Example:*
```bash
function test_success_with_callable() {
  function foo() {
    return 0
  }

  assertSuccessfulCode "$(foo)"
}

function test_success_without_callable() {
  function foo() {
    return 0
  }

  foo # function took instead `callable`

  assertSuccessfulCode
}

function test_failure() {
  function foo() {
    return 1
  }

  assertSuccessfulCode "$(foo)"
}
```

## assertGeneralError
> `assertGeneralError ["callable"]`

Reports an error if the exit code of `callable` is not a general error (`1`).

If `callable` is not provided, it takes the last executed command or function instead.

[assertExitCode](#assertexitcode) is the full version of this assertion where you can specify the expected exit code.

*Example:*
```bash
function test_success_with_callable() {
  function foo() {
    return 1
  }

  assertGeneralError "$(foo)"
}

function test_success_without_callable() {
  function foo() {
    return 1
  }

  foo # function took instead `callable`

  assertGeneralError
}

function test_failure() {
  function foo() {
    return 0
  }

  assertGeneralError "$(foo)"
}
```

## assertCommandNotFound
> `assertGeneralError ["callable"]`

Reports an error if `callable` exists.
In other words, if executing `callable` does not return a command not found exit code (`127`).

If `callable` is not provided, it takes the last executed command or function instead.

[assertExitCode](#assertexitcode) is the full version of this assertion where you can specify the expected exit code.

*Example:*
```bash
function test_success_with_callable() {
  assertCommandNotFound "$(foo > /dev/null 2>&1)"
}

function test_success_without_callable() {
  foo > /dev/null 2>&1

  assertCommandNotFound
}

function test_failure() {
  assertCommandNotFound "$(ls > /dev/null 2>&1)"
}
```

## assert_not_equals
> `assert_not_equals "expected" "actual"`

Reports an error if the two variables `expected` and `actual` are equal.

[assert_equals](#assert_equals) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assert_not_equals "foo" "bar"
}

function test_failure() {
  assert_not_equals "foo" "foo"
}
```

## assert_not_contains
> `assert_not_contains "needle" "haystack"`

Reports an error if `needle` is a substring of `haystack`.

[assert_contains](#assert_contains) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assert_not_contains "baz" "foobar"
}

function test_failure() {
  assert_not_contains "foo" "foobar"
}
```

## assert_not_empty
> `assert_not_empty "actual"`

Reports an error if `actual` is empty.

[assert_empty](#assert_empty) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assert_not_empty "foo"
}

function test_failure() {
  assert_not_empty ""
}
```

## assertNotMatches
> `assertNotMatches "pattern" "value"`

Reports an error if `value` matches the regular expression `pattern`.

[assert_matches](#assert_matches) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assertNotMatches "foo$" "foobar"
}

function test_failure() {
  assertNotMatches "bar$" "foobar"
}
```

## assertArrayNotContains
> `assertArrayNotContains "needle" "haystack"`

Reports an error if `needle` is an element of `haystack`.

[assertArrayContains](#assertarraycontains) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  local haystack=(foo bar baz)

  assertArrayNotContains "foobar" "${haystack[@]}"
}

function test_failure() {
  local haystack=(foo bar baz)

  assertArrayNotContains "baz" "${haystack[@]}"
}
```
