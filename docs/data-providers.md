---
description: "Use bashunit data providers to run one test with multiple input sets, keeping bash tests concise, parameterized and easy to maintain."
---

# Data providers

Data providers run the same test function with different sets of arguments.

## Defining a data provider

Add a `@data_provider` comment before a test function to name its provider. The provider supplies the argument sets and determines how many times the test runs:

> **Note**: The previous `# data_provider` syntax is still supported but
> deprecated. Use the `@` prefix.

::: code-group
```bash [Example]
# @data_provider provider_function
function test_my_test_case() {
  ...
}
```
:::

The annotation must sit within **two lines** of the function definition. A `# @tag` line or
a one-line docstring in between is fine; anything longer and bashunit stops seeing the
annotation, and the test runs once with no arguments instead of reporting an error.

## Implementing a data provider

Call `bashunit::data_set` for each set of inputs. Each call runs the test once, passing those inputs as positional arguments (`$1`, `$2`, ...).

Each run passes or fails independently, with [set_up](/test-files#set-up-function) before it and [tear_down](/test-files#tear-down-function) after it.

Under `--parallel` every row is dispatched as its own concurrent job, so rows sharing a
file, a temp path or an environment variable will race. Serialise them with the
`# bashunit: no-parallel-tests` directive at the top of the file (see
[Parallel](/command-line#parallel)), or give each row its own scratch path with
`bashunit::temp_file`.

The annotation must be in the test file, but the provider function only has to be defined
by the time the run starts. Put shared providers in your bootstrap file (`--boot` or
`BASHUNIT_BOOTSTRAP`) and reference them by name from any test file:

::: code-group
```bash [tests/bootstrap.sh]
function provider_supported_shells() {
  bashunit::data_set "bash"
  bashunit::data_set "zsh"
}
```
```bash [tests/any_test.sh]
# @data_provider provider_supported_shells
function test_shell_is_available() {
  assert_command_available "$1"
}
```
:::

::: warning A provider with no rows makes its test disappear
A provider that does not exist, or that emits no `bashunit::data_set` line, makes its test
run **zero** times, and bashunit does not error: the header still counts the test, nothing
runs, and the suite stays green. Compare the header count with the reported total (`Tests: 2`
in the header but `1 total` at the bottom means a provider produced no rows), or check the
selection with `./bashunit --list <file>`.
:::

For example:

::: code-group
```bash [Example]
function provider_function() {
  bashunit::data_set "one"
  bashunit::data_set "two" "three"
  bashunit::data_set "value containing spaces"
  bashunit::data_set "" "first value is empty"
}

```
:::

> **Note**: The previous variant of using `echo` to define data within a data
> provider is still supported but deprecated, as it does not support empty values or
> values containing spaces. Use `bashunit::data_set` instead.

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
  bashunit::data_set 3 4
  bashunit::data_set 3 6
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
  bashunit::data_set "/usr" "/etc" "/var"
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
  bashunit::data_set "/usr"
  bashunit::data_set "/etc"
  bashunit::data_set "/var"
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
  bashunit::data_set "outro" "/usr"
  bashunit::data_set "outro" "/etc"
  bashunit::data_set "outro" "/var"
}
```
```[Output]
Running example_test.sh
✓ Passed: Directory exists ('outro', '/usr')
✓ Passed: Directory exists ('outro', '/etc')
✓ Passed: Directory exists ('outro', '/var')
```
:::

## Failing rows

A failing row's result line is labelled with the test name only: the arguments are **not**
appended the way they are on a passing row.

```[Output]
✓ Passed: Directory exists ('/usr')
✓ Passed: Directory exists ('/etc')
✗ Failed: Directory exists
    Expected '/nope'
    to exist but 'do not exist'
    at example_test.sh:5
```

Identify the row from the `Expected` value, or use `::1::` interpolation in the test title,
which does put the arguments in the name.

## Combining with other options

| Option | Effect on a provider |
|--------|----------------------|
| `--repeat <n>` | Every row runs n times; each row still reports one line |
| `--retry <n>` | Only the failing row is retried |
| `# @tag` / `--tag` | Tags belong to the test function, so they select all its rows |
| `--filter` | Matches the **function name**, not the interpolated title: `--filter directory_exists`, not `--filter "Directory exists"` |
| `--list` | Lists the function once; the row count is a property of the run (see [Command line](/command-line#list)) |

## Related

- [Test files](/test-files) — `set_up` and `tear_down` lifecycle hooks
- [Assertions](/assertions) — the built-in assertion reference
- [Common patterns](/common-patterns) — real-world testing patterns
