# Assertions

When creating tests, you'll need to verify your commands and functions.
We provide assertions for these checks.
Below is their documentation.

## assert_equals
> `assert_equals "expected" "actual"`

Reports an error if the two variables `expected` and `actual` are not equal.

[assert_not_equals](#assert-not-equals) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_equals "foo" "foo"
}

function test_failure() {
  assert_equals "foo" "bar"
}
```
:::

## assert_contains
> `assert_contains "needle" "haystack"`

Reports an error if `needle` is not a substring of `haystack`.

[assert_not_contains](#assert-not-contains) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_contains "foo" "foobar"
}

function test_failure() {
  assert_contains "baz" "foobar"
}
```

:::

## assert_contains_ignore_case
> `assert_contains_ignore_case "needle" "haystack"`

Reports an error if `needle` is not a substring of `haystack`. Differences in casing are ignored when needle is searched
for in haystack.

:::

## assert_empty
> `assert_empty "actual"`

Reports an error if `actual` is not empty.

[assert_not_empty](#assert-not-empty) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_empty ""
}

function test_failure() {
  assert_empty "foo"
}
```
:::

## assert_matches
> `assert_matches "pattern" "value"`

Reports an error if `value` does not match the regular expression `pattern`.

[assert_not_matches](#assert-not-matches) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_matches "^foo" "foobar"
}

function test_failure() {
  assert_matches "^bar" "foobar"
}
```
:::

## assert_string_starts_with
> `assert_string_starts_with "needle" "haystack"`

Reports an error if `haystack` does not starts with `needle`.

[assert_string_not_starts_with](#assert-string-not-starts-with) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_string_starts_with "foo" "foobar"
}

function test_failure() {
  assert_string_starts_with "baz" "foobar"
}
```
:::

## assert_string_ends_with
> `assert_string_ends_with "needle" "haystack"`

Reports an error if `haystack` does not ends with `needle`.

[assert_string_not_ends_with](#assert-string-not-ends-with) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_string_ends_with "bar" "foobar"
}

function test_failure() {
  assert_string_ends_with "foo" "foobar"
}
```
:::

## assert_less_than
> `assert_less_than "expected" "actual"`

Reports an error if `actual` is higher or equal than `expected`.

[assert_greater_than](#assert-greater-than) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_less_than "999" "1"
}

function test_failure() {
  assert_less_than "1" "999"
}
```
:::

## assert_less_or_equal_than
> `assert_less_or_equal_than "expected" "actual"`

Reports an error if `actual` is higher than `expected`.

[assert_greater_than](#assert-greater-or-equal-than) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_less_or_equal_than "999" "1"
}

function test_success_with_two_equal_numbers() {
  assert_less_or_equal_than "999" "999"
}

function test_failure() {
  assert_less_or_equal_than "1" "999"
}
```
:::

## assert_greater_than
> `assert_greater_than "expected" "actual"`

Reports an error if `actual` is higher or equal than `expected`.

[assert_less_than](#assert-less-than) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_greater_than "1" "999"
}

function test_failure() {
  assert_greater_than "999" "1"
}
```
:::

## assert_greater_or_equal_than
> `assert_greater_or_equal_than "expected" "actual"`

Reports an error if `expected` is higher than `actual`.

[assert_less_or_equal_than](#assert-less-or-equal-than) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_greater_or_equal_than "1" "999"
}

function test_success_with_two_equal_numbers() {
  assert_greater_or_equal_than "999" "999"
}

function test_failure() {
  assert_greater_or_equal_than "999" "1"
}
```
:::

## assert_exit_code
> `assert_exit_code "expected" ["callable"]`

Reports an error if the exit code of `callable` is not equal to `expected`.

If `callable` is not provided, it takes the last executed command or function instead.

