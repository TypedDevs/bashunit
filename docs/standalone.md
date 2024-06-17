# Standalone

You can use all bashunit assertions outside any tests if you would like to use them in integration or end-to-end tests, for entire applications or executables.

## Executing an assertion

If you want to use the nice assertions syntax of bashunit - without the tests context/functions, but to end-to-end tests executables, you can use the `-a|--assert` option when running `./bashunit` and call the assertion directly from there.

The return exit code will be `0` for success assertions and `1` for failures.

::: info
The prefix `assert_` is optional.
:::

::: code-group
```bash [Example]
# with `assert_` prefix
./bashunit -a assert_equals "foo" "foo"
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
    but got 'foo'
```
:::

