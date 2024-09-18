# Configuration

Environment configuration to control **bashunit** behavior.

It serves to configure the behavior of bashunit in your project.
You need to create a `.env` file in the root directory,
but you can give it another name if you pass it as an argument to the command with
`--env` [option](/command-line#environment).

## Default path

> `BASHUNIT_DEFAULT_PATH=directory|file`

Specifies the `directory` or `file` containing the tests to be run. `empty` by default.

If a directory is specified, it will execute tests within files ending in `test.sh`.

If you use wildcards, **bashunit** will run any tests it finds.

::: code-group
```bash [Example]
# all tests inside the tests directory
BASHUNIT_DEFAULT_PATH=tests

# concrete test by full path
BASHUNIT_DEFAULT_PATH=tests/example_test.sh

# all test matching given wildcard
BASHUNIT_DEFAULT_PATH=tests/**/*_test.sh
```
:::

## Output

> `BASHUNIT_SIMPLE_OUTPUT=true|false`

Enables simplified output to the console. `false` by default.

Verbose is the default output, but it can be overridden by the environment configuration.

Similar as using `-s|--simple | -vvv|--verbose` option on the [command line](/command-line#output).

::: code-group
```bash [Simple output]
....
```
```bash [.env]
BASHUNIT_SIMPLE_OUTPUT=true
```
:::

::: code-group
```[Verbose output]
Running tests/functional/logic_test.sh
✓ Passed: Other way of using the exit code
✓ Passed: Should validate a non ok exit code
✓ Passed: Should validate an ok exit code
✓ Passed: Text should be equal
```
```bash [.env]
BASHUNIT_SIMPLE_OUTPUT=false
```
:::

## Stop on failure

> `BASHUNIT_STOP_ON_FAILURE=true|false`

Force to stop the runner right after encountering one failing test. `false` by default.

Similar as using `-S|--stop-on-failure` option on the [command line](/command-line#stop-on-failure).

## Show header

> `BASHUNIT_SHOW_HEADER=true|false`
>
> `BASHUNIT_HEADER_ASCII_ART=true|false`

Specify if you want to show the bashunit header. `true` by default.

Additionally, you can use the env-var `BASHUNIT_HEADER_ASCII_ART` to display bashunit in ASCII. `false` by default.

::: code-group
``` [Without header]
✓ Passed: foo bar
```
```bash [.env]
BASHUNIT_SHOW_HEADER=false
```
:::

::: code-group
```-vue [Plain header]
bashunit - {{ pkg.version }} // [!code hl]

✓ Passed: foo bar
```
```bash [.env]
BASHUNIT_SHOW_HEADER=true
```
:::

::: code-group
```-vue [ASCII header]
__               _                   _    // [!code hl]
| |__   __ _ ___| |__  __ __ ____ (_) |_  // [!code hl]
| '_ \ / _' / __| '_ \| | | | '_ \| | __| // [!code hl]
| |_) | (_| \__ \ | | | |_| | | | | | |_  // [!code hl]
|_.__/ \__,_|___/_| |_|\___/|_| |_|_|\__| // [!code hl]
{{ pkg.version }} // [!code hl]

✓ Passed: foo bar
```
```bash [.env]
BASHUNIT_SHOW_HEADER=true
BASHUNIT_HEADER_ASCII_ART=true
```
:::

## Show execution time

> `BASHUNIT_SHOW_EXECUTION_TIME=true|false`

Specify if you want to display the execution time after running **bashunit**. `true` by default.

::: code-group
```-vue [With execution time]
✓ Passed: foo bar

Tests:      1 passed, 1 total
Assertions: 3 passed, 3 total
All tests passed
Time taken: 14 ms  // [!code hl]
```
```bash [.env]
BASHUNIT_SHOW_EXECUTION_TIME=true
```
:::

::: code-group
```[Without execution time]
✓ Passed: foo bar

Tests:      1 passed, 1 total
Assertions: 3 passed, 3 total
All tests passed
```
```bash [.env]
BASHUNIT_SHOW_EXECUTION_TIME=false
```
:::

## Log JUnit

> `BASHUNIT_LOG_JUNIT=file`

Create a report XML file that follows the JUnit XML format and contains information about the test results of your bashunit tests.

::: code-group
```bash [Example]
BASHUNIT_LOG_JUNIT=log-junit.xml
```
:::

## Report HTML

> `BASHUNIT_REPORT_HTML=file`

Create a report HTML file that contains information about the test results of your bashunit tests.

::: code-group
```bash [Example]
BASHUNIT_REPORT_HTML=report.html
```
:::

## Load file

> `BASHUNIT_LOAD_FILE=file`

Specifies an additional file to be loaded for all tests cases.
Useful to set up global variables or functions accessible in all your tests.

Similarly, you can use load an additional file via the [command line](/command-line#environment).

::: code-group
```bash [Example]
# a simple .env file
BASHUNIT_LOAD_FILE=".env.tests"

# or a complete script file
BASHUNIT_LOAD_FILE="tests/globals.sh"
```
:::

<script setup>
import pkg from '../package.json'
</script>
