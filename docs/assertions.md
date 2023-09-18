# Assertions

When creating tests, you'll need to verify your commands and functions.
We provide assertions for these checks.
Below is their documentation.

## assertEquals
> `assertEquals "expected" "actual"`

Reports an error if the two variables `expected` and `actual` are not equal.

[assertNotEquals](#assertnotequals) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assertEquals "foo" "foo"
}

function test_failure() {
  assertEquals "foo" "bar"
}
```

## assertContains
> `assertContains "needle" "haystack"`

Reports an error if `needle` is not a substring of `haystack`.

[assertNotContains](#assertnotcontains) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assertContains "foo" "foobar"
}

function test_failure() {
  assertContains "baz" "foobar"
}
```

## assertEmpty
> `assertEmpty "actual"`

Reports an error if `actual` is not empty.

[assertNotEmpty](#assertnotempty) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assertEmpty ""
}

function test_failure() {
  assertEmpty "foo"
}
```

## assertMatches
> `assertMatches "pattern" "value"`

Reports an error if `value` does not match the regular expression `pattern`.

[assertNotMatches](#assertnotmatches) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assertMatches "^foo" "foobar"
}

function test_failure() {
  assertMatches "^bar" "foobar"
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

## assertNotEquals
> `assertNotEquals "expected" "actual"`

Reports an error if the two variables `expected` and `actual` are equal.

[assertEquals](#assertequals) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assertNotEquals "foo" "bar"
}

function test_failure() {
  assertNotEquals "foo" "foo"
}
```

## assertNotContains
> `assertNotContains "needle" "haystack"`

Reports an error if `needle` is a substring of `haystack`.

[assertContains](#assertcontains) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assertNotContains "baz" "foobar"
}

function test_failure() {
  assertNotContains "foo" "foobar"
}
```

## assertNotEmpty
> `assertNotEmpty "actual"`

Reports an error if `actual` is empty.

[assertEmpty](#assertempty) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assertNotEmpty "foo"
}

function test_failure() {
  assertNotEmpty ""
}
```

## assertNotMatches
> `assertNotMatches "pattern" "value"`

Reports an error if `value` matches the regular expression `pattern`.

[assertMatches](#assertmatches) is the inverse of this assertion and takes the same arguments.

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
