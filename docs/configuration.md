---
description: "Configure bashunit with environment variables and config files to control output, parallelism, reporting and test execution across your project."
---

# Configuration

Environment variables and config files control **bashunit** behavior across your project.

It serves to configure the behavior of bashunit in your project.
`.env` and `.bashunitrc` are project files, always read from the working directory.

`-e, --env` (alias `--boot`) loads an **additional** bootstrap file whose assignments
override them; it does not rename `.env`. See
[the option](/command-line#environment-bootstrap). `--skip-env-file` is the only way to
stop `.env` and `.bashunitrc` from being read at all.

## Config file (.bashunitrc)

As an alternative to a `.env` file, you can place a `.bashunitrc` file in the
project root with `KEY=value` lines (blank lines and `#` comments are ignored):

```bash
# .bashunitrc
BASHUNIT_SHOW_HEADER=false
BASHUNIT_PARALLEL_RUN=true
BASHUNIT_PROFILE=true
```

It is meant for committing sensible project defaults. Precedence, from highest
to lowest:

1. CLI flags (e.g. `--simple`)
2. The file given to `-e, --env, --boot`
3. `.env` entries that have a value
4. Environment variables
5. `.bashunitrc`
6. Built-in defaults

The `--env` file is sourced during flag parsing, so it overrides `.env`, `.bashunitrc` and
the ambient environment, and it loses only to flags written **after** it on the command
line: `bashunit --simple --env custom.env` uses the file's value, `bashunit --env custom.env --simple`
uses the flag. Unlike `.env`, an empty entry in that file is **not** treated as "not
configured here": `BASHUNIT_SHOW_HEADER=` assigns the empty string, which is not the
built-in default — for a boolean setting it simply is not `true`. Delete the entry to fall
back to the default; blanking it disables the setting.

An entry left **empty** in `.env` means "not configured here" and does not
override the environment, so `BASHUNIT_OUTPUT_FORMAT=tap ./bashunit` keeps
working even when `.env` lists that name. Give the entry a value and it takes
effect for the whole project, overriding the ambient environment — that is what a
committed project config is for.

`.bashunitrc` only fills values that are not already set, so anything above it
always wins. `--skip-env-file` skips both `.env` and `.bashunitrc`.

The two files are read differently, which is why they behave differently: `.env` is
**sourced** as a shell script under `allexport`, so it can hold arbitrary shell and an
empty entry is unconditional (hence the preservation rule above), while `.bashunitrc` is
parsed as literal `KEY=value` lines and only fills names that are not already set. The
`--env` file is sourced the same way as `.env` but without that preservation pass, which
is why blanking an entry there assigns an empty value instead of being ignored.

## Benchmark reports

> `BASHUNIT_BENCH_REPORT_JSON=file`
> `BASHUNIT_BENCH_REPORT_JUNIT=file`

Write the results of a `bashunit bench` run to a file: JSON for charting and
comparison, JUnit XML so a CI test reporter shows benchmarks next to tests.
Empty by default, which is what keeps a bench run printing only its table.

Same as the `--report-json` / `--report-junit` options of
[`bashunit bench`](/benchmarks#machine-readable-reports).

## Benchmark baseline

> `BASHUNIT_BENCH_BASELINE=file`
> `BASHUNIT_BENCH_BASELINE_TOLERANCE=percentage`
> `BASHUNIT_BENCH_BASELINE_UPDATE=file`

Compare a `bashunit bench` run against a previous `--report-json` result and
fail when a benchmark is more than `TOLERANCE` percent slower (default `10`).
`BASHUNIT_BENCH_BASELINE_UPDATE` records the current run as the new baseline.

Same as the `--baseline` options of
[`bashunit bench`](/benchmarks#failing-on-a-regression).

## Sandbox

> `BASHUNIT_SANDBOX=true|false`
> `BASHUNIT_SANDBOX_ALLOW=cmd,cmd`

Fail any test that runs an external command it did not mock. `false` by
default. `BASHUNIT_SANDBOX_ALLOW` widens the baseline allowlist with a
comma-separated list of commands.

Same as the [`--sandbox`](/command-line#sandbox) option on the command line;
see [test doubles](/test-doubles#sandbox-mode) for what the sandbox does and
does not cover.

```bash [.bashunitrc]
BASHUNIT_SANDBOX=true
BASHUNIT_SANDBOX_ALLOW=curl,jq
```

## Named suites

A project with more than one tier of tests can name each tier in `.bashunitrc`
and select it with [`--suite`](/command-line#suites), instead of keeping the
paths and their flags in a Makefile:

```ini
# .bashunitrc
BASHUNIT_SHOW_HEADER=false      # global settings still live at the top level

[suite:unit]
paths = tests/unit
parallel = true

[suite:acceptance]
paths = tests/acceptance
no-parallel = true
test-timeout = 60

[suite:ci]
paths = tests/unit tests/functional
tag = !slow
```

```bash
bashunit --suite unit
bashunit --suite unit --suite acceptance   # the union of their paths
bashunit --list-suites
```

Inside a section:

- `paths` is the list of files or directories the suite runs, separated by spaces.
- **Every other key is a long option without its leading dashes.** Underscores
  read as dashes, so `test_timeout` and `test-timeout` are the same key.
- `= true` means the bare flag, `= false` leaves it out, anything else is the
  option's value. A value may contain spaces (`report-md = a report.md`) but
  not newlines.

Precedence is the same chain as everywhere else, with suites sitting between
the command line and the global config: **CLI flags → suite settings → global
`.bashunitrc` → `.env` → defaults.** An explicit path argument likewise
replaces the suite's `paths` and keeps its options.

When several suites are named and they set the *same* option to different
values, the one named later on the command line wins — so
`--suite a --suite b` and `--suite b --suite a` run the union of the same paths
but can run them in different modes if, say, one sets `parallel = true` and the
other `no-parallel = true`. Their paths are always unioned regardless of order;
it is only conflicting options that depend on it.

An unknown suite name exits non-zero listing the defined ones, and a line
inside a section that is not `key = value` — or an option that is not a real
flag — exits non-zero quoting it, rather than running something other than what
was asked for.

::: tip
A suite does not have to carry `paths`. bashunit's own `.bashunitrc` defines
option-only suites (`parallel`, `strict`) that its `Makefile` combines with the
file list it already computes.
:::

## Default path

> `BASHUNIT_DEFAULT_PATH=directory|file`

Specifies the `directory` or `file` containing the tests to be run. `tests` by default,
so a run with no path argument searches `tests/` for files ending in `test.sh`.

If a directory is specified, it will execute tests within files ending in `test.sh`.
When running benchmarks (`bashunit bench`), the same path is used to search for files ending in `bench.sh`.

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

Detailed output is the default, but it can be overridden by the environment configuration.

Similar as using `-s|--simple` / `--detailed` on the [command line](/command-line#output-style).

This is a different setting from [`BASHUNIT_VERBOSE`](#verbose): `-vvv|--verbose` adds the
execution-details block and does not change the result style.

::: code-group
```bash [Simple output]
....
```
```bash [.env]
BASHUNIT_SIMPLE_OUTPUT=true
```
:::

::: code-group
```[Detailed output]
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

## Parallel

> `BASHUNIT_PARALLEL_RUN=true|false`

Runs the tests in child processes, one worker per test, which may improve overall testing
speed, especially for larger test suites. `false` by default.

Dispatch keeps definition order, but **completion** order is nondeterministic, so tests
must not depend on each other. Parallel never shuffles: shuffling is opt-in through
[`BASHUNIT_RANDOM_ORDER`](#random-order) or `BASHUNIT_ORDER_BY=random`. Cap the concurrency
with [`BASHUNIT_PARALLEL_JOBS`](#parallel-jobs), and use `--no-parallel` to opt out of a
configured parallel run.

::: warning
Parallel execution is supported on **macOS**, **Ubuntu**, **Alpine**, and
**Windows**. On other systems bashunit forces sequential execution to avoid
inconsistent results.
:::

Similar as using `-p|--parallel` option on the [command line](/command-line#parallel).

## Parallel Jobs

> `BASHUNIT_PARALLEL_JOBS=<N>`

Limits the number of concurrent jobs when running in parallel mode. Set to `0` (default) for unlimited concurrency.

Similar as using `-j|--jobs` option on the [command line](/command-line#jobs).

## Stop on failure

> `BASHUNIT_STOP_ON_FAILURE=true|false`

Force to stop the runner right after encountering one failing test. `false` by default.

Similar as using `-S|--stop-on-failure` option on the [command line](/command-line#test-options).

::: tip Assertion behavior
By default, when an assertion fails within a test, subsequent assertions in the same test are skipped. Use `-R, --run-all` or set `BASHUNIT_STOP_ON_ASSERTION_FAILURE=false` to run all assertions even when one fails.

The `--stop-on-failure` flag is separate – it stops the entire test runner after a failing **test**, while assertion-level stopping happens within each test.
:::

## Pass with no tests

> `BASHUNIT_PASS_WITH_NO_TESTS=true|false`

Exit `0` when the run selects no tests. `false` by default, because selecting
nothing usually means a typo — the run still reports `No tests found` either
way, so only the verdict changes.

Turn it on where an empty run is deliberate: a CI matrix whose shards are not
all populated, or a changed-files run that touched no tests. Prefer the
`--pass-with-no-tests` flag on those invocations over setting this globally; a
suite that silently stops running tests is what the non-zero default catches.

It does not excuse a path that is not on disk — that is a wrong invocation and
is still refused by name.

Similar as using `--pass-with-no-tests` option on the [command line](/command-line#test-options).

## Test timeout

> `BASHUNIT_TEST_TIMEOUT=<seconds>`

Abort an individual test if it runs longer than the given number of seconds,
report it as a failure and keep running the remaining tests. `0` (disabled) by
default. Useful to stop a run from hanging forever on a blocked test, such as a
mock left without an implementation.

The value is expressed in whole seconds and applies per test (set up and tear
down included). It needs no external `timeout` command and works on Bash 3.0+,
including the default macOS Bash.

Similar as using `--test-timeout` option on the [command line](/command-line#test-timeout).

::: code-group
```bash [Enable a 5s timeout]
BASHUNIT_TEST_TIMEOUT=5
```
```bash [Disabled (default)]
BASHUNIT_TEST_TIMEOUT=0
```
:::

## Retry

> `BASHUNIT_RETRY=<n>`

Re-run a failed test up to `n` extra times and report it as passed if any
attempt passes; it fails only after every attempt fails. `0` (disabled) by
default. Mitigates flaky tests in CI without hiding a consistently broken one; a
test that recovers on retry is annotated so the flakiness stays visible.

Applies per test and works together with `--parallel` and `--stop-on-failure`.

Similar as using `--retry` option on the [command line](/command-line#retry).

::: code-group
```bash [Retry up to 2 times]
BASHUNIT_RETRY=2
```
```bash [Disabled (default)]
BASHUNIT_RETRY=0
```
:::

## Repeat

> `BASHUNIT_REPEAT=<n>`

Run each selected test `n` times so flakiness surfaces before CI hits it. `1` by default.
The test is reported once with the aggregate outcome, and a failure names the iteration it
happened on. Repeat wraps [`BASHUNIT_RETRY`](#retry), not the other way round.

Similar as using `--repeat` option on the [command line](/command-line#repeat).

## Fail on flaky

> `BASHUNIT_FAIL_ON_FLAKY=true|false`

Turn a run red when a test passed only after a retry. `false` by default, so a flaky test
stays inside the pass total and the exit code is unchanged.

Similar as using `--fail-on-flaky` option on the [command line](/command-line#fail-on-flaky).

## Random order

> `BASHUNIT_RANDOM_ORDER=true|false` and `BASHUNIT_SEED=<n>`

Randomize the order of test files and of the tests within each file to surface
hidden inter-test coupling. Disabled by default. `BASHUNIT_SEED` pins the
shuffle so a run can be replayed; when unset, a seed is generated and printed in
the run header. Composes with `--parallel`.

Similar as using `--random-order` / `--seed` options on the
[command line](/command-line#random-order), with one difference: `--seed` on the
command line turns the random order on by itself, `BASHUNIT_SEED` does not. A
seed typed at the prompt is a replay of one run; a seed in a config file is
read by every run, including the nested ones a suite spawns, so it stays inert
until `BASHUNIT_RANDOM_ORDER` asks for it.

::: code-group
```bash [Reproducible shuffle]
BASHUNIT_RANDOM_ORDER=true
BASHUNIT_SEED=12345
```
```bash [Disabled (default)]
BASHUNIT_RANDOM_ORDER=false
```
:::

## Execution order

> `BASHUNIT_ORDER_BY=defined|defects|random`

Execution order. `defined` by default (definition order). `defects` runs the last run's
failures first and still runs the whole suite. `random` is the same mode as
[`BASHUNIT_RANDOM_ORDER=true`](#random-order).

Similar as using `--order-by` option on the [command line](/command-line#order-by).

## Exclude filter

> `BASHUNIT_EXCLUDE_FILTER=name`

Skip tests whose name matches. Empty by default. It wins over a `--filter` match.

Similar as using `--exclude-filter` option on the [command line](/command-line#exclude-filter).

## Changed files only

> `BASHUNIT_CHANGED=true|false` and `BASHUNIT_CHANGED_REF=<ref>`

Run only the test files git reports as changed. `false` by default.
`BASHUNIT_CHANGED_REF` is empty by default, which means `origin/HEAD`, then `HEAD`.

Similar as using `--changed` option on the [command line](/command-line#changed).

## Shard

> `BASHUNIT_SHARD_INDEX=<i>` and `BASHUNIT_SHARD_TOTAL=<n>`

Run shard `i` of `n` to split the suite across runners. Both are empty (disabled) by
default, and sharding needs both.

Similar as using `--shard` option on the [command line](/command-line#shard).

## List tests

> `BASHUNIT_LIST_TESTS=true|false` and `BASHUNIT_LIST_FORMAT=text|json`

Print the tests a run would execute and exit without running them. `false` and `text` by
default.

Similar as using `--list` / `--list-format` options on the [command line](/command-line#list).

## List tags

> `BASHUNIT_LIST_TAGS=true|false`

Print the tags carried by the selected files, one per line, and exit without running
anything. Disabled by default. It implies `BASHUNIT_LIST_TESTS`: the answer comes from
scanning the selected files, and nothing may run to produce it.

Similar as using `--list-tags` option on the [command line](/command-line#list-tags).

## Snapshot update

> `BASHUNIT_SNAPSHOT_UPDATE=true|false`

Rewrite existing snapshots with the value each run produces instead of comparing
against them. Disabled by default. Snapshots holding the placeholder are left
alone. Because it writes to disk, prefer the flag for a one-off re-record and
keep this off in a committed `.env`.

Similar as using `--snapshot-update` option on the
[command line](/command-line#snapshot-update).

::: code-group
```bash [Re-record snapshots]
BASHUNIT_SNAPSHOT_UPDATE=true
```
```bash [Disabled (default)]
BASHUNIT_SNAPSHOT_UPDATE=false
```
:::

## Snapshot create

> `BASHUNIT_SNAPSHOT_CREATE=true|false`

Whether a missing snapshot is recorded on the fly. Enabled by default, which is
what makes the first run of a snapshot test pass. Set it to `false` in CI so a
snapshot that was never committed fails the run instead of being re-created
silently.

Similar as using `--no-snapshot-create` option on the
[command line](/command-line#no-snapshot-create).

::: code-group
```bash [CI: a missing snapshot fails]
BASHUNIT_SNAPSHOT_CREATE=false
```
```bash [Default]
BASHUNIT_SNAPSHOT_CREATE=true
```
:::

## Snapshot report unused

> `BASHUNIT_SNAPSHOT_REPORT_UNUSED=true|false`

List the snapshot files no test resolved. `false` by default. Full runs only, and it deletes
nothing.

Similar as using `--snapshot-report-unused` option on the [command line](/command-line#snapshot-report-unused).

## Snapshot prune

> `BASHUNIT_SNAPSHOT_PRUNE=true|false`

Delete the snapshot files no test resolved. `false` by default. Full runs only,
and never on a run with failures.

Similar as using `--snapshot-prune` option on the [command line](/command-line#snapshot-prune).

## Rerun failed

> `BASHUNIT_RERUN_FAILED=true|false`

Replay only the tests that failed on the previous run instead of the whole
suite. Disabled by default. Every run records its failing tests to
`.bashunit/last-failed` (add `.bashunit/` to your `.gitignore`), so enabling
this replays exactly those; a fully green run clears the cache, and an empty
cache falls back to running everything. Composes with `--filter`, `--tag` and
`--parallel`.

Similar as using `--rerun-failed` option on the
[command line](/command-line#rerun-failed).

::: code-group
```bash [Replay last failures]
BASHUNIT_RERUN_FAILED=true
```
```bash [Disabled (default)]
BASHUNIT_RERUN_FAILED=false
```
:::

## Stop on assertion failure

> `BASHUNIT_STOP_ON_ASSERTION_FAILURE=true|false`

Controls whether to stop at the first failed assertion within a test. `true` by default.

When enabled (default), subsequent assertions in the same test are skipped after a failure.
When disabled, all assertions in the test run, showing all failures at once.

Similar as using `-R|--run-all` option on the [command line](/command-line).

::: code-group
```bash [Run all assertions]
BASHUNIT_STOP_ON_ASSERTION_FAILURE=false
```
```bash [Stop on first failure (default)]
BASHUNIT_STOP_ON_ASSERTION_FAILURE=true
```
:::

## Watch polling interval

> `BASHUNIT_WATCH_INTERVAL=<seconds>`

Seconds between checks for the pure-shell polling loop used by watch mode when
neither `inotifywait` nor `fswatch` is installed. `2` by default. Must be a
positive integer; any other value falls back to the default.

::: code-group
```bash [Poll every 5 seconds]
BASHUNIT_WATCH_INTERVAL=5
```
:::

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

## Show skipped

> `BASHUNIT_SHOW_SKIPPED=true|false`

Show a summary of skipped tests at the end of the run. Disabled by default.

Similar as using `--show-skipped` option on the [command line](/command-line).

::: code-group
```bash [Show skipped]
BASHUNIT_SHOW_SKIPPED=true
```
```bash [Disabled (default)]
BASHUNIT_SHOW_SKIPPED=false
```
:::

## Show incomplete

> `BASHUNIT_SHOW_INCOMPLETE=true|false`

Show a summary of incomplete tests at the end of the run. Disabled by default.

Similar as using `--show-incomplete` option on the [command line](/command-line).

::: code-group
```bash [Show incomplete]
BASHUNIT_SHOW_INCOMPLETE=true
```
```bash [Disabled (default)]
BASHUNIT_SHOW_INCOMPLETE=false
```
:::

## Show execution time

> `BASHUNIT_SHOW_EXECUTION_TIME=true|false|auto`

Specify if you want to display the per-test execution time after running **bashunit**. `auto` by default.

`auto` shows per-test times when the shell has a fork-free high-resolution clock (Bash 5.0+ via `EPOCHREALTIME`, or GNU `date`), and hides them when measuring a test would require forking an interpreter (for example the default Bash 3.2 on macOS, which falls back to `perl`). This keeps a plain run fast on those shells. Set `true` to always measure and show per-test times (paying that cost), or `false` to always hide them. `--profile`, `--verbose`, and the `--report-*`/`--log-junit` reports always measure regardless of this setting.

The time format adapts based on duration:
- Under 1 second: displayed in milliseconds (e.g., `14 ms`)
- 1-59 seconds: displayed in seconds (e.g., `5 s`)
- 60+ seconds: displayed in minutes and seconds (e.g., `2m 1s`)

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

## Output format

> `BASHUNIT_OUTPUT_FORMAT=text|tap|json|junit`

Send the report to stdout in a machine-readable format instead of the console
rendering: `tap` for
[TAP version 13](https://testanything.org/tap-version-13-specification.html),
`json` for the `--report-json` document and `junit` for JUnit XML. `text`, the
default, keeps the human-readable output.

Similar as using `--output` option on the [command line](/command-line#output-format).

::: code-group
```bash [.env]
BASHUNIT_OUTPUT_FORMAT=tap
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

## Log GitHub Actions

> `BASHUNIT_LOG_GHA=file`

Write GitHub Actions workflow commands (`::error`, `::warning`, `::notice`) to the given file, so failed, risky and incomplete tests show up as inline annotations in the "Files changed" tab of a pull request.

On a CI runner, stream the generated file to stdout so GitHub parses it:

::: code-group
```bash [Example]
BASHUNIT_LOG_GHA=gha.log
```
```yaml [GitHub Actions workflow]
- run: ./bashunit --log-gha gha.log tests/ || (cat gha.log && exit 1)
```
:::

## Report HTML

> `BASHUNIT_REPORT_HTML=file`

Create a report HTML file that contains information about the test results of your bashunit tests.

The page is a summary table plus one table per test file — test name, status and duration —
followed by a **Failures** section giving each failure its name, `file:line` and the assertion
message, so the artifact answers *what broke* rather than only *that something did*. A run with
no failures does not get the section.

::: code-group
```bash [Example]
BASHUNIT_REPORT_HTML=report.html
```
:::

## Report TAP

> `BASHUNIT_REPORT_TAP=file`

Write a [TAP version 13](https://testanything.org/tap-version-13-specification.html) report to the given file. Unlike `BASHUNIT_OUTPUT_FORMAT=tap`, which replaces the console output, this writes to disk and leaves the normal output alone.

::: code-group
```bash [Example]
BASHUNIT_REPORT_TAP=report.tap
```
:::

## Report JSON

> `BASHUNIT_REPORT_JSON=file`

Write a machine-readable JSON report to the given file: a summary plus one entry per test, including the failure message and source line. Strings are escaped in pure Bash, so `jq` is not required to produce it.

::: code-group
```bash [Example]
BASHUNIT_REPORT_JSON=report.json
```
:::

::: tip
The report destination is checked before the suite runs — an unwritable path fails
immediately instead of after a passing run. See [Invalid input](/command-line#invalid-input).
:::

## Report Markdown

> `BASHUNIT_REPORT_MD=file`

Write a Markdown run summary: verdict, counts table, failures with their message, plus
coverage and slowest tests when those ran. Empty by default. Inside GitHub Actions it is
also appended to `$GITHUB_STEP_SUMMARY`, for the outermost run only.

Similar as using `--report-md` option on the [command line](/command-line#report-md).

## GitHub Actions annotations

> `BASHUNIT_GHA_ANNOTATIONS=auto|always|never`

Controls GitHub Actions annotations on stdout. `auto` by default: on inside GitHub Actions,
quiet everywhere else. Never emitted under a machine `--output` format
(`tap`, `json`, `junit`).

Similar as using `--gha-annotations` option on the [command line](/command-line#gha-annotations).

## Bootstrap

> `BASHUNIT_BOOTSTRAP=file`

Specifies an additional file to be loaded for all tests cases.
Useful to set up global variables or functions accessible in all your tests.

::: tip Using functions in tests
If you need shell functions available in your tests, define them in a bootstrap
file and use `export -f function_name` to make them available in test subshells.
This is the recommended pattern for sharing functions across tests.
:::

Similarly, you can use load an additional file via the [command line](/command-line#environment-bootstrap).

::: code-group
```bash [Example]
# a simple .env file
BASHUNIT_BOOTSTRAP=".env.tests"

# or a complete script file
BASHUNIT_BOOTSTRAP="tests/globals.sh"

# Default value
BASHUNIT_BOOTSTRAP="tests/bootstrap.sh"
```
:::

### Bootstrap arguments

> `BASHUNIT_BOOTSTRAP_ARGS=arguments`

Pass arguments to the bootstrap file. Arguments are space-separated and available
as positional parameters (`$1`, `$2`, etc.) in your bootstrap script.

::: code-group
```bash [.env]
BASHUNIT_BOOTSTRAP="tests/bootstrap.sh"
BASHUNIT_BOOTSTRAP_ARGS="staging verbose"
```
```bash [bootstrap.sh]
#!/usr/bin/env bash
ENVIRONMENT="${1:-production}"
VERBOSE="${2:-false}"

export API_URL="https://${ENVIRONMENT}.api.example.com"
```
:::

You can also pass arguments inline via the [--env](/command-line#environment-bootstrap) option:

```bash
bashunit --env "tests/bootstrap.sh staging verbose" tests/
```

## Dev log

> `BASHUNIT_DEV_LOG=file`

> See: [Globals > log](/globals#bashunit-log)

::: code-group
```bash [Setup]
BASHUNIT_DEV_LOG="dev.log"
```
```bash [Usage]
bashunit::log "I am tracing something..."
bashunit::log "error" "an" "error" "message"
bashunit::log "warning" "different log level messages!"
```
```[Output: dev.log]
2024-10-03 21:27:23 [INFO]: I am tracing something... #tests/sample.sh:11
2024-10-03 21:27:23 [ERROR]: an error message #tests/sample.sh:27
2024-10-03 21:27:24 [WARNING]: different log level messages! #tests/sample.sh:21
```
:::
When enabled, the selected log file path is printed in the header so you can
quickly `tail -f` it while the tests run.

> All internal messages emitted by bashunit are prefixed with `[INTERNAL]`.
> You can toggle internal messages with `BASHUNIT_INTERNAL_LOG=true|false`.

## Bench mode

> `BASHUNIT_BENCH_MODE=true|false`

Set by the `bashunit bench` subcommand and not meant to be configured by hand. `false` by
default.

## Verbose

> `BASHUNIT_VERBOSE=bool`

Display internal details for each test.

Similarly, you can use the command line option for this: [command line](/command-line#test-options).

::: code-group
```bash [Example]
BASHUNIT_VERBOSE=true
```
:::

## No output

> `BASHUNIT_NO_OUTPUT=true|false`

Suppress all console output. Defaults to `false`.

Similar as using `--no-output` option on the [command line](/command-line#test-options).

::: code-group
```bash [Example]
BASHUNIT_NO_OUTPUT=true
```
:::

## Fail on risky

> `BASHUNIT_FAIL_ON_RISKY=true|false`

Treat risky tests (tests with zero assertions) as failures instead of warnings. `false` by default.

When enabled, a test that finishes without running any assertion is reported as failed, and the run exits with a non-zero status.

Similar as using `--fail-on-risky` option on the command line.

::: code-group
```bash [Example]
BASHUNIT_FAIL_ON_RISKY=true
```
:::

## Profile

> `BASHUNIT_PROFILE=true|false` · `BASHUNIT_PROFILE_COUNT=<n>`

Report the slowest tests after a run. `false` by default; `BASHUNIT_PROFILE_COUNT` defaults to `10`.

When enabled, each test's duration is recorded and the slowest ones are printed at the end,
sorted from slowest to fastest. `BASHUNIT_PROFILE_COUNT` limits how many are shown.

Similar as using `--profile` option on the [command line](/command-line#profile).

::: code-group
```bash [Example]
BASHUNIT_PROFILE=true
BASHUNIT_PROFILE_COUNT=5
```
:::

## Failures only

> `BASHUNIT_FAILURES_ONLY=true|false`

Only show failures, suppressing passed, skipped, and incomplete tests. `false` by default.

When enabled, progress output is suppressed and only failing tests are displayed.
The final summary still shows all counts (passed/failed/skipped/incomplete).

Similar as using `--failures-only` option on the [command line](/command-line#test-options).

::: code-group
```bash [Example]
BASHUNIT_FAILURES_ONLY=true
```
:::

## No progress

> `BASHUNIT_NO_PROGRESS=true|false`

Suppress real-time progress display during test execution. `false` by default.

When enabled, bashunit hides per-test output, file headers, hook messages, and spinners,
showing only the final summary. Useful for CI/CD pipelines or log-restricted environments.

Similar as using `--no-progress` option on the [command line](/command-line#no-progress).

::: code-group
```bash [Example]
BASHUNIT_NO_PROGRESS=true
```
:::

## Show output on failure

> `BASHUNIT_SHOW_OUTPUT_ON_FAILURE=true|false`

Display captured stdout/stderr output when tests fail with runtime errors or assertion failures. `true` by default.

When a test fails due to a runtime error (command not found, unbound variable, etc.) or
a failed assertion after the test printed diagnostics, bashunit displays the test's output
in an "Output:" section to help debug the failure.

Similar as using `--show-output` or `--no-output-on-failure` options on the [command line](/command-line#show-output-on-failure).

::: code-group
```[Output example]
✗ Error: My test function
    command not found
    Output:
      Debug: Setting up test
      Running command: my_command
```
```bash [.env to disable]
BASHUNIT_SHOW_OUTPUT_ON_FAILURE=false
```
:::

## Diff on multiline failures

> `BASHUNIT_NO_DIFF=true|false`

When an `assert_equals`/`assert_same` failure involves a multiline value,
bashunit renders a git word-diff below the `Expected/but got` header so the
difference is easy to spot; the inline values are truncated to their first line
while the diff is shown. Requires git (falls back to the plain output when it is
unavailable), respects `--no-color`, and never affects single-line failures or
machine reports (JUnit/TAP/JSON). `false` by default — set `BASHUNIT_NO_DIFF=true`
to always print the full raw values instead.

::: code-group
```[Output example]
✗ Failed: My test function
    Expected 'alpha…'
    but got  'alpha…'
    alpha
    [-beta-]{+DELTA+}
    gamma
```
```bash [.env to disable]
BASHUNIT_NO_DIFF=true
```
:::

## Color output

> `BASHUNIT_NO_COLOR=true|false`

Disables ANSI color codes in output. `false` by default.

`NO_COLOR` is the honored external standard: a non-empty `NO_COLOR` forces
`BASHUNIT_NO_COLOR=true`. Follows [no-color.org](https://no-color.org).

When set to any value, bashunit will output plain text without color formatting.

Similar as using `--no-color` option on the [command line](/command-line).

::: code-group
```bash [Example]
NO_COLOR=1
```
:::

## Strict mode

> `BASHUNIT_STRICT_MODE=true|false`

Enable strict shell mode (`set -euo pipefail`) for test execution. `false` by default.

By default, tests run in permissive mode to maximize compatibility with
different coding styles. Enable strict mode to catch potential issues like
uninitialized variables and unchecked command failures.

Similar as using `--strict` option on the [command line](/command-line#strict-mode).

::: code-group
```bash [Example]
BASHUNIT_STRICT_MODE=true
```
:::

## Skip env file

> `BASHUNIT_SKIP_ENV_FILE=true|false`

Skip loading the `.env` file and use the current shell environment only. `false` by default.

By default, bashunit loads variables from `.env` which can override environment
variables set in your shell. Enable this option when running in CI/CD pipelines
or when you want shell environment variables to take precedence.

::: warning Important
Only environment variables are inherited from the parent shell. Shell functions
and aliases are NOT available in tests due to bashunit's subshell architecture.
Use a [bootstrap file](#bootstrap) to define functions needed by your tests.
:::

Similar as using `--skip-env-file` option on the [command line](/command-line#skip-env-file).

::: code-group
```bash [Example]
BASHUNIT_SKIP_ENV_FILE=true ./bashunit tests/
```
:::

## Login shell

> `BASHUNIT_LOGIN_SHELL=true|false`

Run tests in a login shell context by sourcing profile files. `false` by default.

When enabled, bashunit sources the following files (if they exist) before each test:
- `/etc/profile`
- `~/.bash_profile`
- `~/.bash_login`
- `~/.profile`

Use this when your tests depend on environment setup from login shell profiles.

Similar as using `-l|--login` option on the [command line](/command-line#login-shell).

::: code-group
```bash [Example]
BASHUNIT_LOGIN_SHELL=true
```
:::

## Coverage

### Enable coverage

> `BASHUNIT_COVERAGE=true|false`

Enable code coverage tracking. `false` by default.

When enabled, bashunit tracks which lines of your source code are executed during tests
and generates a coverage report.

Similar as using `--coverage` option on the [command line](/command-line#coverage).

::: code-group
```bash [.env]
BASHUNIT_COVERAGE=true
```
:::

### Coverage paths

> `BASHUNIT_COVERAGE_PATHS=paths`

Comma-separated list of paths to track for coverage.

By default, paths are auto-discovered from test file names (e.g., `tests/unit/assert_test.sh` discovers `src/assert.sh`).

::: code-group
```bash [.env]
# Single path (explicit)
BASHUNIT_COVERAGE_PATHS=src/

# Multiple paths (explicit)
BASHUNIT_COVERAGE_PATHS=src/,lib/,bin/
```
:::

### Coverage exclude

> `BASHUNIT_COVERAGE_EXCLUDE=patterns`

Comma-separated list of patterns to exclude from coverage tracking.
Default: `tests/*,vendor/*,*_test.sh,*Test.sh`

::: code-group
```bash [.env]
BASHUNIT_COVERAGE_EXCLUDE=tests/*,vendor/*,*_test.sh,*_mock.sh
```
:::

### Coverage report

> `BASHUNIT_COVERAGE_REPORT=file`

Path for the LCOV format coverage report. `coverage/lcov.info` by default.

An empty entry means "not configured", so the default path still applies. To skip the file
and keep the console report only, use the `--no-coverage-report` flag.

::: code-group
```bash [.env]
# Custom path
BASHUNIT_COVERAGE_REPORT=reports/coverage.lcov
```
```bash [Console only]
bashunit tests/ --coverage --no-coverage-report
```
:::

### Coverage report HTML

> `BASHUNIT_COVERAGE_REPORT_HTML=dir`

Directory for the browsable HTML coverage report. Empty by default (not generated).

Similar as using `--coverage-report-html` option on the [command line](/command-line#coverage).

### Coverage report Cobertura

> `BASHUNIT_COVERAGE_REPORT_COBERTURA=file`

Path for the Cobertura XML coverage report, the format GitLab merge-request coverage visualisation, Azure DevOps and Jenkins consume. Empty by default (not generated); `--coverage-report-cobertura` with no value uses `coverage/cobertura.xml`.

Similar as using `--coverage-report-cobertura` option on the [command line](/command-line#coverage).

### Coverage diff

> `BASHUNIT_COVERAGE_DIFF=<ref>`

Restrict the console coverage report to the lines changed since `<ref>`. Empty by default.
`BASHUNIT_COVERAGE_MIN` then gates on that diff percentage instead of the whole-file one.
LCOV and HTML stay whole-file.

Similar as using `--coverage-diff` option on the [command line](/command-line#coverage).

### Coverage detail blocks

> `BASHUNIT_COVERAGE_SHOW_FUNCTIONS=true|false`
>
> `BASHUNIT_COVERAGE_SHOW_UNCOVERED=true|false`
>
> `BASHUNIT_COVERAGE_SHOW_LINE_HITS=true|false`

Opt-in blocks appended to the console coverage report: a per-function table, the executable
lines never hit (as compressed ranges), and per-line execution counts. All `false` by
default.

### Coverage engine

> `BASHUNIT_COVERAGE_ENGINE=auto|xtrace|trap`

Which mechanism captures executed lines. `auto` by default.

`xtrace` redirects `set -x` to a private file descriptor and parses it after the
run, which costs about a quarter of what the `DEBUG` trap costs per executed
line. It requires `BASH_XTRACEFD` (Bash 4.1+), so `auto` — and an explicit
`xtrace` that the running Bash cannot honour — falls back to `trap`.

See [Coverage](/coverage#tracing-engine) for the behavioural differences.

::: code-group
```bash [.env]
BASHUNIT_COVERAGE_ENGINE=trap
```
:::

### Coverage minimum

> `BASHUNIT_COVERAGE_MIN=percent`

Minimum coverage percentage required. Empty by default (no minimum).

When set, bashunit will exit with a failure code if coverage falls below this threshold.

::: code-group
```bash [.env]
BASHUNIT_COVERAGE_MIN=80
```
:::

### Coverage thresholds

> `BASHUNIT_COVERAGE_THRESHOLD_LOW=percent`
>
> `BASHUNIT_COVERAGE_THRESHOLD_HIGH=percent`

Thresholds for color-coding the coverage output. Defaults: `50` and `80`.

- At or above `THRESHOLD_HIGH`: green
- At or above `THRESHOLD_LOW`: yellow
- Below `THRESHOLD_LOW`: red

::: code-group
```bash [.env]
BASHUNIT_COVERAGE_THRESHOLD_LOW=60
BASHUNIT_COVERAGE_THRESHOLD_HIGH=90
```
:::

## Deprecations

Many settings also answer to an **unprefixed** name — `VERBOSE` as well as
`BASHUNIT_VERBOSE`. Those are the ones that predate the `BASHUNIT_` prefix introduced in
0.15.0, and they are deprecated: the names are generic enough that an
unrelated tool exporting `COVERAGE=true` or `VERBOSE=true` silently
reconfigures bashunit. Always use the prefixed name.

When a deprecated form is what supplied a value, bashunit says so on stderr:

```
Deprecated: the unprefixed `VERBOSE`. Use `BASHUNIT_VERBOSE` instead.
```

Settings added after the prefix ship **only** under `BASHUNIT_`, so an unprefixed form for
them is ignored rather than warned about. `--retry`, `--seed`, `--order-by`, `--list`, and
the snapshot and shard settings are all prefix-only.

The warning goes to stderr, so it never corrupts a report on stdout. Silence it
with:

> `BASHUNIT_NO_DEPRECATION_WARNINGS=true`

::: tip Deprecation policy
A form that still works but is on its way out warns for at least one minor
release before it is removed in a major one. If you see one of these warnings,
you have time to migrate — but the form will not be there forever.
:::

Currently deprecated:

| Deprecated | Use instead |
|------------|-------------|
| Unprefixed settings (`VERBOSE`, `COVERAGE`, …) | The `BASHUNIT_`-prefixed name |
| `bashunit test --assert <fn>` | [`bashunit assert <fn>`](/standalone) |

## Related

- [Command line](/command-line) — flags that mirror these settings
- [Test files](/test-files) — how tests are discovered and named
- [Coverage](/coverage) — measure how much code your tests exercise
- [Globals](/globals) — helper functions available in tests

<script setup>
import pkg from '../package.json'
</script>
