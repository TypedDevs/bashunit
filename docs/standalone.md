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
✗ Failed: Main::exec not_equals
    Expected 'foo'
    but got  'foo'
```
:::


## Lazy evaluations

You can evaluate the `exit_code` for your scripts using `eval...` instead of executing them with `$(...)` to avoid
interrupting the CI when encountering a potential error (anything different from `0`). For example:

::: code-group
```bash [Example]
../bashunit -a exit_code "0" "eval $PHPSTAN_PATH analyze \
  --no-progress --level 8 \
  --error-format raw ./" 1>&1 2> /tmp/error.log
```
```[Output]
Testing.php:3:Method Testing::bar() has no return type specified.
```
```[/tmp/error.log]
✗ Failed: Main::exec assert
    Expected '0'
    but got  '1'
```
:::