[assert_successful_code](#assert-successful-code), [assert_general_error](#assert-general-error) and [assert_command_not_found](#assert-command-not-found)
are more semantic versions of this assertion, for which you don't need to specify an exit code.

::: code-group
```bash [Example]
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
:::

## assert_array_contains
> `assert_array_contains "needle" "haystack"`

Reports an error if `needle` is not an element of `haystack`.

[assert_array_not_contains](#assert-array-not-contains) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  local haystack=(foo bar baz)

  assert_array_contains "bar" "${haystack[@]}"
}

function test_failure() {
  local haystack=(foo bar baz)

  assert_array_contains "foobar" "${haystack[@]}"
}
```
:::

## assert_successful_code
> `assert_successful_code ["callable"]`

Reports an error if the exit code of `callable` is not successful (`0`).

If `callable` is not provided, it takes the last executed command or function instead.

[assert_exit_code](#assert-exit-code) is the full version of this assertion where you can specify the expected exit code.

::: code-group
```bash [Example]
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
:::

## assert_general_error
> `assert_general_error ["callable"]`

Reports an error if the exit code of `callable` is not a general error (`1`).

If `callable` is not provided, it takes the last executed command or function instead.

[assert_exit_code](#assert-exit-code) is the full version of this assertion where you can specify the expected exit code.

::: code-group
```bash [Example]
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
:::

## assert_command_not_found
> `assert_general_error ["callable"]`

Reports an error if `callable` exists.
In other words, if executing `callable` does not return a command not found exit code (`127`).

If `callable` is not provided, it takes the last executed command or function instead.

[assert_exit_code](#assert-exit-code) is the full version of this assertion where you can specify the expected exit code.

::: code-group
```bash [Example]
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
:::

## assert_file_exists
> `assert_file_exists "file"`

Reports an error if `file` does not exists, or it is a directory.

[assert_file_not_exists](#assert-file-not-exists) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
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
:::

## assert_is_file
> `assert_is_file "file"`

Reports an error if `file` is not a file.

::: code-group
```bash [Example]
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
:::

## assert_is_file_empty
> `assert_is_file_empty "file"`

Reports an error if `file` is not empty.

::: code-group
```bash [Example]
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
:::

## assert_directory_exists
> `assert_directory_exists "directory"`

Reports an error if `directory` does not exist.

[assert_directory_not_exists](#assert-directory-not-exists) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  local directory="/var"

  assert_directory_exists "$directory"
}

function test_failure() {
  local directory="/nonexistent_directory"

  assert_directory_exists "$directory"
}
```
:::

## assert_is_directory
> `assert_is_directory "directory"`

Reports an error if `directory` is not a directory.

::: code-group
```bash [Example]
function test_success() {
  local directory="/var"

  assert_is_directory "$directory"
}

function test_failure() {
  local file="/etc/hosts"

  assert_is_directory "$file"
}
```
:::

## assert_is_directory_empty
> `assert_is_directory_empty "directory"`

Reports an error if `directory` is not an empty directory.

[assert_is_directory_not_empty](#assert-is-directory-not-empty) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  local directory="/home/user/empty_directory"
  mkdir "$directory"

  assert_is_directory_empty "$directory"
}

function test_failure() {
  local directory="/etc"

  assert_is_directory_empty "$directory"
}
```
:::

## assert_is_directory_readable
> `assert_is_directory_readable "directory"`

Reports an error if `directory` is not a readable directory.

[assert_is_directory_not_readable](#assert-is-directory-not-readable) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  local directory="/var"

  assert_is_directory_readable "$directory"
}

function test_failure() {
  local directory="/home/user/test"
  chmod -r "$directory"

  assert_is_directory_readable "$directory"
}
```
:::

## assert_is_directory_writable
> `assert_is_directory_writable "directory"`

Reports an error if `directory` is not a writable directory.

[assert_is_directory_not_writable](#assert-is-directory-not-writable) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  local directory="/tmp"

  assert_is_directory_writable "$directory"
}

function test_failure() {
  local directory="/home/user/test"
  chmod -w "$directory"

  assert_is_directory_writable "$directory"
}
```
:::

## assert_not_equals
> `assert_not_equals "expected" "actual"`

Reports an error if the two variables `expected` and `actual` are equal.

[assert_equals](#assert-equals) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_not_equals "foo" "bar"
}

function test_failure() {
  assert_not_equals "foo" "foo"
}
```
:::

## assert_not_contains
> `assert_not_contains "needle" "haystack"`

Reports an error if `needle` is a substring of `haystack`.

[assert_contains](#assert-contains) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_not_contains "baz" "foobar"
}

function test_failure() {
  assert_not_contains "foo" "foobar"
}
```
:::

## assert_string_not_starts_with
> `assert_string_not_starts_with "needle" "haystack"`

Reports an error if `haystack` does starts with `needle`.

[assert_string_starts_with](#assert-string-starts-with) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_string_not_starts_with "bar" "foobar"
}

function test_failure() {
  assert_string_not_starts_with "foo" "foobar"
}
```
:::

## assert_string_not_ends_with
> `assert_string_not_ends_with "needle" "haystack"`

Reports an error if `haystack` does ends with `needle`.

[assert_string_ends_with](#assert-string-ends-with) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_string_not_ends_with "foo" "foobar"
}

function test_failure() {
  assert_string_not_ends_with "bar" "foobar"
}
```
:::

## assert_not_empty
> `assert_not_empty "actual"`

Reports an error if `actual` is empty.

[assert_empty](#assert-empty) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_not_empty "foo"
}

function test_failure() {
  assert_not_empty ""
}
```
:::

## assert_not_matches
> `assert_not_matches "pattern" "value"`

Reports an error if `value` matches the regular expression `pattern`.

[assert_matches](#assert-matches) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_not_matches "foo$" "foobar"
}

function test_failure() {
  assert_not_matches "bar$" "foobar"
}
```
:::

## assert_array_not_contains
> `assert_array_not_contains "needle" "haystack"`

Reports an error if `needle` is an element of `haystack`.

[assert_array_contains](#assert-array-contains) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  local haystack=(foo bar baz)

  assert_array_not_contains "foobar" "${haystack[@]}"
}

function test_failure() {
  local haystack=(foo bar baz)

  assert_array_not_contains "baz" "${haystack[@]}"
}
```
:::

## assert_file_not_exists
> `assert_file_not_exists "file"`

Reports an error if `file` does exists.

[assert_file_exists](#assert-file-exists) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
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
:::

## assert_directory_not_exists
> `assert_directory_not_exists "directory"`

Reports an error if `directory` exists.

[assert_directory_exists](#assert-directory-exists) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  local directory="/nonexistent_directory"

  assert_directory_not_exists "$directory"
}

function test_failure() {
  local directory="/var"

  assert_directory_not_exists "$directory"
}
```
:::

## assert_is_directory_not_empty
> `assert_is_directory_not_empty "directory"`

Reports an error if `directory` is empty.

[assert_is_directory_empty](#assert-is-directory-empty) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  local directory="/etc"

  assert_is_directory_not_empty "$directory"
}

function test_failure() {
  local directory="/home/user/empty_directory"
  mkdir "$directory"

  assert_is_directory_not_empty "$directory"
}
```
:::

## assert_is_directory_not_readable
> `assert_is_directory_not_readable "directory"`

Reports an error if `directory` is readable.

[assert_is_directory_readable](#assert-is-directory-readable) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  local directory="/home/user/test"
  chmod -r "$directory"

  assert_is_directory_not_readable "$directory"
}

function test_failure() {
  local directory="/var"

  assert_is_directory_not_readable "$directory"
}
```
:::

## assert_is_directory_not_writable
> `assert_is_directory_not_writable "directory"`

Reports an error if `directory` is writable.

[assert_is_directory_writable](#assert-is-directory-writable) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  local directory="/home/user/test"
  chmod -w "$directory"

  assert_is_directory_not_writable "$directory"
}

function test_failure() {
  local directory="/tmp"

  assert_is_directory_not_writable "$directory"
}
```
:::
