# Configuration

Environment configuration to control **bashunit** behavior.

It serves to configure the behavior of bashunit in your project. You need to create a `.env` file in the root directory, but you can give it another name if you pass it as an argument to the command with [`--env` option](/command-line#environment).

Full example with the default values:

```.env
SIMPLE_OUTPUT=false
STOP_ON_FAILURE=false
SHOW_HEADER=true
HEADER_ASCII_ART=false
SHOW_EXECUTION_TIME=true
```

## Simple output

> `SIMPLE_OUTPUT=false`

Similar as using `-s|--simple` option on the [command line](/command-line#output).

Enables simplified output to the console.

Verbose is the default output, but it can be overridden by the environment configuration.

::: code-group
```[Output]
....
```
```env [Example]
SIMPLE_OUTPUT=true
```
:::

::: code-group
```[Output]
Running tests/functional/logic_test.sh
✓ Passed: Other way of using the exit code
✓ Passed: Should validate a non ok exit code
✓ Passed: Should validate an ok exit code
✓ Passed: Text should be equal
```
```env [Example]
SIMPLE_OUTPUT=false
```
:::
## Stop on failure

> `STOP_ON_FAILURE=false`

Similar as using `-S|--stop-on-failure` option on the [command line](/command-line#stop-on-failure).

Force to stop the runner right after encountering one failing test.

## Show header

> `SHOW_HEADER=false`

Specifies if you want to show the bashunit header.

Additionally, you can use the env-var `HEADER_ASCII_ART` to display bashunit in ASCII.

::: code-group
```[Output without header]
✓ Passed: foo bar
```
```env [.env]
SHOW_HEADER=false
```
:::

::: code-group
```[Output with plain header]
bashunit - 0.9.0

✓ Passed: foo bar
```
```env [.env]
SHOW_HEADER=true
```
:::

::: code-group
```[Output with ASCII header]
__               _                   _
| |__   __ _ ___| |__  __ __ ____ (_) |_
| '_ \ / _' / __| '_ \| | | | '_ \| | __|
| |_) | (_| \__ \ | | | |_| | | | | | |_
|_.__/ \__,_|___/_| |_|\___/|_| |_|_|\__|
0.9.0

✓ Passed: foo bar
```
```env [.env]
SHOW_HEADER=true
HEADER_ASCII_ART=true
```
:::

## Show execution time

> `SHOW_EXECUTION_TIME=true|false`

Specifies if you want to display the execution time after running **bashunit**.

> This feature is available only for Linux and Windows.

::: code-group
```[Output with execution time]
✓ Passed: foo bar

Tests:      1 passed, 1 total
Assertions: 3 passed, 3 total
All tests passed
Time taken: 14 ms
```
```env [.env]
SHOW_EXECUTION_TIMEER=true
```
:::

::: code-group
```[Output without execution time]
✓ Passed: foo bar

Tests:      1 passed, 1 total
Assertions: 3 passed, 3 total
All tests passed
```
```env [.env]
SHOW_EXECUTION_TIMEER=false
```
:::
