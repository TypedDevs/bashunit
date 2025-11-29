# Data providers

**bashunit** offers a way to parameterize your test functions with data providers.
Ideal when you want to execute the same test function multiple times, each with a different set of arguments.

## Defining a data provider

You can add a special comment `@data_provider` before a test function to specify an auxiliary function. This function controls how many times the test will run and what arguments it will receive.

A data provider function is specified as follows:

> **Note**: The previous `# data_provider` syntax is still supported but
> deprecated. Prefer using the `@` prefix going forward.

::: code-group
```bash [Example]
# @data_provider provider_function
function test_my_test_case() {
  ...
}
```
:::

## Implementing a data provider

A data provider function contains one or more `data_set` lines. Each `data_set` results in a separate run of the test function with the individual `data_set` arguments being passed to it as positional arguments (`$1`, `$2`, ...).

Each run is treated as a separate test, so it can pass or fail independently. Plus, [set_up](/test-files#set-up-function) and [tear_down](/test-files#tear-down-function) are called before and after each run. This reduces code repetition and helps create related tests more efficiently.

A data provider function is implemented as follows:

::: code-group
```bash [Example]
function provider_function() {
  data_set "one"
  data_set "two" "three"
  data_set "value containing spaces"
  data_set "" "first value is empty"
}

```
:::

> **Note**: The previous variant of using `echo` to define data within a data provider
> provider is still supported but deprecated, as it does not support empty values or
> values containing spaces. Prefer using the `data_set` function going forward.

## Interpolating arguments in test names

You can reference the values provided by a data provider directly in the test
function name using placeholders like `::1::`, `::2::`, ... matching the
argument position.

::: code-group
```bash [example_test.sh]
# @data_provider fizz_numbers
function test_returns_fizz_when_multiple_of_::1::_like_::2::_given() {
  # ...
}

function fizz_numbers() {
  data_set 3 4
  data_set 3 6
}
```
```[Output]
Running example_test.sh
✓ Passed: Returns fizz when multiple of '3' like '4' given
✓ Passed: Returns fizz when multiple of '3' like '6' given
```
:::

## Multiple args in one call

::: code-group
```bash [example_test.sh]
# @data_provider provider_directories
function test_directories_exists() {
  local dir1=$1
  local dir2=$2
  local dir3=$3

  assert_directory_exists "$dir1"
  assert_directory_exists "$dir2"
  assert_directory_exists "$dir3"
}

function provider_directories() {
  data_set "/usr" "/etc" "/var"
}
```
```[Output]
Running example_test.sh
✓ Passed: Directories exists ('/usr', '/etc', '/var')
```
:::

## Single arg in multiple calls

::: code-group
```bash [example_test.sh]
# @data_provider provider_directories
function test_directory_exists() {
  local directory=$1

  assert_directory_exists "$directory"
}

function provider_directories() {
  data_set "/usr"
  data_set "/etc"
  data_set "/var"
}
```
```[Output]
Running example_test.sh
✓ Passed: Directory exists ('/usr')
✓ Passed: Directory exists ('/etc')
✓ Passed: Directory exists ('/var')
```
:::

## Multiple args in multiple calls

::: code-group
```bash [example_test.sh]
# @data_provider provider_directories
function test_directory_exists() {
  local outro=$1
  local directory=$2

  assert_equals "outro" "$outro"
  assert_directory_exists "$directory"
}

function provider_directories() {
  data_set "outro" "/usr"
  data_set "outro" "/etc"
  data_set "outro" "/var"
}
```
```[Output]
Running example_test.sh
✓ Passed: Directory exists ('outro', '/usr')
✓ Passed: Directory exists ('outro', '/etc')
✓ Passed: Directory exists ('outro', '/var')
```
:::
