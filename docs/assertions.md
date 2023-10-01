# Assertions

When creating tests, you'll need to verify your commands and functions.
We provide assertions for these checks.
Below is their documentation.

## assert_equals
> `assert_equals "expected" "actual"`

Reports an error if the two variables `expected` and `actual` are not equal.

[assert_not_equals](#assert-not-equals) is the inverse of this assertion and takes the same arguments.

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

[assert_not_contains](#assert-not-contains) is the inverse of this assertion and takes the same arguments.

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

[assert_not_empty](#assert-not-empty) is the inverse of this assertion and takes the same arguments.

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

[assert_not_matches](#assert-not-matches) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assert_matches "^foo" "foobar"
}

function test_failure() {
  assert_matches "^bar" "foobar"
}
```

## assert_exit_code
> `assert_exit_code "expected" ["callable"]`

Reports an error if the exit code of `callable` is not equal to `expected`.

If `callable` is not provided, it takes the last executed command or function instead.

[assert_successful_code](#assert-successful-code), [assert_general_error](#assert-general-error) and [assert_command_not_found](#assert-command-not-found)
are more semantic versions of this assertion, for which you don't need to specify an exit code.

*Example:*
```bash
function test_success_with_callable() {
  function foo() {
    return 1
  }

  assert_exit_code "1" "$(foo)"
}

function test_success_without_callable() {
  function foo() {
    return 1
  }

  foo # function took instead `callable`

  assert_exit_code "1"
}

function test_failure() {
  function foo() {
    return 1
  }

  assert_exit_code "0" "$(foo)"
}
```

## assert_array_contains
> `assert_array_contains "needle" "haystack"`

Reports an error if `needle` is not an element of `haystack`.

[assert_array_not_contains](#assert-array-not-contains) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  local haystack=(foo bar baz)

  assert_array_contains "bar" "${haystack[@]}"
}

function test_failure() {
  local haystack=(foo bar baz)

  assert_array_contains "foobar" "${haystack[@]}"
}
```

## assert_successful_code
> `assert_successful_code ["callable"]`

Reports an error if the exit code of `callable` is not successful (`0`).

If `callable` is not provided, it takes the last executed command or function instead.

[assert_exit_code](#assert-exit-code) is the full version of this assertion where you can specify the expected exit code.

*Example:*
```bash
function test_success_with_callable() {
  function foo() {
    return 0
  }

  assert_successful_code "$(foo)"
}

function test_success_without_callable() {
  function foo() {
    return 0
  }

  foo # function took instead `callable`

  assert_successful_code
}

function test_failure() {
  function foo() {
    return 1
  }

  assert_successful_code "$(foo)"
}
```

## assert_general_error
> `assert_general_error ["callable"]`

Reports an error if the exit code of `callable` is not a general error (`1`).

If `callable` is not provided, it takes the last executed command or function instead.

[assert_exit_code](#assert-exit-code) is the full version of this assertion where you can specify the expected exit code.

*Example:*
```bash
function test_success_with_callable() {
  function foo() {
    return 1
  }

  assert_general_error "$(foo)"
}

function test_success_without_callable() {
  function foo() {
    return 1
  }

  foo # function took instead `callable`

  assert_general_error
}

function test_failure() {
  function foo() {
    return 0
  }

  assert_general_error "$(foo)"
}
```

## assert_command_not_found
> `assert_general_error ["callable"]`

Reports an error if `callable` exists.
In other words, if executing `callable` does not return a command not found exit code (`127`).

If `callable` is not provided, it takes the last executed command or function instead.

[assert_exit_code](#assert-exit-code) is the full version of this assertion where you can specify the expected exit code.

*Example:*
```bash
function test_success_with_callable() {
  assert_command_not_found "$(foo > /dev/null 2>&1)"
}

function test_success_without_callable() {
  foo > /dev/null 2>&1

  assert_command_not_found
}

function test_failure() {
  assert_command_not_found "$(ls > /dev/null 2>&1)"
}
```

## assert_file_exists
> `assert_file_exists "file"`

Reports an error if `file` does not exists, or it is a directory.

[assert_file_not_exists](#assert-file-not-exists) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  local file_path="foo.txt"
  touch "$file_path"

  assert_file_exists "$file_path"
  rm "$file_path"
}

function test_failure() {
  local file_path="foo.txt"
  rm -f $file_path

  assert_file_exists "$file_path"
}
```

## assert_is_file
> `assert_is_file "file"`

Reports an error if `file` is not a file.

*Example:*
```bash
function test_success() {
  local file_path="foo.txt"
  touch "$file_path"

  assert_is_file "$file_path"
  rm "$file_path"
}

function test_failure() {
  local dir_path="bar"
  mkdir "$dir_path"

  assert_is_file "$dir_path"
  rmdir "$dir_path"
}
```

## assert_is_file_empty
> `assert_is_file_empty "file"`

Reports an error if `file` is not empty.

*Example:*
```bash
function test_success() {
  local file_path="foo.txt"
  touch "$file_path"

  assert_is_file_empty "$file_path"
  rm "$file_path"
}

function test_failure() {
  local file_path="foo.txt"
  echo "bar" > "$file_path"

  assert_is_file_empty "$file_path"
  rm "$file_path"
}
```

## assert_not_equals
> `assert_not_equals "expected" "actual"`

Reports an error if the two variables `expected` and `actual` are equal.

[assert_equals](#assert-equals) is the inverse of this assertion and takes the same arguments.

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

[assert_contains](#assert-contains) is the inverse of this assertion and takes the same arguments.

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

[assert_empty](#assert-empty) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assert_not_empty "foo"
}

function test_failure() {
  assert_not_empty ""
}
```

## assert_not_matches
> `assert_not_matches "pattern" "value"`

Reports an error if `value` matches the regular expression `pattern`.

[assert_matches](#assert-matches) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assert_not_matches "foo$" "foobar"
}

function test_failure() {
  assert_not_matches "bar$" "foobar"
}
```

## assert_array_not_contains
> `assert_array_not_contains "needle" "haystack"`

Reports an error if `needle` is an element of `haystack`.

[assert_array_contains](#assert-array-contains) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  local haystack=(foo bar baz)

  assert_array_not_contains "foobar" "${haystack[@]}"
}

function test_failure() {
  local haystack=(foo bar baz)

  assert_array_not_contains "baz" "${haystack[@]}"
}
```

## assert_file_not_exists
> `assert_file_not_exists "file"`

Reports an error if `file` does exists.

[assert_file_exists](#assert-file-exists) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  local file_path="foo.txt"
  touch "$file_path"
  rm "$file_path"

  assert_file_not_exists "$file_path"
}

function test_failed() {
  local file_path="foo.txt"
  touch "$file_path"

  assert_file_not_exists "$file_path"
  rm "$file_path"
}
```
