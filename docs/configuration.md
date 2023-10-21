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

> `SIMPLE_OUTPUT=true|false`

Similar as using `-s|--simple` option on the [command line](/command-line#output).


## Stop on failure

> `STOP_ON_FAILURE=true|false`

Similar as using `-S|--stop-on-failure` option on the [command line](/command-line#stop-on-failure).

## Show header

> `SHOW_HEADER=true|false`

Specifies if you want to show the bashunit header.

Additionally, you can use the env-var `HEADER_ASCII_ART` to display bashunit in ASCII.

::: code-group
```env [.env]
SHOW_HEADER=false
```
```bash [Example]
./bashunit ./tests
```
```[Output without header]
✓ Passed: foo bar
```
:::

::: code-group
```env [.env]
SHOW_HEADER=true
```
```bash [Example]
./bashunit ./tests
```
```[Output with simple header]
bashunit - 0.9.0

✓ Passed: foo bar
```
:::

::: code-group
```env [.env]
SHOW_HEADER=true
HEADER_ASCII_ART=true
```
```bash [Example]
./bashunit ./tests
```
```[Output with header ASCII]
__               _                   _
| |__   __ _ ___| |__  __ __ ____ (_) |_
| '_ \ / _' / __| '_ \| | | | '_ \| | __|
| |_) | (_| \__ \ | | | |_| | | | | | |_
|_.__/ \__,_|___/_| |_|\___/|_| |_|_|\__|
0.9.0

✓ Passed: foo bar
```
:::

## Show execution time

> `SHOW_EXECUTION_TIME=true|false`

Specifies if you want to display the execution time after running **bashunit**.

> This feature is available only for Linux and Windows.

::: code-group
```env [.env]
SHOW_EXECUTION_TIMEER=true
```
```bash [Example]
./bashunit ./tests
```
```[Output with execution time]
✓ Passed: foo bar

Tests:      1 passed, 1 total
Assertions: 3 passed, 3 total
All tests passed
Time taken: 14 ms
```
:::

::: code-group
```env [.env]
SHOW_EXECUTION_TIMEER=false
```
```bash [Example]
./bashunit ./tests
```
```[Output without execution time]
✓ Passed: foo bar

Tests:      1 passed, 1 total
Assertions: 3 passed, 3 total
All tests passed
```
:::
