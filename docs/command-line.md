# Command line

**bashunit** uses a subcommand-based CLI. Each command has its own options and behavior.

## Quick Reference

```bash
bashunit test [path] [options]    # Run tests (default)
bashunit bench [path] [options]   # Run benchmarks
bashunit doc [filter]             # Show assertion documentation
bashunit init [dir]               # Initialize test directory
bashunit learn                    # Interactive tutorial
bashunit upgrade                  # Upgrade to latest version
bashunit --help                   # Show help
bashunit --version                # Show version
```

## test

> `bashunit test [path] [options]`
> `bashunit [path] [options]`

Run test files. This is the default command - you can omit `test` for convenience.

::: code-group
```bash [Examples]
# Run all tests in directory
bashunit test tests/

# Shorthand (same as above)
bashunit tests/

# Run specific test file
bashunit test tests/unit/example_test.sh

# Run with filter
bashunit test tests/ --filter "user"

# Run with options
bashunit test tests/ --parallel --simple
```
:::

### Test Options

| Option | Description |
|--------|-------------|
| `-a, --assert <fn> <args>` | Run a standalone assert function |
| `-e, --env, --boot <file>` | Load custom env/bootstrap file |
| `-f, --filter <name>` | Only run tests matching name |
| `--log-junit <file>` | Write JUnit XML report |
| `-p, --parallel` | Run tests in parallel (default) |
| `--no-parallel` | Run tests sequentially |
| `-r, --report-html <file>` | Write HTML report |
| `-R, --run-all` | Run all assertions (don't stop on first failure) |
| `-s, --simple` | Simple output (dots) |
| `--detailed` | Detailed output (default) |
| `-S, --stop-on-failure` | Stop on first failure |
| `--show-skipped` | Show skipped tests summary at end |
| `--show-incomplete` | Show incomplete tests summary at end |
| `-vvv, --verbose` | Show execution details |
| `--debug [file]` | Enable shell debug mode |
| `--no-output` | Suppress all output |
| `--strict` | Enable strict shell mode |
| `--preserve-env` | Skip `.env` loading, use shell environment only |
| `-l, --login` | Run tests in login shell context |

### Standalone Assert

> `bashunit test -a|--assert function "arg1" "arg2"`

Run a core assert function standalone without a test context.

::: code-group
```bash [Example]
bashunit test --assert equals "foo" "bar"
```
```[Output]
✗ Failed: Main::exec assert
    Expected 'foo'
    but got  'bar'
```
:::

### Filter

> `bashunit test -f|--filter "test name"`

Run only tests matching the given name.

::: code-group
```bash [Example]
bashunit test tests/ --filter "user_login"
```
:::

### Inline Filter Syntax

You can also specify a filter directly in the file path using `::` or `:line` syntax:

**Run a specific test by function name:**
> `bashunit test path::function_name`

::: code-group
```bash [Exact match]
bashunit test tests/unit/example_test.sh::test_user_login
```
```bash [Partial match]
# Runs all tests containing "user" in their name
bashunit test tests/unit/example_test.sh::user
```
:::

**Run the test at a specific line number:**
> `bashunit test path:line_number`

This is useful when jumping to a test from your editor or IDE.

::: code-group
```bash [Example]
bashunit test tests/unit/example_test.sh:42
```
:::

::: tip
The line number syntax finds the test function that contains the specified line. If the line is before any test function, an error is shown.
:::

### Parallel

> `bashunit test -p|--parallel`
> `bashunit test --no-parallel`

Run tests in parallel (default) or sequentially.

::: warning
Parallel mode is supported on **macOS**, **Ubuntu**, and **Windows**. On other
systems (like Alpine Linux) the option is automatically disabled due to
inconsistent results.
:::

### Output Style

> `bashunit test -s|--simple`
> `bashunit test --detailed`

Choose between simple (dots) or detailed output.

::: code-group
```bash [Simple]
bashunit test tests/ --simple
```
```[Output]
........
```
:::

::: code-group
```bash [Detailed]
bashunit test tests/ --detailed
```
```[Output]
Running tests/unit/example_test.sh
✓ Passed: Should validate input
✓ Passed: Should handle errors
```
:::

### Reports

Generate test reports in different formats:

::: code-group
```bash [JUnit XML]
bashunit test tests/ --log-junit results.xml
```
```bash [HTML Report]
bashunit test tests/ --report-html report.html
```
:::

### Strict Mode

> `bashunit test --strict`

Enable strict shell mode (`set -euo pipefail`) for test execution.

By default, tests run in permissive mode which allows:
- Unset variables without errors
- Non-zero return codes from commands
- Pipe failures to be ignored

With `--strict`, your tests run with bash strict mode enabled, catching
potential issues like uninitialized variables and unchecked command failures.

::: code-group
```bash [Example]
bashunit test tests/ --strict
```
:::

### Preserve Environment

> `bashunit test --preserve-env`

Skip loading the `.env` file and use the current shell environment only.

By default, bashunit loads variables from `.env` which can override environment
variables set in your shell. Use `--preserve-env` when you want to:
- Run in CI/CD where environment is pre-configured
- Override `.env` values with shell environment variables
- Avoid `.env` interfering with your current settings

::: code-group
```bash [Example]
BASHUNIT_SIMPLE_OUTPUT=true ./bashunit test tests/ --preserve-env
```
:::

### Login Shell

> `bashunit test -l|--login`

Run tests in a login shell context by sourcing profile files.

When enabled, bashunit sources the following files (if they exist) before each test:
- `/etc/profile`
- `~/.bash_profile`
- `~/.bash_login`
- `~/.profile`

Use this when your tests depend on environment setup from login shell profiles, such as:
- PATH modifications
- Shell functions defined in `.bash_profile`
- Environment variables set during login

::: code-group
```bash [Example]
bashunit test tests/ --login
```
:::

## bench

> `bashunit bench [path] [options]`

Run benchmark functions prefixed with `bench_`. Use `@revs` and `@its` comments to control revolutions and iterations.

::: code-group
```bash [Examples]
# Run all benchmarks
bashunit bench

# Run specific benchmark file
bashunit bench benchmarks/parser_bench.sh

# With filter
bashunit bench --filter "parse"
```
:::

### Bench Options

| Option | Description |
|--------|-------------|
| `-e, --env, --boot <file>` | Load custom env/bootstrap file |
| `-f, --filter <name>` | Only run benchmarks matching name |
| `-s, --simple` | Simple output |
| `--detailed` | Detailed output (default) |
| `-vvv, --verbose` | Show execution details |
| `--preserve-env` | Skip `.env` loading, use shell environment only |
| `-l, --login` | Run in login shell context |

## doc

> `bashunit doc [filter]`

Display documentation for assertion functions.

::: code-group
```bash [Examples]
# Show all assertions
bashunit doc

# Filter by name
bashunit doc equals

# Show file-related assertions
bashunit doc file
```
```[Output]
## assert_equals
--------------
> `assert_equals "expected" "actual"`

Reports an error if the two variables are not equal...

## assert_not_equals
--------------
...
```
:::

## init

> `bashunit init [directory]`

Initialize a new test directory with sample files.

::: code-group
```bash [Examples]
# Create tests/ directory (default)
bashunit init

# Create custom directory
bashunit init spec
```
```[Output]
> bashunit initialized in tests
```
:::

Creates:
- `bootstrap.sh` - Setup file for test configuration
- `example_test.sh` - Sample test file to get started

## learn

> `bashunit learn`

Start the interactive learning tutorial with 10 progressive lessons.

::: code-group
```bash [Example]
bashunit learn
```
```[Output]
bashunit - Interactive Learning

Choose a lesson:

  1. Basics - Your First Test
  2. Assertions - Testing Different Conditions
  3. Setup & Teardown - Managing Test Lifecycle
  4. Testing Functions - Unit Testing Patterns
  5. Testing Scripts - Integration Testing
  6. Mocking - Test Doubles and Mocks
  7. Spies - Verifying Function Calls
  8. Data Providers - Parameterized Tests
  9. Exit Codes - Testing Success and Failure
  10. Complete Challenge - Real World Scenario

  p. Show Progress
  r. Reset Progress
  q. Quit

Enter your choice:
```
:::

::: tip
Perfect for new users getting started with bashunit.
:::

## upgrade

> `bashunit upgrade`

Upgrade bashunit to the latest version.

::: code-group
```bash [Example]
bashunit upgrade
```
```[Output]
> Upgrading bashunit to latest version
> bashunit upgraded successfully to latest version 0.28.0
```
:::

## Global Options

These options work without a subcommand:

### Version

> `bashunit --version`

Display the current version.

::: code-group
```bash [Example]
bashunit --version
```
```-vue [Output]
bashunit - {{ pkg.version }}
```
:::

### Help

> `bashunit --help`

Display help message with available commands.

::: code-group
```bash [Example]
bashunit --help
```
```[Output]
Usage: bashunit <command> [arguments] [options]

Commands:
  test [path]       Run tests (default command)
  bench [path]      Run benchmarks
  doc [filter]      Display assertion documentation
  init [dir]        Initialize a new test directory
  learn             Start interactive tutorial
  upgrade           Upgrade bashunit to latest version

Global Options:
  -h, --help        Show this help message
  -v, --version     Display the current version

Run 'bashunit <command> --help' for command-specific options.
```
:::

Each subcommand also supports `--help`:

```bash
bashunit test --help
bashunit bench --help
bashunit doc --help
```

<script setup>
import pkg from '../package.json'
</script>
