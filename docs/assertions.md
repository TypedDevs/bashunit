# Assertions

When creating tests, you'll need to verify your commands and functions.
We provide assertions for these checks.
Below is their documentation.

## assert_true
> `assert_true bool|function|command`

Reports an error if the argument result in a truthy value: `true` or `0`.

- [assert_false](#assert-false) is similar but different.

::: code-group
```bash [Example]
function test_success() {
  assert_true true
  assert_true 0
  assert_true "eval return 0"
  assert_true mock_true
}

function test_failure() {
  assert_true false
  assert_true 1
  assert_true "eval return 1"
  assert_true mock_false
}
```
```bash [globals.sh]
function mock_true() {
  return 0
}
function mock_false() {
  return 1
}
:::

## assert_false
> `assert_false bool|function|command`

Reports an error if the argument result in a falsy value: `false` or `1`.

- [assert_true](#assert-true) is similar but different.

::: code-group
```bash [Example]
function test_success() {
  assert_false false
  assert_false 1
  assert_false "eval return 1"
  assert_false mock_false
}

function test_failure() {
  assert_false true
  assert_false 0
  assert_false "eval return 0"
  assert_false mock_true
}
```
```bash [globals.sh]
function mock_true() {
  return 0
}
function mock_false() {
  return 1
}
```
:::

## assert_same
> `assert_same "expected" "actual"`

Reports an error if the `expected` and `actual` are not the same - including special chars.

- [assert_not_same](#assert-not-same) is the inverse of this assertion and takes the same arguments.
- [assert_equals](#assert-equals) is similar but ignoring the special chars.

::: code-group
```bash [Example]
function test_success() {
  assert_same "foo" "foo"
}

function test_failure() {
  assert_same "foo" "bar"
}
```
:::

## assert_equals
> `assert_equals "expected" "actual"`

Reports an error if the two variables `expected` and `actual` are not equal ignoring the special chars like ANSI Escape Sequences (colors) and other special chars like tabs and new lines.

- [assert_same](#assert-same) is similar but including special chars.

::: code-group
```bash [Example]
function test_success() {
  assert_equals "foo" "\e[31mfoo"
}

function test_failure() {
  assert_equals "\e[31mfoo" "\e[31mfoo"
}
```
:::

## assert_contains
> `assert_contains "needle" "haystack"`

Reports an error if `needle` is not a substring of `haystack`.

- [assert_not_contains](#assert-not-contains) is the inverse of this assertion and takes the same arguments.

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

Reports an error if `needle` is not a substring of `haystack`.
Differences in casing are ignored when needle is searched for in haystack.

::: code-group
```bash [Example]
function test_success() {
  assert_contains_ignore_case "foo" "FooBar"
}
function test_failure() {
  assert_contains_ignore_case "baz" "FooBar"
}
```
:::

## assert_empty
> `assert_empty "actual"`

Reports an error if `actual` is not empty.

- [assert_not_empty](#assert-not-empty) is the inverse of this assertion and takes the same arguments.

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

- [assert_not_matches](#assert-not-matches) is the inverse of this assertion and takes the same arguments.

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

- [assert_string_not_starts_with](#assert-string-not-starts-with) is the inverse of this assertion and takes the same arguments.

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

- [assert_string_not_ends_with](#assert-string-not-ends-with) is the inverse of this assertion and takes the same arguments.

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

## assert_string_matches_format
> `assert_string_matches_format "format" "value"`

Reports an error if `value` does not match the `format` string. The format string uses PHPUnit-style placeholders:

| Placeholder | Matches |
|-------------|---------|
| `%d` | One or more digits |
| `%i` | Signed integer (e.g. `+1`, `-42`) |
| `%f` | Floating point number (e.g. `3.14`) |
| `%s` | One or more non-whitespace characters |
| `%x` | Hexadecimal (e.g. `ff00ab`) |
| `%e` | Scientific notation (e.g. `1.5e10`) |
| `%%` | Literal `%` character |

- [assert_string_not_matches_format](#assert-string-not-matches-format) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_string_matches_format "%d items found" "42 items found"
  assert_string_matches_format "%s has %d items at %f each" "cart has 5 items at 9.99 each"
}

function test_failure() {
  assert_string_matches_format "%d items" "hello world"
}
```
:::

## assert_line_count
> `assert_line_count "count" "haystack"`

Reports an error if `haystack` does not contain `count` lines.

::: code-group
```bash [Example]
function test_success() {
  local string="this is line one
this is line two
this is line three"

  assert_line_count 3 "$string"
}

function test_failure() {
  assert_line_count 2 "foobar"
}
```
:::

## assert_less_than
> `assert_less_than "expected" "actual"`

Reports an error if `actual` is not less than `expected`.

- [assert_greater_than](#assert-greater-than) is the inverse of this assertion and takes the same arguments.

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

Reports an error if `actual` is not less than or equal to `expected`.

- [assert_greater_than](#assert-greater-or-equal-than) is the inverse of this assertion and takes the same arguments.

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

Reports an error if `actual` is not greater than `expected`.

- [assert_less_than](#assert-less-than) is the inverse of this assertion and takes the same arguments.

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

Reports an error if `actual` is not greater than or equal to `expected`.

- [assert_less_or_equal_than](#assert-less-or-equal-than) is the inverse of this assertion and takes the same arguments.

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
> `assert_exit_code "expected"`

Reports an error if the exit code of the last executed command is not equal to `expected`.

This assertion captures `$?` from the command executed **before** calling the assertion.
It does **not** execute a string command passed as a second parameter.

::: tip
Use [assert_exec](#assert-exec) if you want to pass a command as a string and check its exit code:
`assert_exec "your_command" --exit 0`
:::

- [assert_successful_code](#assert-successful-code), [assert_unsuccessful_code](#assert-unsuccessful-code), [assert_general_error](#assert-general-error) and [assert_command_not_found](#assert-command-not-found)
are more semantic versions of this assertion, for which you don't need to specify an exit code.

::: code-group
```bash [Example]
function test_success_checking_previous_command() {
  function foo() {
    return 1
  }

  foo

  assert_exit_code "1"
}

function test_success_with_external_command() {
  touch /tmp/myfile

  assert_exit_code "0"
}

function test_failure() {
  function foo() {
    return 1
  }

  foo

  assert_exit_code "0"
}
```
:::

## assert_exec
> `assert_exec "command" [--exit <code>] [--stdout "text"] [--stderr "text"]`

Runs `command` capturing its exit status, standard output and standard error and
checks all provided expectations. When `--exit` is omitted the expected exit
status defaults to `0`.

::: code-group
```bash [Example]
function sample() {
  echo "out"
  echo "err" >&2
  return 1
}

function test_success() {
  assert_exec sample --exit 1 --stdout "out" --stderr "err"
}

function test_failure() {
  assert_exec sample --exit 0 --stdout "out" --stderr "err"
}
```
:::

## assert_array_contains
> `assert_array_contains "needle" "haystack"`

Reports an error if `needle` is not an element of `haystack`.

- [assert_array_not_contains](#assert-array-not-contains) is the inverse of this assertion and takes the same arguments.

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
> `assert_successful_code`

Reports an error if the exit code of the last executed command is not successful (`0`).

This assertion captures `$?` from the command executed **before** calling the assertion.
It does **not** execute a string command passed as a parameter.

::: tip
Use [assert_exec](#assert-exec) if you want to pass a command as a string and check its exit code:
`assert_exec "your_command"` (defaults to expecting exit code 0)
:::

- [assert_exit_code](#assert-exit-code) is the full version of this assertion where you can specify the expected exit code.

::: code-group
```bash [Example]
function test_success_with_function() {
  function foo() {
    return 0
  }

  foo

  assert_successful_code
}

function test_success_with_external_command() {
  touch /tmp/myfile

  assert_successful_code
}

function test_failure() {
  function foo() {
    return 1
  }

  foo

  assert_successful_code
}
```
:::

## assert_unsuccessful_code
> `assert_unsuccessful_code`

Reports an error if the exit code of the last executed command is not unsuccessful (non-zero).

This assertion captures `$?` from the command executed **before** calling the assertion.
It does **not** execute a string command passed as a parameter.

::: tip
Use [assert_exec](#assert-exec) if you want to pass a command as a string and check its exit code:
`assert_exec "your_command" --exit 1`
:::

- [assert_exit_code](#assert-exit-code) is the full version of this assertion where you can specify the expected exit code.

::: code-group
```bash [Example]
function test_success_with_function() {
  function foo() {
    return 1
  }

  foo

  assert_unsuccessful_code
}

function test_success_with_failing_command() {
  ls /nonexistent_path 2>/dev/null

  assert_unsuccessful_code
}

function test_failure() {
  function foo() {
    return 0
  }

  foo

  assert_unsuccessful_code
}
```
:::

## assert_general_error
> `assert_general_error`

Reports an error if the exit code of the last executed command is not a general error (`1`).

This assertion captures `$?` from the command executed **before** calling the assertion.
It does **not** execute a string command passed as a parameter.

::: tip
Use [assert_exec](#assert-exec) if you want to pass a command as a string and check its exit code:
`assert_exec "your_command" --exit 1`
:::

- [assert_exit_code](#assert-exit-code) is the full version of this assertion where you can specify the expected exit code.

::: code-group
```bash [Example]
function test_success_with_function() {
  function foo() {
    return 1
  }

  foo

  assert_general_error
}

function test_success_with_external_command() {
  grep "nonexistent" /dev/null

  assert_general_error
}

function test_failure() {
  function foo() {
    return 0
  }

  foo

  assert_general_error
}
```
:::

## assert_command_not_found
> `assert_command_not_found`

Reports an error if the last executed command did not return a "command not found" exit code (`127`).

This assertion captures `$?` from the command executed **before** calling the assertion.
It does **not** execute a string command passed as a parameter.

::: tip
Use [assert_exec](#assert-exec) if you want to pass a command as a string and check its exit code:
`assert_exec "nonexistent_command" --exit 127`
:::

- [assert_exit_code](#assert-exit-code) is the full version of this assertion where you can specify the expected exit code.

::: code-group
```bash [Example]
function test_success_with_nonexistent_command() {
  nonexistent_command 2>/dev/null

  assert_command_not_found
}

function test_failure_with_existing_command() {
  ls > /dev/null 2>&1

  assert_command_not_found
}
```
:::

## assert_file_exists
> `assert_file_exists "file"`

Reports an error if `file` does not exists, or it is a directory.

- [assert_file_not_exists](#assert-file-not-exists) is the inverse of this assertion and takes the same arguments.

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

## assert_file_contains
> `assert_file_contains "file" "search"`

Reports an error if `file` does not contains the search string.

- [assert_file_not_contains](#assert-file-not-contains) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  local file="/tmp/file-path.txt"
  echo -e "original content" > "$file"

  assert_file_contains "$file" "content"
}

function test_failure() {
  local file="/tmp/file-path.txt"
  echo -e "original content" > "$file"

  assert_file_contains "$file" "non existing"
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

- [assert_directory_not_exists](#assert-directory-not-exists) is the inverse of this assertion and takes the same arguments.

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

- [assert_is_directory_not_empty](#assert-is-directory-not-empty) is the inverse of this assertion and takes the same arguments.

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

- [assert_is_directory_not_readable](#assert-is-directory-not-readable) is the inverse of this assertion and takes the same arguments.

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

- [assert_is_directory_not_writable](#assert-is-directory-not-writable) is the inverse of this assertion and takes the same arguments.

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

## assert_files_equals
> `assert_files_equals "expected" "actual"`

Reports an error if `expected` and `actual` are not equals.

- [assert_files_not_equals](#assert-files-not-equals) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  local expected="/tmp/file1.txt"
  local actual="/tmp/file2.txt"

  echo "file content" > "$expected"
  echo "file content" > "$actual"

  assert_files_equals "$expected" "$actual"
}

function test_failure() {
  local expected="/tmp/file1.txt"
  local actual="/tmp/file2.txt"

  echo "file content" > "$expected"
  echo "different content" > "$actual"

  assert_files_equals "$expected" "$actual"
}
```
```[Output]
✓ Passed: Success
✗ Failed: Failure
    Expected '/tmp/file1.txt'
    Compared '/tmp/file2.txt'
    Diff '@@ -1 +1 @@
-file content
+different content'
```
:::

## assert_not_same
> `assert_not_same "expected" "actual"`

Reports an error if the two variables `expected` and `actual` are the same value.

- [assert_same](#assert-same) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_not_same "foo" "bar"
}

function test_failure() {
  assert_not_same "foo" "foo"
}
```
:::

## assert_not_contains
> `assert_not_contains "needle" "haystack"`

Reports an error if `needle` is a substring of `haystack`.

- [assert_contains](#assert-contains) is the inverse of this assertion and takes the same arguments.

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

- [assert_string_starts_with](#assert-string-starts-with) is the inverse of this assertion and takes the same arguments.

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

- [assert_string_ends_with](#assert-string-ends-with) is the inverse of this assertion and takes the same arguments.

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

- [assert_empty](#assert-empty) is the inverse of this assertion and takes the same arguments.

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

- [assert_matches](#assert-matches) is the inverse of this assertion and takes the same arguments.

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

## assert_string_not_matches_format
> `assert_string_not_matches_format "format" "value"`

Reports an error if `value` matches the `format` string. See [assert_string_matches_format](#assert-string-matches-format) for supported placeholders.

- [assert_string_matches_format](#assert-string-matches-format) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_string_not_matches_format "%d items" "hello world"
}

function test_failure() {
  assert_string_not_matches_format "%d items" "42 items"
}
```
:::

## assert_array_not_contains
> `assert_array_not_contains "needle" "haystack"`

Reports an error if `needle` is an element of `haystack`.

- [assert_array_contains](#assert-array-contains) is the inverse of this assertion and takes the same arguments.

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

- [assert_file_exists](#assert-file-exists) is the inverse of this assertion and takes the same arguments.

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

## assert_file_not_contains
> `assert_file_not_contains "file" "search"`

Reports an error if `file` contains the search string.

- [assert_file_contains](#assert-file-contains) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  local file="/tmp/file-path.txt"
  echo -e "original content" > "$file"

  assert_file_not_contains "$file" "non existing"
}

function test_failure() {
  local file="/tmp/file-path.txt"
  echo -e "original content" > "$file"

  assert_file_not_contains "$file" "content"
}
```
:::

## assert_directory_not_exists
> `assert_directory_not_exists "directory"`

Reports an error if `directory` exists.

- [assert_directory_exists](#assert-directory-exists) is the inverse of this assertion and takes the same arguments.

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

- [assert_is_directory_empty](#assert-is-directory-empty) is the inverse of this assertion and takes the same arguments.

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

- [assert_is_directory_readable](#assert-is-directory-readable) is the inverse of this assertion and takes the same arguments.

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

- [assert_is_directory_writable](#assert-is-directory-writable) is the inverse of this assertion and takes the same arguments.

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


## assert_files_not_equals
> `assert_files_not_equals "expected" "actual"`

Reports an error if `expected` and `actual` are not equals.

- [assert_files_equals](#assert-files-equals) is the inverse of this assertion and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  local expected="/tmp/file1.txt"
  local actual="/tmp/file2.txt"

  echo "file content" > "$expected"
  echo "different content" > "$actual"

  assert_files_not_equals "$expected" "$actual"
}

function test_failure() {

  local expected="/tmp/file1.txt"
  local actual="/tmp/file2.txt"

  echo "file content" > "$expected"
  echo "file content" > "$actual"

  assert_files_not_equals "$expected" "$actual"
}
```
```[Output]
✓ Passed: Success
✗ Failed: Failure
    Expected '/tmp/file1.txt'
    Compared '/tmp/file2.txt'
    Diff 'Files are equals'
```
:::

## assert_json_key_exists
> `assert_json_key_exists "key" "json"`

Reports an error if `key` does not exist in the JSON string. Uses [jq](https://jqlang.github.io/jq/) syntax for key paths. Requires `jq` to be installed; if missing the test is skipped.

::: code-group
```bash [Example]
function test_success() {
  assert_json_key_exists ".name" '{"name":"bashunit","version":"1.0"}'
  assert_json_key_exists ".data.id" '{"data":{"id":42}}'
}

function test_failure() {
  assert_json_key_exists ".missing" '{"name":"bashunit"}'
}
```
:::

## assert_json_contains
> `assert_json_contains "key" "expected" "json"`

Reports an error if `key` does not exist in the JSON string or its value does not equal `expected`. Uses [jq](https://jqlang.github.io/jq/) syntax for key paths. Requires `jq` to be installed; if missing the test is skipped.

::: code-group
```bash [Example]
function test_success() {
  assert_json_contains ".name" "bashunit" '{"name":"bashunit","version":"1.0"}'
  assert_json_contains ".count" "42" '{"count":42}'
}

function test_failure() {
  assert_json_contains ".name" "other" '{"name":"bashunit"}'
  assert_json_contains ".missing" "value" '{"name":"bashunit"}'
}
```
:::

## assert_json_equals
> `assert_json_equals "expected" "actual"`

Reports an error if the two JSON strings are not structurally equal. Key order is ignored. Requires `jq` to be installed; if missing the test is skipped.

::: code-group
```bash [Example]
function test_success() {
  assert_json_equals '{"b":2,"a":1}' '{"a":1,"b":2}'
}

function test_failure() {
  assert_json_equals '{"a":1}' '{"a":2}'
}
```
:::

## bashunit::fail
> `bashunit::fail "failure message"`

Unambiguously reports an error message. Useful for reporting specific message
when testing situations not covered by any `assert_*` functions.

::: code-group
```bash [Example]
function test_success() {
  if [ "$(date +%-H)" -gt 25 ]; then
    bashunit::fail "Something is very wrong with your clock"
  fi
}
function test_failure() {
  if [ "$(date +%-H)" -lt 25 ]; then
    bashunit::fail "This test will always fail"
  fi
}
```
:::
