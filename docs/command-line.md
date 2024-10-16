# Command line

**bashunit** command accepts options to control its behavior. These options will override the environment [configuration](/configuration), which you can use to make the change permanent.

## Directory or file

> `bashunit "directory|file"`

Specifies the `directory` or `file` containing the tests to be run.

If a directory is specified, it will execute tests within files ending in `test.sh`.

If you use wildcards, **bashunit** will run any tests it finds.

You can use `BASHUNIT_DEFAULT_PATH` option in your [configuration](/configuration#default-path)
to choose where the tests are located by default.

::: code-group
```bash [Example]
# all tests inside the tests directory
./bashunit ./tests

# concrete test by full path
./bashunit ./tests/example_test.sh

# all test matching given wildcard
./bashunit ./tests/**/*_test.sh
```
:::

## Assert

> `bashunit -a|--assert function "arg1" "arg2"`

Run a core assert function standalone without a test context. Read more: [Standalone](/standalone)

::: code-group
```bash [Example]
./bashunit --assert equals "foo" "bar"
```
```[Output]
✗ Failed: Main::exec assert
    Expected 'foo'
    but got  'bar'
```
:::

## Bootstrap

> `bashunit -e|--env|--boot "file path"`

Load a custom file, overriding the existing `.env` variables or loading a bootstrap file.

> You can use `BASHUNIT_BOOTSTRAP` option in your [configuration](/configuration#bootstrap).

::: code-group
```bash [Example: --boot]
./bashunit tests --boot tests/globals.sh
```
```bash [Example: --env]
./bashunit tests --env .env.tests
```
:::

## Debug

> `bashunit --debug <?file-path>`

Enables a shell mode in which all executed commands are printed to the terminal,
or printed into a file if this is specified.

Printing every command as executed may help you visualize the script's control flow if it is not working as expected.

::: code-group
```bash [Example]
./bashunit --debug local/debug.sh
```
:::

## Filter

> `bashunit -f|--filter "test name"`

Filters the tests to be run based on the `test name`.

::: code-group
```bash [Example]
# run all test functions including "something" in the name
./bashunit ./tests --filter "something"
```
:::

## JUnit Logging

> `bashunit -l|--log-junit <out.xml>`

Creates a report XML file that follows the JUnit XML format and contains information about the test results of your bashunit tests.

::: code-group
```bash [Example]
./bashunit ./tests --log-junit log-junit.xml
```
```xml [log-junit.xml]
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="bashunit" tests="340"
             passed="328" failures="0" incomplete="10"
             skipped="1" snapshot="1"
             time="43344">
    <testcase file="tests/acceptance/bashunit_direct_fn_call_test.sh"
              name="test_bashunit_direct_fn_call_passes"
              status="passed"
              assertions="1"
              time="45">
    </testcase>
    <testcase file="tests/acceptance/bashunit_direct_fn_call_test.sh"
              name="test_bashunit_direct_fn_call_without_assert_prefix_passes"
              status="passed"
              assertions="1"
              time="51">
    </testcase>
    ... etc
```
:::

## Parallel

> `bashunit -p|--parallel`

bashunit provides an option to run each test in a separate child process, allowing you to parallelize the test execution and potentially speed up the testing process. When running in parallel mode, the execution order of tests is randomized.

::: code-group
```bash [Example]
./bashunit ./tests --parallel
```
:::

This runs the tests in child processes with randomized execution, which may improve overall testing speed, especially for larger test suites.

You can use `BASHUNIT_PARALLEL_RUN` option in your [configuration](/configuration#parallel).

### Disabling Parallel Testing

> `bashunit --no-parallel`

If parallel testing is enabled by default or within a script, you can disable it using the --no-parallel option. This is useful if you need to run tests in sequence or if parallel execution is causing issues during debugging.

## HTML report

> `bashunit -r|--report-html <out.html>`

Creates a report HTML file that contains information about the test results of your bashunit tests.

::: code-group
```bash [Example]
./bashunit ./tests --report-html report.html
```

```html [report.html]
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Test Report</title>
  <style>
    body { font-family: Arial, sans-serif; }
    table { width: 100%; border-collapse: collapse; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
    .passed { background-color: #dff0d8; }
    .failed { background-color: #f2dede; }
    .skipped { background-color: #fcf8e3; }
    .incomplete { background-color: #d9edf7; }
    .snapshot { background-color: #dfe6e9; }
  </style>
</head>
<body>
<h1>Test Report</h1>
<table>
  <thead>
  <tr>
    <th>Total Tests</th>
    <th>Passed</th>
    <th>Failed</th>
    <th>Incomplete</th>
    <th>Skipped</th>
    <th>Snapshot</th>
    <th>Time (ms)</th>
  </tr>
  </thead>
  <tbody>
  <tr>
    <td>340</td>
    <td>328</td>
    <td>0</td>
    <td>10</td>
    <td>1</td>
    <td>1</td>
    <td>46811</td>
  </tr>
  </tbody>
</table>
<p>Time: 46811 ms</p>
<h2>File: tests/acceptance/bashunit_direct_fn_call_test.sh</h2>
<table>
  <thead>
  <tr>
    <th>Test Name</th>
    ... etc
```
:::

## Output

> `bashunit -s|--simple`
>
> `bashunit --detailed` [Default]

Enables simplified or verbose output to the console.

Verbose is the default output, but it can be overridden by the environment configuration.

This command flag will always take precedence over the environment configuration.

You can use `BASHUNIT_SIMPLE_OUTPUT` option in your [configuration](/configuration#output)
to choose the default output display.

::: code-group
```bash [Example]
./bashunit ./tests --simple
```
```[Output]
........
```
:::

::: code-group
```bash [Example]
./bashunit ./tests --detailed
```
```[Output]
Running tests/functional/logic_test.sh
✓ Passed: Other way of using the exit code
✓ Passed: Should validate a non ok exit code
✓ Passed: Should validate an ok exit code
✓ Passed: Text should be equal
✓ Passed: Text should contain
✓ Passed: Text should match a regular expression
✓ Passed: Text should not contain
✓ Passed: Text should not match a regular expression
```
:::

## Stop on failure

> `bashunit -S|--stop-on-failure`

Force to stop the runner right after encountering one failing test.

You can use `BASHUNIT_STOP_ON_FAILURE` option in your [configuration](/configuration#stop-on-failure)
to make this behavior permanent.

::: code-group
```bash [Example]
./bashunit --stop-on-failure
```
:::

## Verbose

> `bashunit -vvv|--verbose`

Display internal details for each test

You can use `BASHUNIT_VERBOSE` option in your [configuration](/configuration#verbose)
to make this behavior permanent.

::: code-group
```bash [Example]
./bashunit --verbose
```
```bash [Output]
bashunit - 0.17.0 | Tests: ~333
########################################################################################################################################
Filter:      None
Total files: 36
Test files:
- tests/acceptance/bashunit_direct_fn_call_test.sh
- tests/acceptance/bashunit_execution_error_test.sh
- tests/acceptance/bashunit_fail_test.sh
- tests/acceptance/bashunit_find_tests_command_line_test.sh
- tests/acceptance/bashunit_log_junit_test.sh
- ... etc
........................................................................................................................................
BASHUNIT_DEFAULT_PATH:        tests
BASHUNIT_DEV_LOG:             dev.log
BASHUNIT_BOOTSTRAP:           tests/bootstrap.sh
BASHUNIT_LOG_JUNIT:           local/log-junit.xml
BASHUNIT_REPORT_HTML:         local/report.html
BASHUNIT_PARALLEL_RUN:        false
BASHUNIT_SHOW_HEADER:         true
BASHUNIT_HEADER_ASCII_ART:    false
BASHUNIT_SIMPLE_OUTPUT:       false
BASHUNIT_STOP_ON_FAILURE:     false
BASHUNIT_SHOW_EXECUTION_TIME: true
BASHUNIT_DEV_MODE:            true
BASHUNIT_VERBOSE:             true
########################################################################################################################################

Running tests/acceptance/bashunit_direct_fn_call_test.sh
========================================================================================================================================
File:     tests/acceptance/bashunit_direct_fn_call_test.sh
Function: test_bashunit_direct_fn_call_passes
Duration: 48 ms
##ASSERTIONS_FAILED=0##ASSERTIONS_PASSED=1##ASSERTIONS_SKIPPED=0##ASSERTIONS_INCOMPLETE=0##ASSERTIONS_SNAPSHOT=0##TEST_OUTPUT=##
----------------------------------------------------------------------------------------------------------------------------------------
✓ Passed: Bashunit direct fn call passes                                                                                           48 ms
========================================================================================================================================
... etc
```
:::

## Version

> `bashunit --version`

Displays the current version of **bashunit**.

::: code-group
```bash [Example]
./bashunit --version
```
```-vue [Output]
bashunit - {{ pkg.version }}
```
:::

## Upgrade

> `bashunit --upgrade`

Upgrade **bashunit** to latest version.

::: code-group
```bash [Example]
./bashunit --upgrade
```
```bash [Output]
> You are already on latest version
```
:::

## Help

> `bashunit --help`

Displays a help message with all allowed arguments and options.

::: code-group
```bash [Example]
./bashunit --help
```
```[Output]
bashunit [arguments] [options]

Arguments:
  Specifies the directory or file containing [...]

Options:
  -f|--filter
    Filters the tests to run based on the test name.

  [...]
```
:::

<script setup>
import pkg from '../package.json'
</script>
