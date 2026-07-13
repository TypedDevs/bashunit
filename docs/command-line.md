---
description: "bashunit command-line reference: every CLI flag and option to run, filter, parallelize, and report your bash tests from the terminal."
---

# Command line

**bashunit** uses a subcommand-based CLI. Each command has its own options and behavior.

## Quick Reference

```bash
bashunit test [path] [options]    # Run tests (default)
bashunit bench [path] [options]   # Run benchmarks
bashunit watch [path] [options]   # Watch files, re-run tests on change
bashunit assert <fn> <args>       # Run standalone assertion
bashunit doc [filter]             # Show assertion documentation
bashunit init [dir]               # Initialize test directory
bashunit learn                    # Interactive tutorial
bashunit upgrade                  # Upgrade to latest version
bashunit --help                   # Show help
bashunit --version                # Show version
```

## Argument Notation

| Syntax   | Meaning                                  |
|----------|------------------------------------------|
| `<arg>`  | Required - must be provided              |
| `[arg]`  | Optional - can be omitted (uses default) |

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

| Option                         | Description                                      |
|--------------------------------|--------------------------------------------------|
| `-a, --assert <fn> <args>`     | Run a standalone assert function                 |
| `-e, --env, --boot <file>`     | Load custom env/bootstrap file (supports args)   |
| `-f, --filter <name>`          | Only run tests matching name                     |
| `--tag <name>`                 | Only run tests with matching `@tag` (repeatable) |
| `--exclude-tag <name>`         | Skip tests with matching `@tag` (repeatable)     |
| `--output <format>`            | Output format (`tap` for TAP version 13)         |
| `-w, --watch`                  | Watch files and re-run tests on change           |
| `--log-junit, --report-junit <file>` | Write JUnit XML report                     |
| `--log-gha <file>`             | Write GitHub Actions workflow-commands log       |
| `-j, --jobs <N\|auto>`         | Run tests in parallel with max N concurrent jobs (`auto` = CPU cores) |
| `-p, --parallel`               | Run tests in parallel                            |
| `--no-parallel`                | Run tests sequentially                           |
| `-r, --report-html <file>`     | Write HTML report                                |
| `--report-tap <file>`          | Write TAP version 13 report to a file            |
| `--report-json <file>`         | Write machine-readable JSON report to a file     |
| `-R, --run-all`                | Run all assertions (don't stop on first failure) |
| `-s, --simple`                 | Simple output (dots)                             |
| `--detailed`                   | Detailed output (default)                        |
| `-S, --stop-on-failure`        | Stop on first failure                            |
| `--test-timeout <seconds>`     | Fail a test if it runs longer than N seconds     |
| `--retry <n>`                  | Re-run a failed test up to N extra times         |
| `--random-order`               | Randomize test execution order                   |
| `--seed <n>`                   | Seed for `--random-order` (reproducible shuffle) |
| `--shard <i>/<n>`              | Run shard i of n (split suite across runners)    |
| `--rerun-failed`               | Replay only the tests that failed on the last run |
| `--show-skipped`               | Show skipped tests summary at end                |
| `--show-incomplete`            | Show incomplete tests summary at end             |
| `-vvv, --verbose`              | Show execution details                           |
| `--debug [file]`               | Enable shell debug mode                          |
| `--no-output`                  | Suppress all output                              |
| `--failures-only`              | Only show failures                               |
| `--fail-on-risky`              | Treat risky tests (no assertions) as failures    |
| `--profile`                    | Report the slowest tests after a run             |
| `--no-progress`                | Suppress real-time progress, show only summary   |
| `--show-output`                | Show test output on failure (default)            |
| `--no-output-on-failure`       | Hide test output on failure                      |
| `--strict`                     | Enable strict shell mode                         |
| `--skip-env-file`              | Skip `.env` loading, use shell environment only  |
| `-l, --login`                  | Run tests in login shell context                 |
| `--no-color`                   | Disable colored output                           |
| `--coverage`                   | Enable code coverage tracking                    |
| `--coverage-paths <paths>`     | Paths to track (default: auto-discover)          |
| `--coverage-exclude <pat>`     | Exclusion patterns                               |
| `--coverage-report [file]`     | LCOV output path (default: `coverage/lcov.info`) |
| `--coverage-report-html [dir]` | Generate HTML report (default: `coverage/html`)  |
| `--coverage-min <percent>`     | Minimum coverage threshold                       |
| `--no-coverage-report`         | Console output only, no LCOV file                |

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

### Tags

> `bashunit test --tag <name>`
> `bashunit test --exclude-tag <name>`

Filter tests by `# @tag` annotations. Both flags are repeatable. `--tag` uses OR
logic across names; `--exclude-tag` wins when a test matches both.

::: code-group
```bash [Annotate tests]
# @tag slow
function test_heavy_computation() {
  ...
}

# @tag integration
function test_api_call() {
  ...
}
```
```bash [Run by tag]
bashunit test tests/ --tag slow
bashunit test tests/ --tag slow --tag integration
bashunit test tests/ --exclude-tag integration
```
:::

### Output format

> `bashunit test --output <format>`

Select an alternative output format. Currently supported:

- `tap` — [TAP version 13](https://testanything.org/tap-version-13-specification.html) for CI/CD integrations.

The `TAP version 13` header comes first, each test file is announced via a
`# <path>` diagnostic line, each test emits an `ok <n> - <name>` or
`not ok <n> - <name>` line (failures include a YAML `--- ... ...` block with
expected/actual), and the `1..N` plan line closes the report.

::: code-group
```bash [Example]
bashunit test tests/ --output tap
```
```[Output]
TAP version 13
# tests/example_test.sh
ok 1 - Should validate input
not ok 2 - Should handle errors
  ---
  Expected 'foo'
  but got  'bar'
  ...

1..2
```
:::

### Watch mode

> `bashunit test -w|--watch`

Watch the test path (plus `src/` if present) and re-run tests when files change.
The `-w`/`--watch` flag uses a lightweight **checksum polling loop** that works
on any system — no external tools required.

::: code-group
```bash [Example]
bashunit test tests/ --watch
```
:::

::: tip
For file-event-driven watching (no polling), use the dedicated
[`watch`](#watch) subcommand, which relies on `inotifywait` (Linux) or
`fswatch` (macOS).
:::

### Environment / Bootstrap

> `bashunit test -e|--env|--boot <file>`
> `bashunit test --env "file arg1 arg2"`

Load a custom environment or bootstrap file before running tests.

::: code-group
```bash [Basic usage]
bashunit test --env tests/bootstrap.sh tests/
```
```bash [With arguments]
# Pass arguments to the bootstrap file
bashunit test --env "tests/bootstrap.sh staging verbose" tests/
```
:::

Arguments are available as positional parameters (`$1`, `$2`, etc.) in your bootstrap script:

```bash
#!/usr/bin/env bash
# tests/bootstrap.sh
ENVIRONMENT="${1:-production}"
VERBOSE="${2:-false}"

export API_URL="https://${ENVIRONMENT}.api.example.com"
```

You can also set arguments via environment variable:

```bash
BASHUNIT_BOOTSTRAP_ARGS="staging verbose" bashunit test tests/
```

See [Configuration: Bootstrap](/configuration#bootstrap) for more details.

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

Run tests in parallel or sequentially. Sequential is the default.

In parallel mode, both test files and individual test functions run concurrently
for maximum performance.

::: warning
Parallel mode is supported on **macOS**, **Ubuntu**, **Alpine**, and **Windows**.
On other systems the option is automatically disabled due to inconsistent results.
:::

::: tip Opt-out of test-level parallelism
If a test file has shared state or race conditions, you can disable test-level
parallelism by adding this directive as the second line:

```bash
#!/usr/bin/env bash
# bashunit: no-parallel-tests

function test_with_shared_state() {
  # This test will not run in parallel with others in this file
}
```

The file will still run in parallel with other files, but tests within it will
run sequentially.
:::

### Jobs

> `bashunit test -j|--jobs <N|auto>`

Run tests in parallel with a maximum of N concurrent jobs. This implicitly
enables parallel mode.

Use this to limit CPU usage on CI or machines with constrained resources.
Pass `auto` to cap concurrency at the number of detected CPU cores.

::: code-group
```bash [Example]
bashunit test tests/ --jobs 4
bashunit test tests/ --jobs auto
```
:::

::: tip
`--jobs 0` (the default) means unlimited concurrency, which is equivalent to
`--parallel`. `--jobs auto` caps at the detected CPU core count.
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
```bash [GitHub Actions]
# Stream annotations straight to the runner log:
bashunit test tests/ --log-gha /dev/stdout
```
```bash [JSON]
bashunit test tests/ --report-json report.json
```
:::

The `--log-gha` flag writes GitHub Actions workflow commands (`::error`, `::warning`, `::notice`) for failed, risky and incomplete tests, including the failing test's `file` and `line`. Point it at `/dev/stdout` (or stream a log file to stdout) on a runner and the failures appear as inline annotations in the "Files changed" tab of a pull request.

The `--report-json` flag writes machine-readable results for scripts, dashboards and bots. Strings are escaped in pure Bash, so no `jq` is needed to produce it. Its schema is:

```json
{
  "summary": { "total": 3, "passed": 2, "failed": 1, "skipped": 0, "incomplete": 0, "duration_ms": 42 },
  "tests": [
    { "file": "tests/math_test.sh", "name": "it adds", "status": "passed", "duration_ms": 5, "message": "" },
    { "file": "tests/math_test.sh", "name": "it divides", "status": "failed", "duration_ms": 3, "message": "Expected 2 but got 3" }
  ]
}
```

`status` is one of `passed`, `failed`, `skipped`, `incomplete` (`snapshot` and `risky` are also emitted per test and counted as passed in the summary). Like the other file reporters, per-test rows come from a sequential run; under `--parallel` the file is still valid JSON.

### Show Output on Failure

> `bashunit test --show-output`
> `bashunit test --no-output-on-failure`

Control whether test output (stdout/stderr) is displayed when tests fail with runtime errors or assertion failures.

By default (`--show-output`), when a test fails due to a runtime error (command not found,
unbound variable, permission denied, etc.) or a failed assertion after the test printed
diagnostics, bashunit displays the captured output in an "Output:" section to help debug
the failure.

Use `--no-output-on-failure` to suppress this output.

::: code-group
```bash [Example]
bashunit test tests/ --no-output-on-failure
```
```[Output with --show-output (default)]
✗ Error: My test function
    command not found
    Output:
      Debug: Setting up test
      Running command: my_command
      /path/to/test.sh: line 5: my_command: command not found
```
:::

### Profile

> `bashunit test --profile`

Report the slowest tests after a run. Each test's wall-clock duration is recorded
and, once the run finishes, the slowest ones are printed sorted from slowest to
fastest. Works in both sequential and parallel mode.

The number of entries shown defaults to `10` and can be changed with the
`BASHUNIT_PROFILE_COUNT` environment variable.

::: code-group
```bash [Example]
bashunit test tests/ --profile
```
```[Output]
Tests:      10 passed, 10 total
Assertions: 25 passed, 25 total

 All tests passed

Slowest tests:
  1.20s  test_slow_database_query (tests/integration_test.sh)
  340ms  test_http_client_timeout (tests/http_test.sh)
  12ms   test_parse_config (tests/unit/config_test.sh)
Time taken: 1.60s
```
```bash [Custom count]
BASHUNIT_PROFILE_COUNT=3 bashunit test tests/ --profile
```
:::

### Test Timeout

> `bashunit test --test-timeout <seconds>`

Abort an individual test if it runs longer than the given number of seconds and
report it as a failure, then continue with the remaining tests. This protects a
run from hanging forever on a blocked test — for example a mock that was never
given an implementation and waits on input that never arrives.

The timeout is **disabled by default** (`0`). It applies per test (set up and
tear down included) and is expressed in whole seconds. It needs no external
`timeout` command and works on Bash 3.2+ (including the default macOS Bash).

::: code-group
```bash [Example]
bashunit test tests/ --test-timeout 5
```
```[Output]
✗ Error: Test hangs forever
    Test timed out after 5s

Tests:      1 passed, 1 failed, 2 total
```
:::

It can also be set via the `BASHUNIT_TEST_TIMEOUT` environment variable (see
[configuration](/configuration#test-timeout)).

### Retry

> `bashunit test --retry <n>`

Re-run a **failed** test up to `n` extra times and report it as passed if any
attempt passes; it only fails once every attempt has failed. This mitigates
flaky tests (timing, network or filesystem races) in CI without hiding a test
that is consistently broken.

Retry is **disabled by default** (`0`). A test that recovered on retry is
annotated so the flakiness stays visible, retries apply per test, and it works
together with `--parallel` and `--stop-on-failure` (a test that recovers on
retry does not trigger stop-on-failure).

::: code-group
```bash [Example]
bashunit test tests/ --retry 2
```
```[Output]
✓ Passed: A flaky test (retry 1/2)

Tests:      1 passed, 1 total
```
:::

It can also be set via the `BASHUNIT_RETRY` environment variable (see
[configuration](/configuration#retry)).

### Random order

> `bashunit test --random-order [--seed <n>]`

Randomize the order in which test files and the tests within each file run, to
surface hidden inter-test coupling (leaked globals, shared temp files, ordering
dependencies). Disabled by default.

When enabled and no `--seed` is given, a seed is generated and printed in the
run header so a failing run can be replayed exactly with `--seed <n>`. The same
seed always produces the same order, and it composes with `--parallel`. `--seed`
on its own (without `--random-order`) has no effect.

::: code-group
```bash [Example]
bashunit test tests/ --random-order
```
```[Output]
Randomized with seed: 12345

# replay the exact same order:
bashunit test tests/ --random-order --seed 12345
```
:::

It can also be set via the `BASHUNIT_SEED` environment variable (see
[configuration](/configuration#random-order)).

### Shard

> `bashunit test --shard <index>/<total>`

Run a deterministic subset (shard) of the test files, so a large suite can be
split across parallel CI machines. `index` is 1-based (`1 <= index <= total`);
invalid input exits non-zero with an error. Files are assigned round-robin, so
the union of all shards is the full suite with no overlap. Composes with
`--parallel` (shard first on each runner, then parallelize the slice).

::: code-group
```bash [Split across 4 runners]
bashunit test tests/ --shard 1/4
bashunit test tests/ --shard 2/4
bashunit test tests/ --shard 3/4
bashunit test tests/ --shard 4/4
```
```yaml [GitHub Actions matrix]
strategy:
  matrix:
    shard: [1, 2, 3, 4]
steps:
  - run: ./bashunit tests/ --shard ${{ matrix.shard }}/4
```
:::

### Rerun failed

> `bashunit test --rerun-failed`

Replay only the tests that failed on the **previous** run — the fastest
edit-run loop after a red suite.

Every run records its failing tests as `<test_file>:<function_name>` lines in
`.bashunit/last-failed` under the working directory (one write at the end of a
run, so a plain `fail`, then `--rerun-failed` works without planning ahead). A
fully green run clears the cache. With `--rerun-failed`, discovery is restricted
to the recorded files and each file is filtered to the recorded functions; if
the cache is missing or empty, bashunit prints a short notice and runs the full
suite.

Add `.bashunit/` to your `.gitignore`:

```bash [.gitignore]
.bashunit/
```

Notes:

- Works with `--parallel` (same cache format).
- Composes with `--filter`/`--tag` — both filters apply (intersection).
- Data-provider tests record the base function name once; replaying runs all its
  data rows.
- Entries pointing at deleted files or functions are skipped, not fatal.

::: code-group
```bash [Rerun only what just failed]
bashunit test tests/            # some tests fail
bashunit test --rerun-failed    # replay just those
```
```bash [Env variable]
BASHUNIT_RERUN_FAILED=true bashunit test tests/
```
:::

### No Progress

> `bashunit test --no-progress`

Suppress real-time progress display during test execution, showing only the final summary.

When enabled, bashunit hides:
- Per-test output (pass/fail messages or dots)
- File headers ("Running tests/...")
- Hook completion messages
- Spinner during parallel execution

The final summary with test counts and results is still displayed.

This is useful for:
- CI/CD pipelines where streaming output causes issues
- Log-restricted environments
- Reducing output noise when only the final result matters

::: code-group
```bash [Example]
bashunit test tests/ --no-progress
```
```[Output]
bashunit - 0.34.1 | Tests: 10
Tests:      10 passed, 10 total
Assertions: 25 passed, 25 total

 All tests passed
Time taken: 1.23s
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

### Skip Env File

> `bashunit test --skip-env-file`

Skip loading the `.env` file and use the current shell environment only.

By default, bashunit loads variables from `.env` which can override environment
variables set in your shell. Use `--skip-env-file` when you want to:
- Run in CI/CD where environment is pre-configured
- Override `.env` values with shell environment variables
- Avoid `.env` interfering with your current settings

::: warning Important
Only environment variables are inherited from the parent shell. Shell functions
and aliases are NOT available in tests due to bashunit's subshell architecture.
Use a [bootstrap file](/configuration#bootstrap) to define functions needed by your tests.
:::

::: code-group
```bash [Example]
BASHUNIT_SIMPLE_OUTPUT=true ./bashunit test tests/ --skip-env-file
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

### Coverage

> `bashunit test --coverage`

Enable code coverage tracking for your tests. See the [Coverage](/coverage) documentation for comprehensive details.

::: code-group
```bash [Basic usage]
bashunit test tests/ --coverage
```
```bash [With options]
bashunit test tests/ --coverage --coverage-paths src/,lib/ --coverage-min 80
```
:::

**Coverage options:**

| Option                          | Description                                                                 |
|---------------------------------|-----------------------------------------------------------------------------|
| `--coverage`                    | Enable coverage tracking                                                    |
| `--coverage-paths <paths>`      | Comma-separated paths to track (default: auto-discover from test files)     |
| `--coverage-exclude <patterns>` | Comma-separated patterns to exclude (default: `tests/*,vendor/*,*_test.sh`) |
| `--coverage-report [file]`      | LCOV output file path (default: `coverage/lcov.info`)                       |
| `--coverage-report-html [dir]`  | Generate HTML report (default: `coverage/html`)                             |
| `--coverage-min <percent>`      | Minimum coverage percentage; fails if below                                 |
| `--no-coverage-report`          | Show console report only, don't generate LCOV file                          |

::: tip
Coverage works with parallel execution (`-p`). Each worker tracks coverage independently, and results are aggregated before reporting.
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
| `-e, --env, --boot <file>` | Load custom env/bootstrap file (supports args) |
| `-f, --filter <name>` | Only run benchmarks matching name |
| `-s, --simple` | Simple output |
| `--detailed` | Detailed output (default) |
| `-vvv, --verbose` | Show execution details |
| `--skip-env-file` | Skip `.env` loading, use shell environment only |
| `-l, --login` | Run in login shell context |

## watch

> `bashunit watch [path] [test-options]`

Dedicated watch subcommand that uses **OS file-event notifications** (no
polling) to re-run tests as soon as a `.sh` file changes. Any option accepted
by `bashunit test` is also accepted here.

::: code-group
```bash [Examples]
# Watch current directory
bashunit watch

# Watch the tests/ directory
bashunit watch tests/

# Watch and filter by name
bashunit watch tests/ --filter user

# Watch with simple output
bashunit watch tests/ --simple
```
:::

::: warning Requirements
- **Linux:** `inotifywait` (`sudo apt install inotify-tools`)
- **macOS:** `fswatch` (`brew install fswatch`)

If the required tool is not installed, bashunit prints a clear installation hint
and exits with a non-zero code.
:::

::: tip
If you cannot install `inotifywait` or `fswatch`, use the portable
[`-w/--watch`](#watch-mode) flag on `bashunit test` instead (uses polling).
:::

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
> bashunit upgraded successfully to latest version 0.34.1
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
  test [path]         Run tests (default command)
  bench [path]        Run benchmarks
  assert <fn> <args>  Run standalone assertion
  doc [filter]        Display assertion documentation
  init [dir]          Initialize a new test directory
  learn               Start interactive tutorial
  watch [path]        Watch files and re-run tests on change
  upgrade             Upgrade bashunit to latest version

Global Options:
  -h, --help          Show this help message
  -v, --version       Display the current version

Run 'bashunit <command> --help' for command-specific options.
```
:::

Each subcommand also supports `--help`:

```bash
bashunit test --help
bashunit bench --help
bashunit watch --help
bashunit doc --help
```

## Related

- [Configuration](/configuration) — set the same options via env vars and config files
- [Test files](/test-files) — how bashunit discovers and names test files
- [Coverage](/coverage) — code coverage tracking
- [Benchmarks](/benchmarks) — performance benchmarks with `bashunit bench`

<script setup>
import pkg from '../package.json'
</script>
