---
description: "Complete reference of bashunit assertions for testing bash scripts: assert equals, contains, matches, exit codes, files, arrays and more, with examples."
---

# Assertions

When creating tests, you'll need to verify your commands and functions.
We provide assertions for these checks.
Below is their documentation.

Assertions are called **unprefixed** — `assert_same`, not `bashunit::assert_same`. Every
other helper does take the `bashunit::` prefix; see [Globals](/globals).

Run `bashunit doc` to print this catalogue in your terminal, or `bashunit doc <filter>`
to narrow it (`bashunit doc json`).

Any assertion here also runs from the shell without a test file:
`bashunit assert contains "world" "hello world"`. See [Standalone](/standalone).

`assert_same`, `assert_equals`, `assert_not_same`, `assert_not_equals` and the numeric
comparisons take an optional last argument used as the failure label:
`assert_same "1" "2" "my custom label"` reports `✗ Failed: my custom label`.

The string assertions whose signature ends in `...` take a variadic value: every argument
after the first is joined with **newlines** and compared as one value. They accept no
trailing label override, so `assert_contains "zzz" "abc" "my label"` searches
`abc\nmy label` instead of relabelling the failure.

## Quick reference

| Group | Assertions |
|-------|------------|
| **Booleans and equality** | [assert_true](#assert-true) · [assert_false](#assert-false) · [assert_same](#assert-same) · [assert_not_same](#assert-not-same) · [assert_equals](#assert-equals) · [assert_not_equals](#assert-not-equals) |
| **Strings** | [assert_contains](#assert-contains) · [assert_not_contains](#assert-not-contains) · [assert_contains_ignore_case](#assert-contains-ignore-case) · [assert_matches](#assert-matches) · [assert_not_matches](#assert-not-matches) · [assert_string_starts_with](#assert-string-starts-with) · [assert_string_not_starts_with](#assert-string-not-starts-with) · [assert_string_ends_with](#assert-string-ends-with) · [assert_string_not_ends_with](#assert-string-not-ends-with) · [assert_string_matches_format](#assert-string-matches-format) · [assert_string_not_matches_format](#assert-string-not-matches-format) · [assert_empty](#assert-empty) · [assert_not_empty](#assert-not-empty) · [assert_line_count](#assert-line-count) |
| **Numbers** | [assert_less_than](#assert-less-than) · [assert_less_or_equal_than](#assert-less-or-equal-than) · [assert_greater_than](#assert-greater-than) · [assert_greater_or_equal_than](#assert-greater-or-equal-than) · [assert_between](#assert-between) · [assert_not_between](#assert-not-between) · [assert_within_delta](#assert-within-delta) |
| **Dates** | [assert_date_equals](#assert-date-equals) · [assert_date_before](#assert-date-before) · [assert_date_after](#assert-date-after) · [assert_date_within_range](#assert-date-within-range) · [assert_date_within_delta](#assert-date-within-delta) |
| **Exit codes and commands** | [assert_exit_code](#assert-exit-code) · [assert_successful_code](#assert-successful-code) · [assert_unsuccessful_code](#assert-unsuccessful-code) · [assert_general_error](#assert-general-error) · [assert_command_available](#assert-command-available) · [assert_command_not_found](#assert-command-not-found) · [assert_exec](#assert-exec) |
| **Files** | [assert_file_exists](#assert-file-exists) · [assert_file_not_exists](#assert-file-not-exists) · [assert_file_contains](#assert-file-contains) · [assert_file_not_contains](#assert-file-not-contains) · [assert_is_file](#assert-is-file) · [assert_is_file_empty](#assert-is-file-empty) · [assert_is_file_not_empty](#assert-is-file-not-empty) · [assert_is_file_readable](#assert-is-file-readable) · [assert_is_file_not_readable](#assert-is-file-not-readable) · [assert_is_file_writable](#assert-is-file-writable) · [assert_is_file_not_writable](#assert-is-file-not-writable) · [assert_is_file_executable](#assert-is-file-executable) · [assert_is_file_not_executable](#assert-is-file-not-executable) · [assert_is_symlink](#assert-is-symlink) · [assert_is_not_symlink](#assert-is-not-symlink) · [assert_symlink_to](#assert-symlink-to) · [assert_file_permissions](#assert-file-permissions) · [assert_files_equals](#assert-files-equals) · [assert_files_not_equals](#assert-files-not-equals) |
| **Directories** | [assert_directory_exists](#assert-directory-exists) · [assert_directory_not_exists](#assert-directory-not-exists) · [assert_is_directory](#assert-is-directory) · [assert_is_directory_empty](#assert-is-directory-empty) · [assert_is_directory_not_empty](#assert-is-directory-not-empty) · [assert_is_directory_readable](#assert-is-directory-readable) · [assert_is_directory_not_readable](#assert-is-directory-not-readable) · [assert_is_directory_writable](#assert-is-directory-writable) · [assert_is_directory_not_writable](#assert-is-directory-not-writable) |
| **Arrays** | [assert_arrays_equal](#assert-arrays-equal) · [assert_array_contains](#assert-array-contains) · [assert_array_not_contains](#assert-array-not-contains) · [assert_array_length](#assert-array-length) |
| **JSON** | [assert_json_equals](#assert-json-equals) · [assert_json_contains](#assert-json-contains) · [assert_json_key_exists](#assert-json-key-exists) · [assert_json_key_not_exists](#assert-json-key-not-exists) · [assert_json_length](#assert-json-length) |
| **Duration** | [assert_duration](#assert-duration) · [assert_duration_less_than](#assert-duration-less-than) · [assert_duration_greater_than](#assert-duration-greater-than) |
| **Snapshots** | [assert_match_snapshot](#assert-match-snapshot) · [assert_match_named_snapshot](#assert-match-named-snapshot) · [assert_match_snapshot_ignore_colors](#assert-match-snapshot-ignore-colors) · [assert_match_named_snapshot_ignore_colors](#assert-match-named-snapshot-ignore-colors) |
| **Spies** | [assert_have_been_called](#assert-have-been-called) · [assert_not_called](#assert-not-called) · [assert_have_been_called_with](#assert-have-been-called-with) · [assert_have_been_called_with_any](#assert-have-been-called-with-any) · [assert_have_been_called_with_args](#assert-have-been-called-with-args) · [assert_have_been_called_nth_with](#assert-have-been-called-nth-with) · [assert_have_been_called_times](#assert-have-been-called-times) |
| **Assertions** | [assert_assertion_passes](#assert-assertion-passes) · [assert_assertion_fails](#assert-assertion-fails) · [assert_assertion_fails_with](#assert-assertion-fails-with) |
| **Manual failure** | [bashunit::fail](#bashunit-fail) |

## assert_true
> `assert_true bool|function|command [args...]`

Pass a command with its arguments as separate arguments:

```bash
assert_true test -d /tmp
assert_true grep -q foo ./file
assert_true my_function
```

Arguments are passed through untouched, so a value containing a space survives.

A **single** argument keeps its older meaning: it is run as one command word, so
`assert_true "test -d /tmp"` looks for a command with that whole name and fails
with `unknown command`. Quote the whole thing only with an `eval` prefix —
`assert_true "eval test -d /tmp"` — or, better, drop the quotes and use the form
above.

A purpose-built assertion is usually clearer still — `assert_directory_exists`
rather than a hand-rolled `test -d`.

Reports an error **unless** the argument results in a truthy value: `true` or `0`, or a
command or function that exits `0`.

- [assert_false](#assert-false) is the inverse of this assertion and takes the same arguments.

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
```
:::

## assert_false
> `assert_false bool|function|command [args...]`

Reports an error **unless** the argument results in a falsy value: `false` or `1`, or a
command or function that exits non-zero.

- [assert_true](#assert-true) is the inverse of this assertion and takes the same arguments.

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

Those are *characters*, not escape sequences. A backslash followed by `t` is
two characters and stays two characters, so comparing it against a real tab
fails; only the tab itself is stripped.

- [assert_same](#assert-same) is similar but including special chars.

::: code-group
```bash [Example]
function test_success() {
  assert_equals "foo" $'\e[31mfoo'
}

function test_failure() {
  assert_equals "foo" $'\e[31mbar'
}
```
:::

## assert_contains
> `assert_contains "needle" "haystack"...`

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
> `assert_matches "pattern" "value"...`

Reports an error if `value` does not match the regular expression `pattern`.

`pattern` is an ERE evaluated by `grep -E`. If it does not match as written, the value is
retried with every newline replaced by a space, so a single-line pattern can match across
lines: `assert_matches 'one two'` matches the two-line value `one\ntwo`.

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
> `assert_string_starts_with "needle" "haystack"...`

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
> `assert_string_ends_with "needle" "haystack"...`

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
| `%s` | One or more characters other than a space (tabs and newlines match) |
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
> `assert_line_count "count" "haystack"...`

Reports an error if `haystack` does not contain `count` lines.

A literal `\n` (backslash followed by `n`) counts as a line break too, so
`assert_line_count 2 'one\ntwo'` passes even though the value holds no real newline.

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

- [assert_greater_or_equal_than](#assert-greater-or-equal-than) is the counterpart of this assertion and takes the same arguments.

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

## assert_between
> `assert_between "min" "max" "actual"`

Reports an error if `actual` is outside the inclusive numeric range from `min` to `max`.
Integers, decimals, and negative values are supported. `min` must not be greater than `max`.

A non-numeric argument, or `min` greater than `max`, is a **usage error**: the assertion
returns 2 and the test is reported as an Error rather than a failure, with a message such
as `assert_between expects min <= max, got '500' and '100'`.

- [assert_not_between](#assert-not-between) is the exact negation and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_between "100" "500" "275"
  assert_between "0.1" "0.3" "0.2"
}

function test_failure() {
  assert_between "100" "500" "750"
}
```
:::

## assert_not_between
> `assert_not_between "min" "max" "actual"`

Reports an error if `actual` is inside the inclusive numeric range from `min` to `max`.
Integers, decimals, and negative values are supported. `min` must not be greater than `max`.

A non-numeric argument, or `min` greater than `max`, is a **usage error**: the assertion
returns 2 and the test is reported as an Error rather than a failure, with a message such
as `assert_between expects min <= max, got '500' and '100'`.

- [assert_between](#assert-between) is the exact negation and takes the same arguments.

::: code-group
```bash [Example]
function test_success() {
  assert_not_between "400" "499" "200"
}

function test_failure() {
  assert_not_between "400" "499" "404"
}
```
:::

## assert_within_delta
> `assert_within_delta "expected" "actual" "delta"`

Reports an error if `actual` is not within `delta` of `expected`
(i.e. `|actual - expected| > delta`). Supports floating-point values.
Useful for timing or measured values where exact equality is too strict.

The bound is inclusive, so `|actual - expected| == delta` passes. An operand that is not a
number, such as `1.2.3` or `5-3`, fails the assertion with `to all be numeric` instead of
being evaluated as an expression. A leading `+` is accepted.

::: code-group
```bash [Example]
function test_success() {
  assert_within_delta "3.14159" "3.14" "0.01"
}

function test_failure() {
  assert_within_delta "100" "105" "3"
}
```
:::

## assert_date_equals
> `assert_date_equals "expected" "actual"`

Reports an error if the two date values `expected` and `actual` are not equal.

Inputs are automatically converted to epoch seconds. Supported formats:
- Epoch seconds (integers): `1700000000`
- ISO 8601 date: `2023-11-14`
- ISO 8601 datetime: `2023-11-14T12:00:00`
- ISO 8601 datetime with UTC Z: `2023-11-14T12:00:00Z`
- ISO 8601 datetime with timezone offset: `2023-11-14T12:00:00+0100`
- Space-separated datetime: `2023-11-14 12:00:00`

You can mix formats in the same assertion (e.g., one epoch, one ISO).

Anything else, including an empty string, fails the assertion with
`Expected '<value>' to be 'a valid date'` rather than being coerced to `0`. This applies to
all five date assertions.

::: code-group
```bash [Example]
function test_success() {
  local now
  now="$(date +%s)"

  assert_date_equals "$now" "$now"
}

function test_failure() {
  assert_date_equals "1700000000" "1600000000"
}
```
:::

## assert_date_before
> `assert_date_before "expected" "actual"`

Reports an error if `actual` is not before `expected` (i.e. `actual` must be less than `expected`).

Inputs are automatically converted to epoch seconds. See [assert_date_equals](#assert-date-equals) for supported formats.

::: code-group
```bash [Example]
function test_success() {
  assert_date_before "1700000000" "1600000000"
}

function test_failure() {
  assert_date_before "1700000000" "1800000000"
}
```
:::

## assert_date_after
> `assert_date_after "expected" "actual"`

Reports an error if `actual` is not after `expected` (i.e. `actual` must be greater than `expected`).

Inputs are automatically converted to epoch seconds. See [assert_date_equals](#assert-date-equals) for supported formats.

::: code-group
```bash [Example]
function test_success() {
  assert_date_after "1600000000" "1700000000"
}

function test_failure() {
  assert_date_after "1600000000" "1500000000"
}
```
:::

## assert_date_within_range
> `assert_date_within_range "from" "to" "actual"`

Reports an error if `actual` does not fall between `from` and `to` (inclusive).

Inputs are automatically converted to epoch seconds. See [assert_date_equals](#assert-date-equals) for supported formats.

::: code-group
```bash [Example]
function test_success() {
  assert_date_within_range "1600000000" "1800000000" "1700000000"
}

function test_failure() {
  assert_date_within_range "1600000000" "1800000000" "1900000000"
}
```
:::

## assert_date_within_delta
> `assert_date_within_delta "expected" "actual" "delta"`

Reports an error if `actual` is not within `delta` seconds of `expected`.

`delta` is required: omitting it produces a shell error reported as an Error, not an
assertion failure.

Inputs are automatically converted to epoch seconds. See [assert_date_equals](#assert-date-equals) for supported formats.

::: code-group
```bash [Example]
function test_success() {
  local now
  now="$(date +%s)"
  local five_seconds_later=$(( now + 5 ))

  assert_date_within_delta "$now" "$five_seconds_later" "10"
}

function test_failure() {
  assert_date_within_delta "1700000000" "1700000020" "5"
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
> `assert_exec "command" [--exit <code>] [--stdout "text"] [--stderr "text"] [--stdout-contains "needle"] [--stdout-not-contains "needle"] [--stderr-contains "needle"] [--stderr-not-contains "needle"] [--stdin "input"]`

Runs `command` capturing its exit status, standard output and standard error and
checks all provided expectations. When `--exit` is omitted the expected exit
status defaults to `0`.

Use `--stdin` to feed input into interactive commands (e.g. commands using
`read`). Multiple answers can be passed by separating them with newlines.

Use `--stdout-contains` / `--stdout-not-contains` (and the `stderr-*` variants)
for substring matching when you don't want to assert against the full output.

Unrecognised arguments are silently dropped, so a mistyped flag such as
`--stdout-contain` checks nothing and the assertion passes on exit status alone. Extra
words after the command are dropped too: put arguments inside the command string,
`assert_exec "echo hello" --stdout "hello"`.

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

```bash [Interactive]
function question() {
  local name lang
  read -r name
  read -r lang
  echo "Your name is $name and you prefer $lang."
}

function test_interactive_prompt() {
  assert_exec question \
    --stdin "Chemaclass"$'\n'"Phel-Lang"$'\n' \
    --stdout-contains "Your name is Chemaclass and you prefer Phel-Lang." \
    --stdout-not-contains "Delphi" \
    --exit 0
}
```
:::

## assert_arrays_equal
> `assert_arrays_equal "expected..." -- "actual..."`

Reports an error if the arrays have different lengths or any element differs at the same index.

Use `--` to separate the expected array from the actual array.

::: code-group
```bash [Example]
function test_success() {
  local expected=(foo bar baz)
  local actual=(foo bar baz)

  assert_arrays_equal "${expected[@]}" -- "${actual[@]}"
}

function test_failure() {
  local expected=(foo bar baz)
  local actual=(foo baz bar)

  assert_arrays_equal "${expected[@]}" -- "${actual[@]}"
}
```
:::

## assert_array_contains
> `assert_array_contains "needle" "haystack"`

Reports an error if `needle` is not found in `haystack`.

`needle` is matched as a **substring of the array joined with spaces**, not element by
element, so `assert_array_contains "oob" foobar baz` and
`assert_array_contains "foo bar" foo bar baz` both pass. Use
[assert_arrays_equal](#assert-arrays-equal) when you need exact element comparison.

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

## assert_array_length
> `assert_array_length "expected_length" "array"`

Reports an error if `array` does not have exactly `expected_length` elements.

::: code-group
```bash [Example]
function test_success() {
  local haystack=(foo bar baz)

  assert_array_length 3 "${haystack[@]}"
}

function test_failure() {
  local haystack=(foo bar baz)

  assert_array_length 2 "${haystack[@]}"
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

::: warning Under `set -e`, pass the code as the third argument
A non-zero exit aborts the test before the assertion runs, so the code has to
be captured first — and capturing it sets `$?` to zero:

```bash
local code=0
some_command || code=$?

assert_successful_code            # reads $? — the assignment's 0
assert_successful_code "$code"    # the first argument is ignored, same result

assert_successful_code "" "" "$code"   # correct: read from the third argument
```

`assert_exit_code` takes a captured code the same way, but its first argument
is the *expected* code: `assert_exit_code 7 "" "$code"`.
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

::: warning Under `set -e`, pass the code as the third argument
A non-zero exit aborts the test before the assertion runs, so the code has to
be captured first — and capturing it sets `$?` to zero:

```bash
local code=0
some_command || code=$?

assert_unsuccessful_code            # reads $? — the assignment's 0
assert_unsuccessful_code "$code"    # the first argument is ignored, same result

assert_unsuccessful_code "" "" "$code"   # correct: read from the third argument
```

`assert_exit_code` takes a captured code the same way, but its first argument
is the *expected* code: `assert_exit_code 7 "" "$code"`.
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

::: warning Under `set -e`, pass the code as the third argument
A non-zero exit aborts the test before the assertion runs, so the code has to
be captured first — and capturing it sets `$?` to zero:

```bash
local code=0
some_command || code=$?

assert_general_error            # reads $? — the assignment's 0
assert_general_error "$code"    # the first argument is ignored, same result

assert_general_error "" "" "$code"   # correct: read from the third argument
```

`assert_exit_code` takes a captured code the same way, but its first argument
is the *expected* code: `assert_exit_code 7 "" "$code"`.
:::


## assert_command_available
> `assert_command_available "command"`

Reports an error if `command` is not available.

Availability uses the same `command -v` check as the
[bashunit::is_command_available](/globals#bashunit-is-command-available) helper, so
external commands, shell builtins and shell functions are supported. The command
is only resolved; it is not executed.

::: code-group
```bash [Example]
function test_dependencies_are_installed() {
  assert_command_available bash
  assert_command_available jq
}

function test_shell_function_is_available() {
  function project_build() {
    make build
  }

  assert_command_available project_build
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

::: warning Under `set -e`, pass the code as the third argument
A non-zero exit aborts the test before the assertion runs, so the code has to
be captured first — and capturing it sets `$?` to zero:

```bash
local code=0
some_command || code=$?

assert_command_not_found            # reads $? — the assignment's 0
assert_command_not_found "$code"    # the first argument is ignored, same result

assert_command_not_found "" "" "$code"   # correct: read from the third argument
```

`assert_exit_code` takes a captured code the same way, but its first argument
is the *expected* code: `assert_exit_code 7 "" "$code"`.
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

Reports an error if `file` does not contain the search string.

`search` is matched **literally** (`grep -F`); regex metacharacters have no special meaning.

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

## assert_is_symlink
> `assert_is_symlink "path"`

Reports an error if `path` is not a symbolic link.

Every other filesystem assertion follows the link — `assert_is_file` and
`assert_file_exists` report on the *target*, so a link and the file it points at
look identical, and a dangling link reads as "does not exist". This is the
assertion that tells them apart, and it passes for a link whose target is gone.

::: code-group
```bash [Example]
function test_success() {
  ln -s /etc/hosts ./hosts_link

  assert_is_symlink "./hosts_link"
}
```
:::

## assert_is_not_symlink
> `assert_is_not_symlink "path"`

Reports an error if `path` is a symbolic link.

## assert_symlink_to
> `assert_symlink_to "expected_target" "path"`

Reports an error if `path` is not a symbolic link, or if it points somewhere
other than `expected_target`.

The target is compared **as written**, via `readlink`, not fully resolved: that
is what the test author wrote, and `readlink -f` is GNU-only. A relative link
therefore compares as the relative string it is.

::: code-group
```bash [Example]
function test_success() {
  ln -s ./releases/42 ./current

  assert_symlink_to "./releases/42" "./current"
}
```
:::

## assert_file_permissions
> `assert_file_permissions "mode" "file"`

Reports an error if `file` does not have the expected octal permission `mode`
(e.g. `644`, `0755`). A leading zero is optional (`0755` and `755` are equal).
Works on both Linux (GNU `stat`) and macOS (BSD `stat`).

::: code-group
```bash [Example]
function test_success() {
  local file="/tmp/file-path.txt"
  touch "$file"
  chmod 600 "$file"

  assert_file_permissions "600" "$file"
}

function test_failure() {
  local file="/tmp/file-path.txt"
  touch "$file"
  chmod 644 "$file"

  assert_file_permissions "600" "$file"
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


## assert_is_file_not_empty
> `assert_is_file_not_empty "file"`

Reports an error if `file` is empty. A file holding a single newline counts as
not empty.

::: code-group
```bash [Example]
function test_success() {
  generate_report > report.txt

  assert_is_file_not_empty "report.txt"
}
```
:::

## assert_is_file_readable
> `assert_is_file_readable "file"`

Reports an error if `file` is not readable.

The failure says which of the three things went wrong: the path does not exist,
it exists but is not a file, or it is a file the current user cannot read. The
same applies to every assertion below.

::: code-group
```bash [Example]
function test_success() {
  assert_is_file_readable "/etc/hosts"
}
```
```[Output]
✗ Failed: Success
    Expected '/tmp/nope'
    to be readable
    but does not exist
```
:::

## assert_is_file_not_readable
> `assert_is_file_not_readable "file"`

Reports an error if `file` is readable.

::: code-group
```bash [Example]
function test_success() {
  chmod 000 "$secret"

  assert_is_file_not_readable "$secret"
}
```
:::

::: warning
Running as root bypasses the permission bits, so this assertion passes for
nothing under `sudo` or in a root container. Skip such a test there:
`bashunit::skip_if "[ \"$(id -u)\" -eq 0 ]" "root reads anything"`.
:::

## assert_is_file_writable
> `assert_is_file_writable "file"`

Reports an error if `file` is not writable.

::: code-group
```bash [Example]
function test_success() {
  assert_is_file_writable "$log_file"
}
```
:::

## assert_is_file_not_writable
> `assert_is_file_not_writable "file"`

Reports an error if `file` is writable.

::: code-group
```bash [Example]
function test_success() {
  chmod 444 "$config"

  assert_is_file_not_writable "$config"
}
```
:::

## assert_is_file_executable
> `assert_is_file_executable "file"`

Reports an error if `file` is not executable — the thing a shell project most
often wants to assert about a file it generated.

::: code-group
```bash [Example]
function test_success() {
  ./build.sh

  assert_is_file_executable "bin/tool"
}
```
```[Output]
✗ Failed: Success
    Expected 'bin/tool'
    to be executable
    but is not executable
```
:::

## assert_is_file_not_executable
> `assert_is_file_not_executable "file"`

Reports an error if `file` is executable.

::: code-group
```bash [Example]
function test_success() {
  assert_is_file_not_executable "README.md"
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
  local directory
  directory="$(bashunit::temp_dir)"

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
  local directory
  directory="$(bashunit::temp_dir)"
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
  local directory
  directory="$(bashunit::temp_dir)"
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

## assert_not_equals
> `assert_not_equals "expected" "actual"`

Reports an error if the two variables `expected` and `actual` are equal ignoring the special chars like ANSI Escape Sequences (colors) and other special chars like tabs and new lines.

- [assert_equals](#assert-equals) is the inverse of this assertion and takes the same arguments.

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
> `assert_not_contains "needle" "haystack"...`

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
> `assert_string_not_starts_with "needle" "haystack"...`

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
> `assert_string_not_ends_with "needle" "haystack"...`

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
> `assert_not_matches "pattern" "value"...`

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

Reports an error if `needle` is found in `haystack`.

`needle` is matched as a **substring of the array joined with spaces**, not element by
element, so `assert_array_not_contains "foo bar" foo bar` fails even though no single
element is `foo bar`.

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

`search` is matched as a **basic regular expression** (`grep`), unlike
[assert_file_contains](#assert-file-contains) which matches literally, so
`assert_file_not_contains file 'a.c'` fails on a file containing `abc`.

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
  local directory
  directory="$(bashunit::temp_dir)"

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
  local directory
  directory="$(bashunit::temp_dir)"
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
  local directory
  directory="$(bashunit::temp_dir)"
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

Reports an error if `expected` and `actual` have the same contents.

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

A key whose value is `null` or `false` is reported as missing, because `jq -e` treats both
as absent. `0` and `""` are fine. To assert a false or null value, use
`assert_json_contains ".flag" "false" "$json"`.

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

A key whose value is `null` or `false` is reported as missing, the same guard
[assert_json_key_exists](#assert-json-key-exists) uses.

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

## assert_json_key_not_exists
> `assert_json_key_not_exists "key" "json"`

Reports an error if `key` exists in the JSON string. Uses [jq](https://jqlang.github.io/jq/) syntax for key paths. Requires `jq` to be installed; if missing the test is skipped.

A key with a `null` value still exists and makes this assertion fail. Invalid JSON also fails the assertion.

::: code-group
```bash [Example]
function test_success() {
  assert_json_key_not_exists ".user.password" '{"user":{"name":"bashunit"}}'
}

function test_failure() {
  assert_json_key_not_exists ".user.password" '{"user":{"password":null}}'
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

## assert_json_length
> `assert_json_length "expected" "key" "json"`

Reports an error if the array, object, or string at `key` does not have the expected length. Arrays count elements, objects count key-value pairs, and strings count Unicode codepoints, following `jq`'s `length` behavior. A missing path, unsupported value type, invalid JSON, or non-numeric expected length fails instead of being compared as empty or zero. Requires `jq` to be installed; if missing the test is skipped.

::: code-group
```bash [Example]
function test_success() {
  assert_json_length 3 ".items" '{"items":[1,2,3]}'
  assert_json_length 2 ".metadata" '{"metadata":{"page":1,"total":3}}'
}

function test_failure() {
  assert_json_length 2 ".items" '{"items":[1,2,3]}'
  assert_json_length 0 ".missing" '{"items":[]}'
}
```
:::

## assert_duration
> `assert_duration "command" threshold_ms`

Reports an error if `command` takes longer than `threshold_ms` milliseconds to execute. Uses the framework's portable clock internally.

Requires `awk`, plus `bc` or `awk` for the arithmetic. Unlike the JSON assertions, the
duration assertions do **not** skip when the tool is missing: the test is reported as an
Error.

::: code-group
```bash [Example]
function test_success() {
  assert_duration "echo hello" 500
}

function test_failure() {
  assert_duration "sleep 2" 1000
}
```
:::

## assert_duration_less_than
> `assert_duration_less_than "command" threshold_ms`

Reports an error if `command` takes `threshold_ms` milliseconds or more to execute. Stricter than [assert_duration](#assert-duration) which allows equal values.

::: code-group
```bash [Example]
function test_success() {
  assert_duration_less_than "echo hello" 500
}

function test_failure() {
  assert_duration_less_than "sleep 2" 1000
}
```
:::

## assert_duration_greater_than
> `assert_duration_greater_than "command" threshold_ms`

Reports an error if `command` completes in `threshold_ms` milliseconds or less. Useful for verifying that a command takes at least a minimum amount of time.

::: code-group
```bash [Example]
function test_success() {
  assert_duration_greater_than "sleep 1" 500
}

function test_failure() {
  assert_duration_greater_than "echo hello" 5000
}
```
:::

## assert_match_snapshot
> `assert_match_snapshot "actual" ["snapshot_file"]`

Reports an error if `actual` differs from the stored snapshot. On the first run no snapshot exists, so one is written from `actual` and the assertion passes — review and commit that file.

Pass `snapshot_file` to share one snapshot between tests; by default each test gets its own, named after the test function.

See [Snapshots](/snapshots) for the full workflow, including how to update a snapshot after an intentional change.

::: code-group
```bash [Example]
function test_success() {
  assert_match_snapshot "$(./bin/render --help)"
}

function test_failure() {
  assert_match_snapshot "output that no longer matches the stored snapshot"
}
```
:::

## assert_match_snapshot_ignore_colors
> `assert_match_snapshot_ignore_colors "actual" ["snapshot_file"]`

Same as [assert_match_snapshot](#assert-match-snapshot), but strips ANSI escape sequences from `actual` before comparing. Use it for commands whose colouring depends on the terminal.

::: code-group
```bash [Example]
function test_success() {
  assert_match_snapshot_ignore_colors "$(./bin/render --help)"
}

function test_failure() {
  assert_match_snapshot_ignore_colors "output that no longer matches the stored snapshot"
}
```
:::

## assert_match_named_snapshot
> `assert_match_named_snapshot "name" "actual"`

Matches `actual` against a snapshot whose filename includes `name`. Use it for multiple independent snapshots in one test without constructing file paths yourself. Names are normalized so they cannot escape the test's `snapshots/` directory.

::: code-group
```bash [Example]
function test_render_modes() {
  assert_match_named_snapshot "compact" "$(./bin/render --compact)"
  assert_match_named_snapshot "verbose" "$(./bin/render --verbose)"
}
```
:::

## assert_match_named_snapshot_ignore_colors
> `assert_match_named_snapshot_ignore_colors "name" "actual"`

Named version of [assert_match_snapshot_ignore_colors](#assert-match-snapshot-ignore-colors). ANSI escape sequences are stripped from `actual` before it is stored or compared.

::: code-group
```bash [Example]
function test_colored_render_modes() {
  assert_match_named_snapshot_ignore_colors "compact" "$(./bin/render --compact)"
  assert_match_named_snapshot_ignore_colors "verbose" "$(./bin/render --verbose)"
}
```
:::

## assert_have_been_called
> `assert_have_been_called "command"`

Reports an error if the spied `command` was never called. Requires `bashunit::spy command` first — see [Test doubles](/test-doubles).

Every `assert_have_been_called*` and `assert_not_called` fails with
`was never registered as a spy` when the name was never passed to `bashunit::spy`,
including `assert_not_called`, which does **not** pass for an unspied name. Spies are
cleared between tests, so spy inside the test that asserts on it.

::: code-group
```bash [Example]
function test_success() {
  bashunit::spy send_email
  notify_user

  assert_have_been_called send_email
}

function test_failure() {
  bashunit::spy send_email

  assert_have_been_called send_email
}
```
:::

## assert_have_been_called_with
> `assert_have_been_called_with "command" "expected_args" [nth]`

Reports an error if the spied `command` was not called with `expected_args`. Checks the **last** call unless a trailing all-digits `nth` selects a specific one; the failure names the call it compared.
Because `nth` is detected as a trailing all-digits argument, an expectation whose last
argument is a number is read as the selector: `assert_have_been_called_with git commit -m 5`
compares `commit -m` against call 5. Pass the expectation as one quoted string,
`assert_have_been_called_with git "commit -m 5"`, or use
[assert_have_been_called_with_args](#assert-have-been-called-with-args), which has no `nth`. To match any call, use [assert_have_been_called_with_any](#assert-have-been-called-with-any).

Note the argument order: the spy comes first here, but *second* in [assert_have_been_called_times](#assert-have-been-called-times).

::: code-group
```bash [Example]
function test_success() {
  bashunit::spy send_email
  notify_user "a@b.c"

  assert_have_been_called_with send_email "--to a@b.c"
}

function test_failure() {
  bashunit::spy send_email
  notify_user "a@b.c"

  assert_have_been_called_with send_email "--to nobody@example.com"
}
```
:::

## assert_have_been_called_with_any
> `assert_have_been_called_with_any "command" "expected_args"`

Reports an error if no recorded call to the spied `command` received `expected_args`. Where [assert_have_been_called_with](#assert-have-been-called-with) compares a single call — the last one, or the one at `nth` — this one scans them all, so the assertion does not break when an unrelated call is added after it.

::: code-group
```bash [Example]
function test_success() {
  bashunit::spy send_email
  notify_all "a@b.c" "d@e.f"

  assert_have_been_called_with_any send_email "--to a@b.c"
}

function test_failure() {
  bashunit::spy send_email
  notify_all "a@b.c" "d@e.f"

  assert_have_been_called_with_any send_email "--to nobody@example.com"
}
```
:::

## assert_have_been_called_with_args
> `assert_have_been_called_with_args "command" "expected_arg"...`

Reports an error if the **last** call to the spied `command` did not receive exactly these arguments. Unlike [assert_have_been_called_with](#assert-have-been-called-with), the arguments are compared one by one, so `cmd "a b"` does not match `cmd a b`. Use it whenever an argument may contain spaces, such as a path.

There is no `nth` parameter: a trailing number would be indistinguishable from a numeric argument.

::: code-group
```bash [Example]
function test_success() {
  bashunit::spy touch
  create_report "/tmp/my reports"

  assert_have_been_called_with_args touch "/tmp/my reports/out.txt"
}

function test_failure() {
  bashunit::spy touch
  create_report "/tmp/my reports"

  assert_have_been_called_with_args touch "/tmp/my" "reports/out.txt"
}
```
:::

## assert_have_been_called_times
> `assert_have_been_called_times "expected_count" "command"`

Reports an error if the spied `command` was not called exactly `expected_count` times. The count comes **first**, the spy second.

::: code-group
```bash [Example]
function test_success() {
  bashunit::spy send_email
  notify_all "a@b.c" "d@e.f"

  assert_have_been_called_times 2 send_email
}

function test_failure() {
  bashunit::spy send_email
  notify_all "a@b.c" "d@e.f"

  assert_have_been_called_times 1 send_email
}
```
:::

## assert_have_been_called_nth_with
> `assert_have_been_called_nth_with "nth" "command" "expected_args"`

Reports an error if call number `nth` of the spied `command` did not receive `expected_args`. Calls are numbered from 1.

::: code-group
```bash [Example]
function test_success() {
  bashunit::spy send_email
  notify_all "a@b.c" "d@e.f"

  assert_have_been_called_nth_with 1 send_email "--to a@b.c"
}

function test_failure() {
  bashunit::spy send_email
  notify_all "a@b.c" "d@e.f"

  assert_have_been_called_nth_with 1 send_email "--to d@e.f"
}
```
:::

## assert_not_called
> `assert_not_called "command"`

Reports an error if the spied `command` was called at all. The inverse of [assert_have_been_called](#assert-have-been-called).

::: code-group
```bash [Example]
function test_success() {
  bashunit::spy send_email
  notify_user --dry-run

  assert_not_called send_email
}

function test_failure() {
  bashunit::spy send_email
  notify_user

  assert_not_called send_email
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

## assert_assertion_passes
> `assert_assertion_passes <assertion> [args...]`

Reports an error unless the given assertion reports a success. Use it to test
your own [custom assertions](/custom-asserts).

The inner assertion runs isolated: its verdict is never added to the run totals,
its failure output never reaches the console, and it cannot trip the
stop-on-failure guard for the rest of your test. Exactly one assertion is
counted — this one.

::: code-group
```bash [Example]
function test_success() {
  assert_assertion_passes assert_positive_number 1
}
function test_failure() {
  assert_assertion_passes assert_positive_number 0
}
```
:::

## assert_assertion_fails
> `assert_assertion_fails <assertion> [args...]`

Reports an error unless the given assertion reports a failure. An assertion that
counts nothing at all also fails this check.

The message the inner assertion produced is left in
`$_BASHUNIT_ASSERT_INNER_OUTPUT_OUT`, colour-stripped and flattened to one line,
so you can also assert on what it did *not* say.

::: code-group
```bash [Example]
function test_success() {
  assert_assertion_fails assert_positive_number 0
}
function test_failure() {
  assert_assertion_fails assert_positive_number 1
}
```
:::

## assert_assertion_fails_with
> `assert_assertion_fails_with <expected_message> <assertion> [args...]`

Reports an error unless the given assertion fails **and** its failure message
contains `expected_message`. This is how a custom assertion's output contract
gets tested without rebuilding the expected string from `console_results`.

::: code-group
```bash [Example]
function test_success() {
  assert_assertion_fails_with "positive number" assert_positive_number 0
}
function test_failure() {
  assert_assertion_fails_with "negative number" assert_positive_number 0
}
```
:::

## Related

- [Custom asserts](/custom-asserts) — build your own domain-specific assertions
- [Test doubles](/test-doubles) — mocks and spies for isolated tests
- [Data providers](/data-providers) — run the same assertions over many inputs
- [Globals](/globals) — `bashunit::` helper functions
- [Standalone](/standalone) — run these assertions straight from the command line
