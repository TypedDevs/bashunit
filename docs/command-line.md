# Command line

**bashunit** command accepts options to control its behavior. These options will override the environment [configuration](/configuration), which you can use to make the change permanent.

## Directory or file

> `bashunit "directory|file"`

Specifies the `directory` or `file` containing the tests to be run.

If a directory is specified, it will execute tests within files ending in `test.sh`.

If you use wildcards, **bashunit** will run any tests it finds.

You can use `DEFAULT_PATH` option in your [configuration](/configuration#default-path)
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

## Filter

> `bashunit -f|--filter "test name"`

Filters the tests to be run based on the `test name`.

::: code-group
```bash [Example]
# run all test functions including "something" in it's name
./bashunit ./tests --filter "something"
```
:::

## Output

> `bashunit -s|--simple`
>
> `bashunit -v|--verbose`

Enables simplified or verbose output to the console.

Verbose is the default output, but it can be overridden by the environment configuration.

This command flag will always take precedence over the environment configuration.

You can use `SIMPLE_OUTPUT` option in your [configuration](/configuration#output)
to choose the default output display.

::: code-group
```[Output]
........
```
```bash [Example]
./bashunit ./tests --simple
```
:::

::: code-group
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
```bash [Example]
./bashunit ./tests --verbose
```
:::

## Stop on failure

> `bashunit -S|--stop-on-failure`

Force to stop the runner right after encountering one failing test.

You can use `STOP_ON_FAILURE` option in your [configuration](/configuration#stop-on-failure)
to make this behavior permanent.

::: code-group
```bash [Example]
./bashunit --stop-on-failure
```
:::

## Environment

> `bashunit --env "file path"`

Load a custom env file overriding the `.env` environment variables.

::: code-group
```bash [Example]
./bashunit tests --env .env.production
```
:::

## Version

> `bashunit --version`

Displays the current version of **bashunit**.

::: code-group
```-vue [Output]
bashunit - {{ pkg.version }}
```
```bash [Example]
./bashunit --version
```
:::

## Help

> `bashunit --help`

Displays a help message with all allowed arguments and options.

::: code-group
```-vue [Output]
bashunit [arguments] [options]

Arguments:
  Specifies the directory or file containing [...]

Options:
  -f|--filer
    Filters the tests to run based on the test name.

  [...]
```
```bash [Example]
./bashunit --help
```
:::

<script setup>
import pkg from '../package.json'
</script>
