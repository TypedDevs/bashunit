# Standalone

You can use all bashunit assertions outside any tests if you would like to use them in integration or end-to-end tests, for entire applications or executables.

## Executing an assertion

If you want to use the nice assertions syntax of bashunit - without the tests context/functions, but to end-to-end tests executables, you can use the `-a|--assert` option when running `./bashunit` and call the assertion directly from there.

The return exit code will be:
- `0` success assertion
- `1` failed assertion
- `127` non-existing function

::: info
The prefix `assert_` is optional.
:::

::: code-group
```bash [Example]
# with `assert_` prefix
./bashunit -a assert_same "foo" "foo"

# or without prefix
./bashunit -a equals "foo" "foo"
```
```[Output]
# No output - exit code 0 (success)
```
:::

::: code-group
```bash [Example]
# with `assert_` prefix
./bashunit -a assert_not_equals "foo" "foo"

# or without prefix
./bashunit -a not_equals "foo" "foo"
```
```[Output]
✗ Failed: assert not_equals
    Expected 'foo'
    but got  'foo'
```
:::

## Lazy evaluations

You can evaluate the `exit_code` for your scripts using the command to call as raw-string instead of
executing them with `$(...)` to avoid interrupting the CI when encountering a potential error (anything but `0`).

::: code-group
```bash [Example]
./bashunit -a exit_code "1" "$PHPSTAN_PATH analyze \
  --no-progress --level 8 \
  --error-format raw ./"
```
```[Output]
Testing.php:3:Method Testing::bar() has no return type specified.
```
:::

This is useful to get control over the output of your "callable":

::: code-group
```bash [Example]
OUTPUT=$(./bashunit -a exit_code "1" "$PHPSTAN_PATH analyze \
  --no-progress --level 8 \
  --error-format raw ./")
./bashunit -a line_count 1 "$OUTPUT"
```
```[Output]
# No output
```
:::

### Full control over the stdout and stderr

The stdout will be used for the callable result, while bashunit output will be on stderr.
This way you can control the FD and redirect the output as you need.

::: code-group
```bash [Example]
./bashunit -a exit_code "0" "$PHPSTAN_PATH analyze \
  --no-progress --level 8 \
  --error-format raw ./" 2> /tmp/error.log
```
```[Output]
Testing.php:3:Method Testing::bar() has no return type specified.
```
```[/tmp/error.log]
✗ Failed: assert exit_code
    Expected '0'
    but got  '1'
```
:::

## Multiple assertions

You can chain multiple assertions on a single command output using the `assert` subcommand:

::: code-group
```bash [Example]
./bashunit assert "echo 'error message' && exit 1" exit_code "1" contains "error"
```
```[Output]
error message
# Exit code 0 (all assertions passed)
```
:::

This is equivalent to running each assertion separately:

```bash
OUTPUT=$(./bashunit -a exit_code "1" "echo 'error message' && exit 1")
./bashunit -a contains "error" "$OUTPUT"
```

You can chain as many assertions as needed:

::: code-group
```bash [Example]
./bashunit assert "my_script.sh" \
  exit_code "0" \
  contains "success" \
  not_contains "error"
```
```[Output]
# Script output here
# Exit code 0 (all assertions passed)
```
:::

::: info
Exit code assertions (`exit_code`, `successful_code`, `general_error`, etc.) receive the command's exit code. All other assertions (`contains`, `equals`, `matches`, etc.) receive the command's stdout output.
:::
