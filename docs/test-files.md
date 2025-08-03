# Test files

**bashunit** offers a range of features for test files.
In this section, you'll find information about these features along with some helpful tips.

## Test file names

**bashunit** is flexible about how you name your test files.

You can use a directory name, and bashunit will look for all files (ending with `test.sh` or `test.bash`) recursively inside that directory, and execute them.

If you're using wildcards for scanning your tests, keep in mind that the initial search can slow down if you don't filter the test files in the wildcard.

To optimize this, we recommend adding a `test` prefix or suffix to your test file names, and include this identifier in your wildcard pattern too (e.g., `**/*test.sh` or `**/*test.bash`).
This naming convention not only speeds up the scanning process but also helps you keep your test files organized.

This is useful regardless of whether your test files are located near your production code or share directories with your mocks, stubs, or fixtures.

## Test function names

**bashunit** will search for and execute all test functions it finds within each test file.
To distinguish test functions from auxiliary functions, the names must be prefixed with the word `test`.
The function names are case-insensitive.
Below are some example test function names that would work seamlessly:

::: code-group
```bash [Example]
function test_should_validate_an_ok_exit_code() { ... }
function testRenderAllTestsPassedWhenNotFailedTests { ... }
test_getFunctionsToRun_with_filter_should_return_matching_functions() { ... }
```
:::

::: tip
You're free to use any of Bash's syntax options to define these functions.
:::

## Custom test titles

By default, **bashunit** derives the name shown in reports from the test function name.
If you need a more descriptive title, you can override it inside the test using `set_test_title`:

::: code-group
```bash [Example]
function test_handles_invalid_input() {
  set_test_title "🔥 handles custom test names 🚀"
  # test logic...
}
```
:::

The provided title is used only for display purposes. The original function name is still
used internally, and custom titles are reset automatically after each test.

## `set_up` function

The `set_up` auxiliary function is called, if it is present in the test file, before each test function in the test file is executed.
This provides a hook to prepare the environment or set initial variables specific to each test case.
For example, you might want to create temporary directories or files that your test will manipulate.

::: code-group
```bash [Example]
function set_up() {
  touch temp_file.txt
}
```
:::

## `tear_down` function

The `tear_down` auxiliary function is called, if it is present in the test file, immediately after each test function in the test file is executed.
This auxiliary function offers you a place to clean up any resources allocated or changes made during the `set_up` or test function itself.
This helps to ensure that each test starts with a fresh state.

::: code-group
```bash [Example]
function tear_down() {
  rm temp_file.txt
}
```
:::

## `set_up_before_script` function

The `set_up_before_script` auxiliary function is called, if it is present in the test file, only once before all tests functions in the test file begin.
This is useful for global setup that applies to all test functions in the script, such as loading shared resources.

::: code-group
```bash [Example]
function set_up_before_script() {
  open_database_connection
}
```
:::

## `tear_down_after_script` function

The `tear_down_after_script` auxiliary function is called, if it is present in the test file, only once when all the test functions in the test file have been executed.
This auxiliary function is similar to how `set_up_before_script` works but at the end of the tests.
It provides a hook for any cleanup that should occur after all tests have run, such as deleting temporary files or releasing resources.

::: code-group
```bash [Example]
function tear_down_after_script() {
  close_database_connection
}
```
:::
