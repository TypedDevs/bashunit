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
bashunit doc [options] [filter]   # Show assertion documentation
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
| `-a, --assert <fn> <args>`     | Run a standalone assert function (deprecated: use [`bashunit assert`](#assert)) |
| `-e, --env, --boot <file>`     | Load custom env/bootstrap file (supports args)   |
| `-f, --filter <name>`          | Only run tests matching name                     |
| `--exclude-filter <name>`      | Skip tests whose name matches (repeatable)       |
| `--suite <name>`               | Run a `[suite:<name>]` from `.bashunitrc` (repeatable) |
| `--sandbox`                    | Fail a test that runs an external command it did not mock |
| `--sandbox-allow <cmd,...>`    | Commands the sandbox still allows (repeatable)   |
| `--list-suites`                | Print the suites defined in `.bashunitrc` and exit |
| `--tag <expr>`                 | Only run tests with matching `@tag`; supports `a&&b` and `!a` |
| `--exclude-tag <name>`         | Skip tests with matching `@tag` (repeatable)     |
| `--output <format>`            | Report on stdout: `text` (default), `tap`, `json`, `junit` |
| `-w, --watch`                  | Watch files and re-run tests on change           |
| `--log-junit, --report-junit <file>` | Write JUnit XML report                     |
| `--log-gha <file>`             | Write GitHub Actions workflow-commands log       |
| `--gha-annotations <mode>`     | Annotations on stdout: `auto` (default), `always` or `never` |
| `-j, --jobs <N\|auto>`         | Run tests in parallel with max N concurrent jobs (`auto` = CPU cores) |
| `-p, --parallel`               | Run tests in parallel                            |
| `--no-parallel`                | Run tests sequentially                           |
| `-r, --report-html <file>`     | Write HTML report                                |
| `--report-tap <file>`          | Write TAP version 13 report to a file            |
| `--report-json <file>`         | Write machine-readable JSON report to a file     |
| `--report-md <file>`           | Write a Markdown summary (auto-appended to `$GITHUB_STEP_SUMMARY`) |
| `-R, --run-all`                | Run all assertions (don't stop on first failure) |
| `-s, --simple`                 | Simple output (dots)                             |
| `--detailed`                   | Detailed output (default)                        |
| `-S, --stop-on-failure`        | Stop on first failure                            |
| `--test-timeout <seconds>`     | Fail a test if it runs longer than N seconds     |
| `--retry <n>`                  | Re-run a failed test up to N extra times         |
| `--repeat <n>`                 | Run each selected test N times; it fails if any iteration fails |
| `--random-order`               | Randomize test execution order                   |
| `--order-by <mode>`            | Execution order: `defined` (default), `defects` or `random` |
| `--seed <n>`                   | Seed for `--random-order` (reproducible shuffle) |
| `--shard <i>/<n>`              | Run shard i of n (split suite across runners)    |
| `--rerun-failed`               | Replay only the tests that failed on the last run |
| `--changed [<ref>]`            | Run only the test files changed since `<ref>` (default: `origin/HEAD`, then `HEAD`) |
| `--list`, `--dry-run`          | Print the tests that would run, then exit         |
| `--list-format <fmt>`          | Rendering for `--list`: `text` (default) or `json` |
| `--snapshot-update`            | Rewrite existing snapshots from the actual value |
| `--no-snapshot-create`         | Fail on a missing snapshot instead of recording it |
| `--snapshot-report-unused`     | List snapshot files no test resolved (deletes nothing) |
| `--snapshot-prune`             | Delete the snapshot files no test resolved (full runs only) |
| `--show-skipped`               | Show skipped tests summary at end                |
| `--show-incomplete`            | Show incomplete tests summary at end             |
| `-vvv, --verbose`              | Show execution details                           |
| `--debug [file]`               | Enable shell debug mode                          |
| `--no-output`                  | Suppress all output                              |
| `--failures-only`              | Only show failures                               |
| `--fail-on-risky`              | Treat risky tests (no assertions) as failures    |
| `--fail-on-flaky`              | Treat flaky tests (passed only after a retry) as failures |
| `--profile`                    | Report the slowest tests after a run             |
| `--no-progress`                | Suppress real-time progress, show only summary   |
| `--show-output`                | Show test output on failure (default)            |
| `--no-output-on-failure`       | Hide test output on failure                      |
| `--strict`                     | Enable strict shell mode                         |
| `--skip-env-file`              | Skip `.env` loading, use shell environment only  |
| `-l, --login`                  | Run tests in login shell context                 |
| `--no-color`                   | Disable colored output                           |
| `-h, --help`                   | Show the test help                               |
| `--coverage*`                  | Nine coverage flags, see [Coverage](#coverage)   |

### Standalone Assert

> `bashunit test -a|--assert function "arg1" "arg2"`

::: warning Deprecated
Use the [`assert` subcommand](#assert) instead. This form still works and prints a
deprecation notice on stderr.
:::

Run a core assert function standalone without a test context.

::: code-group
```bash [Example]
bashunit test --assert equals "foo" "bar"
```
```[Output]
Deprecated: `bashunit test --assert`. Use `bashunit assert` instead.
✗ Failed: assert equals
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

The match is against the **function name**, case-sensitively — not the humanized
title the report prints. So the title `✓ Passed: User login` belongs to
`test_user_login`, and `--filter "User login"` selects nothing. A filter that
matches no test says so and names the test it most likely meant:

```
 No tests found
No test matches 'User login'. Filters match the function name, not the title: did you mean 'test_user_login'?
```

### Exclude filter

> `bashunit test --exclude-filter "name"`

Skip tests whose name matches — the name-based counterpart of
[`--exclude-tag`](#tags), for when you want to drop a handful of tests without
tagging them first.

```bash
bashunit test tests/ --exclude-filter "slow_network"
bashunit test tests/ --exclude-filter "slow" --exclude-filter "flaky"  # OR
bashunit test tests/ --filter user --exclude-filter admin              # user, not admin
```

Matching is identical to `--filter`, the flag is repeatable (a test is skipped
if it matches **any** value), and exclusion wins when a name matches both — the
same precedence `--exclude-tag` has over `--tag`.

Excluded tests are **not** reported as skipped: they are never selected, so they
do not appear in the header count either.

### Tags

> `bashunit test --tag <name>`
> `bashunit test --exclude-tag <name>`

Filter tests by `# @tag` annotations. Both flags are repeatable. `--tag` uses OR
logic across names; `--exclude-tag` wins when a test matches both.

::: code-group
```bash [Annotate tests]
# @tags integration        # applies to every test in this file

# @tag slow
function test_heavy_computation() {
  ...
}

# @tag api
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

A tag exists only where someone wrote it, and nothing lists the ones in use, so
a `--tag` that selects nothing names the tags the run actually saw:

```
 No tests found
No test matches tag 'integraton'. Tags in the selected files: integration,slow.
```

When no test carries a tag at all, it says that instead — a different mistake:

```
No test matches tag 'anything'. No test in the selected files carries a '# @tag'.
```

#### File-level tags

`# @tags <list>` applies every name in the list to **all** tests in that file,
so tagging a whole suite no longer means repeating `# @tag` above each function.
It may appear anywhere at top level, and unions with per-function `# @tag`
(a name carried at both levels is not duplicated).

Note the plural: `# @tags a b` is a space-separated list applying to the file,
while `# @tag a b` is a single tag literally named `a b` applying to the next
function.

#### Tag expressions

A single `--tag` value can combine terms with `&&` (AND) and `!` (NOT):

```bash
bashunit test tests/ --tag 'slow&&db'      # both tags
bashunit test tests/ --tag '!slow'         # everything except slow
bashunit test tests/ --tag 'db&&!slow'     # db, but not slow
```

Repeating the flag still means OR *between* expressions, so existing usage is
unchanged:

```bash
bashunit test tests/ --tag 'db&&slow' --tag api   # (db AND slow) OR api
```

`!` matches untagged tests too — `--tag '!slow'` selects a test with no tags at
all. `--exclude-tag` continues to win over any expression match.

A malformed expression (`'a&&'`, `'&&'`, a bare `'!'`) is rejected with an error
and a non-zero exit, rather than silently selecting nothing — or, in the case of
a trailing `&&`, silently behaving like the term before it.

Use [`--list`](#list) to check what an expression actually selects:

```bash
bashunit --list --tag 'db&&!slow' tests/
```

### Sandbox

> `bashunit test --sandbox [--sandbox-allow <cmd,...>]`

Fails any test that reaches an external command it did not mock, so a typo in a
mock name shows up as a failure instead of a real network call. Builtins and
the commands bashunit itself needs are unaffected. Full description in
[test doubles](/test-doubles#sandbox-mode).

```bash
bashunit tests/ --sandbox
bashunit tests/ --sandbox --sandbox-allow curl,jq
```

### Suites

> `bashunit test --suite <name>`
> `bashunit test --list-suites`

A project with several tiers of tests can name them in `.bashunitrc` instead of
keeping the paths and their flags in a Makefile. See
[named suites](/configuration#named-suites) for the file syntax.

```bash
bashunit --suite unit                 # that suite's paths, with its options
bashunit --suite unit --suite e2e     # the union of both
bashunit --list-suites                # print the defined names, exit 0
```

Precedence, from strongest: **CLI flags → suite settings → global
`.bashunitrc` settings → `.env` → built-in defaults.** A suite's options are
placed before the ones you type, so `--suite unit --no-parallel` runs
sequentially even when the suite asks for `parallel = true`. In the same way an
explicit path argument **replaces** the suite's `paths`, keeping its options:

```bash
bashunit --suite unit tests/unit/assert/basic_test.sh
```

An unknown name exits non-zero and lists the defined suites; a suite section
that is not `key = value` exits non-zero quoting the offending line.

### Output format

> `bashunit test --output <format>`

Send the report to **stdout** in a machine-readable format instead of the
human-readable console rendering. Supported values:

- `text` — the default console rendering, identical to passing no flag.
- `tap` — [TAP version 13](https://testanything.org/tap-version-13-specification.html) for CI/CD integrations.
- `json` — the same document [`--report-json`](#reports) writes to a file.
- `junit` — the same JUnit XML [`--report-junit`](#reports) writes to a file.

For every format but `text` the header, progress, summary, coverage table and
slowest-tests table are suppressed, so stdout holds nothing but the report and
can be piped straight into a parser. Diagnostics keep going to stderr, and the
exit code is the one the run would produce anyway.

`--output` and the file reporters (`--report-json`, `--report-junit`) are
independent: asking for both in the same run prints the document **and** writes
the file.

::: code-group
```bash [JSON]
bashunit tests/ --output json | jq '.tests[] | select(.status == "failed") | .name'
```
```bash [JUnit]
bashunit tests/ --output junit > report.xml
```
```bash [Both sinks]
bashunit tests/ --output json --report-json report.json | jq '.summary'
```
:::

For `tap`, the `TAP version 13` header comes first, each test file is announced via a
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
# Nothing to configure: annotations are automatic on a runner.
bashunit test tests/
```
```bash [JSON]
bashunit test tests/ --report-json report.json
```
:::

The JUnit XML groups results into one `<testsuite>` per test file, each with its own counts, time and timestamp. Every `<testcase>` carries `classname` (the file path in dotted form, e.g. `tests.unit.assert.core_test`), `name`, `file` and `time`; a failure's `message` attribute holds the first informative line of the real assertion message with the full text in the element body, and the test's captured output travels in `<system-out>`. That is the shape Jenkins, GitLab, Azure and `dorny/test-reporter` group and de-duplicate by.

### Markdown summary

> `bashunit test --report-md <file>`

Every other report format targets a machine. This one targets the page a
developer actually looks at first:

```markdown
## bashunit

❌ **3 failed**, 409 passed in 12.3s

| Result | Count |
|--------|-------|
| Passed | 409 |
| Failed | 3 |

## Failures

### Sums two numbers

`tests/math_test.sh:42`

```
✗ Failed: Sums two numbers
    Expected '4'
    but got  '5'
    at tests/math_test.sh:42
```
```

Inside GitHub Actions there is **nothing to configure**: with
`GITHUB_STEP_SUMMARY` set and no explicit path, the summary is appended to it
and renders on the job page. Appended, never written, because that file belongs
to the whole job and truncating it would discard the other steps' output. An
explicit `--report-md` path wins over the step summary.

The report always carries the verdict, a counts table and the failures with
their `file:line` and message. Two sections appear only when the data exists:
coverage percentage after a `--coverage` run, and the slowest tests under
[`--profile`](#profile).

Failure messages are ANSI-stripped and go inside a fence, so they render
verbatim. Test names are escaped, so a name containing `|`, `*`, `_` or a
backtick cannot break the table.

Like the annotations, only the outermost run writes the step summary: a nested
bashunit run inherits `GITHUB_STEP_SUMMARY` and would otherwise append its own
fixtures' results to the parent's job page.

### GitHub Actions annotations

Inside GitHub Actions, bashunit annotates failing tests on the pull request by
itself. No flag, no configuration:

```
::error file=tests/math_test.sh,line=42,title=Sums two numbers::✗ Failed: Sums two numbers%0A    Expected '4'%0A    but got  '5'%0A    at tests/math_test.sh:42
```

GitHub parses workflow commands from the **job log**, so the annotations go to
stdout. They carry the failing test's `file` and `line`, which is what puts them
on the right line of the "Files changed" tab: `::error` for failures, `::warning`
for risky and flaky tests, `::notice` for incomplete ones. Messages are
percent-encoded, so a multi-line failure stays a single annotation.

Detection is `GITHUB_ACTIONS=true`, and `--gha-annotations` overrides it:

| Mode | Behaviour |
|------|-----------|
| `auto` | On inside GitHub Actions, silent everywhere else. The default. |
| `always` | On everywhere, useful for another CI that understands the format |
| `never` | Off, including inside GitHub Actions |

```bash
bashunit test tests/ --gha-annotations never
```

`auto` also stays quiet under a machine `--output` format (`tap`, `json`,
`junit`), whose stdout an annotation line would corrupt.

The separate `--log-gha <file>` flag still writes the same workflow commands to a
file. It is independent of the stdout annotations, so using both does not
duplicate anything in the job log.


The `--report-json` flag writes machine-readable results for scripts, dashboards and bots. Strings are escaped in pure Bash, so no `jq` is needed to produce it. Its schema is:

```json
{
  "summary": { "total": 3, "passed": 2, "failed": 1, "skipped": 0, "incomplete": 0, "flaky": 0, "duration_ms": 42 },
  "tests": [
    { "file": "tests/math_test.sh", "name": "it adds", "status": "passed", "duration_ms": 5, "retries": 0, "message": "" },
    { "file": "tests/math_test.sh", "name": "it divides", "status": "failed", "duration_ms": 3, "retries": 0, "message": "Expected 2 but got 3" }
  ]
}
```

`status` is one of `passed`, `failed`, `skipped`, `incomplete`, `flaky` (`snapshot` and `risky` are also emitted per test and counted as passed in the summary). Per-test rows are complete in both modes; under `--parallel` the row order follows completion order rather than definition order.

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
Time taken: 1.60s

Slowest tests:
  1.20s  test_slow_database_query (tests/integration_test.sh)
  340ms  test_http_client_timeout (tests/http_test.sh)
  12ms   test_parse_config (tests/unit/config_test.sh)
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
`timeout` command and works on Bash 3.0+ (including the default macOS Bash).

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

Tests:      1 passed, 1 flaky, 1 total
```

A test that recovered on retry is counted as [flaky](#flaky-tests) as well as passed, so
the exit code stays `0` unless `--fail-on-flaky` is set.
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

### Snapshot update

> `bashunit test --snapshot-update`

Re-record snapshots: every snapshot assertion whose file already exists is
overwritten with the value this run produced, and reported as a recorded
snapshot instead of a pass. A missing snapshot is written as usual. This
includes default, named and ignore-colors snapshots.

Use it when an output change is deliberate. It replaces deleting snapshot files
by hand — the path is derived from the test file and function name, so a wrong
`rm` is easy and silent: a deleted snapshot is re-recorded on the next run and
never fails.

Scope it with `--filter` to re-record a single test:

```bash
./bashunit --snapshot-update --filter "renders the header" tests/
```

Notes:

- A snapshot containing the placeholder (`::ignore::`, or
  `BASHUNIT_SNAPSHOT_PLACEHOLDER`) is **not** overwritten — the placeholder
  marks output the author chose not to pin, and rewriting would silently drop
  it. bashunit says so on stderr and compares as usual.
- Review the diff afterwards: this rewrites files, so `git diff` is what tells
  you the new output is the output you meant.

### Snapshot report unused

> `bashunit test --snapshot-report-unused`

Lists the snapshot files that no test resolved during the run — the ones left
behind when a test was renamed or deleted, since the filename is derived from
the test file and function name:

```
Unused snapshots (1), no test resolved them:
  tests/snapshots/header_test_sh.test_old_name.snapshot
Nothing was deleted. Delete them yourself once you have checked the tests are gone.
```

Nothing is removed, on purpose: a snapshot deleted by mistake is silently
re-recorded on the next run and never fails again, so an automatic cleanup could
turn a real assertion into one that asserts nothing.

The report only considers snapshots belonging to the test files the run
discovered, so running a single file or directory reports only that scope
instead of everything else in the same `snapshots/` directory. A run that
executes a *subset of the tests* in those files would still be misleading, so
the flag is refused alongside `--filter`, `--tag`, `--exclude-tag`, `--shard`,
`--rerun-failed` and `--changed`.

### Snapshot prune

> `bashunit test --snapshot-prune`

Deletes exactly what the report above lists, printing every path it removes.
It refuses the same partial runs, and additionally deletes nothing when the run
has failures: a test that stopped at an earlier assertion never resolved its
snapshot either, so "unused" there can mean "not run".

See [snapshots](/snapshots#deleting-them).

### No snapshot create

> `bashunit test --no-snapshot-create`

Require every snapshot to exist already: a missing one fails the test instead of
being recorded, and the failure names the resolved path so you know what to
commit.

```
✗ Failed: Renders the header
    Expected './tests/snapshots/header_test_sh.test_renders_the_header.snapshot'
    does not exist; record it with a run without '--no-snapshot-create'
```

This is the CI setting. By default a first run records the snapshot and passes,
so a snapshot that was never committed — or is gitignored, or was lost — is
re-created on the fly and CI stays green while asserting nothing. Record
locally, commit the file, and let CI run with this flag.

The two snapshot flags are opposites and pair up: `--snapshot-update` records
deliberately, `--no-snapshot-create` forbids recording by accident.

### List

> `bashunit test --list` · `bashunit test --dry-run`

Print the tests that *would* run, then exit without running any of them.
`--dry-run` is an alias, for anyone arriving from shellspec.

```bash
./bashunit --list tests/
# tests/unit/assert_test.sh::test_assert_equals
# tests/unit/assert_test.sh::test_assert_contains
# ...
# 412 tests
```

Test ids go to **stdout**, one `path::function` per line; the count goes to
**stderr**, so the list pipes cleanly into `grep`, `fzf` or a CI matrix.

Every selection mechanism applies exactly as it would in a real run —
`--filter`, `--tag`, `--exclude-tag`, `--shard`, `--rerun-failed`, `--changed`,
`--random-order --seed`, and `file::fn` / `file:LINE`. That makes it the way to
answer questions that previously needed a full run per answer:

```bash
# Are the shards balanced?
for i in 1 2 3 4; do
  printf '%s: ' "$i"; ./bashunit --list --shard "$i/4" tests/ | wc -l
done

# Which tests does this filter actually select?
./bashunit --list --filter "snapshot" tests/

# What order will seed 42 use?
./bashunit --list --random-order --seed 42 tests/
```

An empty selection prints nothing and exits **0** — this is a query, not a run,
so a filter matching nothing is an empty answer rather than the "No tests found"
error a real run reports.

Test files are still *sourced* (that is how their functions are discovered), but
no test body and no lifecycle hook runs, and no report file is written.

A test using a `@data_provider` is listed **once**, by function: the id is the
thing you can pass back to `--filter`, while the number of executions it expands
to is a property of the run.

#### JSON output

> `bashunit test --list --list-format json`

```bash
./bashunit --list --list-format json tests/ | jq '.tests[] | select(.tags[]? == "slow")'
```

```json
{
  "count": 2,
  "tests": [
    { "file": "tests/unit/example_test.sh", "function": "test_slow_path",
      "name": "Slow path", "line": 12, "tags": ["slow"] }
  ]
}
```

An unsupported format is rejected rather than silently falling back to `text`.

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

### Repeat

> `bashunit test --repeat <n>`

Run each selected test n times. Where [`--retry`](#test-options) mitigates
flakiness after it has already burned a CI run, `--repeat` goes looking for it:

```bash
bashunit test tests/ --repeat 50 --filter flaky_candidate
```

The test is reported **once**, with the aggregate outcome, and the assertion
counts are those of the deciding iteration rather than the sum of all of them.
A failure names the iteration it happened on:

```
✗ Failed: My test
  (failed on iteration 7 of 50)
```

Iterating stops at the first failing iteration: the test is already going to be
reported failed, and the remaining iterations cannot change that.

**Interaction with `--retry`.** Repeat is the outer loop, retry the inner one.
Each iteration gets its full retry budget before the next iteration starts, so
`--repeat 2 --retry 1` runs the body at most four times, and an iteration that
recovers on its retry lets the next iteration begin.

Notes:

- `--repeat 1` behaves exactly as if the flag were absent.
- `--repeat 0`, a negative value and a non-numeric value are usage errors, not
  silent no-ops.
- Per-test `set_up` / `tear_down` run once per iteration; `set_up_before_script`
  runs once for the file, as always.
- Works under `--parallel`: each worker repeats its own test.

::: code-group
```bash [Hammer one suspect test]
bashunit test --repeat 50 --filter flaky_candidate
```
```bash [Env variable]
BASHUNIT_REPEAT=10 bashunit test tests/
```
:::

### Flaky tests

> `bashunit test --retry 2 --fail-on-flaky`

A test that failed and then passed on a retry is **flaky**: it passed, so the
run stays green, but the summary says so.

```
Tests:      12 passed, 1 flaky, 12 total
```

The flaky count is a facet of `passed`, not a seventh outcome, which is why it
is not added to the total. Without it a retried failure is indistinguishable
from a clean run, and flakiness never gets triaged.

Every report carries the status, along with the **first attempt's** failure
message (the diagnostic value, otherwise discarded when the retry overwrites
it) and the retry count:

| Format | Output |
|--------|--------|
| JUnit | `<flakyFailure>` inside the `<testcase>`, rendered natively by Jenkins and GitLab. Not counted in `failures` |
| TAP | `ok N - name # TODO flaky (retried 1/2)` |
| JSON | `"status": "flaky"`, `"retries": N`, plus a `flaky` key in the summary |
| HTML | its own row styling |
| GitHub Actions | a `::warning` annotation |

Add `--fail-on-flaky` to turn a flaky run red, mirroring
[`--fail-on-risky`](#test-options):

```bash
bashunit test tests/ --retry 2 --fail-on-flaky
```

Notes:

- `--retry 0` (the default) can never produce a flaky result: nothing is retried.
- Counters are correct under `--parallel`; the retry count crosses the fork in
  the per-test payload.
- Flaky never changes the exit code on its own.

::: code-group
```bash [Surface flakiness in CI]
bashunit test --retry 2 --report-junit report.xml
```
```bash [Env variable]
BASHUNIT_FAIL_ON_FLAKY=true bashunit test tests/ --retry 2
```
:::

### Order by

> `bashunit test --order-by <mode>`

Choose the execution order. Three modes:

| Mode | Order |
|------|-------|
| `defined` | Definition order. The default. |
| `defects` | Tests that failed on the last recorded run first, then everything else. |
| `random` | Shuffled, the same mode `--random-order` selects. |

`defects` reads the same `.bashunit/last-failed` cache
[`--rerun-failed`](#rerun-failed) writes, but it **reorders instead of
narrowing**: the whole suite still runs. Paired with `--stop-on-failure`, that
turns the pre-push check from minutes into seconds, because the tests most
likely to fail run first.

```bash
bashunit test tests/ --order-by defects --stop-on-failure
```

Notes:

- With no cache file the order falls back to `defined`, silently.
- `--order-by random` and `--random-order` are the same mode, and `--seed`
  applies to both.
- Combining it with `--rerun-failed` is allowed: `--rerun-failed` still narrows
  the selection, `--order-by` only orders what survives.
- Under `--parallel` the recorded failures are dispatched first.

::: code-group
```bash [Fail fast on known-bad tests]
bashunit test --order-by defects --stop-on-failure
```
```bash [Env variable]
BASHUNIT_ORDER_BY=defects bashunit test tests/
```
:::

### Changed

> `bashunit test --changed [<ref>]`

Run only the test files your branch touched. Where
[`--rerun-failed`](#rerun-failed) needs a previous red run, `--changed` needs
only git, so it works on the first run of a fresh branch.

```bash
bashunit test tests/ --changed          # against origin/HEAD, then HEAD
bashunit test tests/ --changed main     # against main
bashunit test tests/ --changed HEAD~3   # against three commits ago
```

The selection is every test file git reports as touched since `<ref>`, which
merges three sources: the commit range `<ref>...HEAD`, the staged and unstaged
edits on top of `HEAD`, and untracked new files. Deleted test files are dropped,
and a rename selects its new path only.

Notes:

- Composes with `--filter`/`--tag` — both apply (intersection).
- The ref argument is optional, so a value that is also an existing path is read
  as the run's path, not as a ref. Write `--changed ./main` or set
  `BASHUNIT_CHANGED_REF` when you mean the ref.
- Outside a git work tree, or with a ref that does not resolve, the run exits
  non-zero with a message rather than quietly running everything.
- No changed test file is not an error in itself: the run reports `No tests
  found` and exits `1`, the same as any other empty selection.
- Source changes are not mapped to the tests that cover them. Only test files
  are selected.

::: code-group
```bash [Fastest branch loop]
bashunit test --changed main
```
```bash [Env variables]
BASHUNIT_CHANGED=true BASHUNIT_CHANGED_REF=main bashunit test tests/
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
bashunit | Tests: 10
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
| `--coverage-exclude <patterns>` | Comma-separated patterns to exclude (default: `tests/*,vendor/*,*_test.sh,*Test.sh`) |
| `--coverage-report [file]`      | LCOV output file path (default: `coverage/lcov.info`)                       |
| `--coverage-report-html [dir]`  | Generate HTML report (default: `coverage/html`)                             |
| `--coverage-report-cobertura [file]` | Cobertura XML for GitLab, Azure and Jenkins (default: `coverage/cobertura.xml`) |
| `--coverage-min <percent>`      | Minimum coverage percentage; fails if below                                 |
| `--coverage-diff <ref>`         | Report only the lines changed since `<ref>`                                 |
| `--no-coverage-report`          | Show console report only, don't generate LCOV file                          |

Both `--coverage-report` and `--coverage-report-html` take an optional value and fall back
to their default path when the next argument is another flag or absent. A value cannot be
told apart from a test path, so write the path before them: `bashunit tests/ --coverage-report`.


::: tip
Coverage works with parallel execution (`-p`). Each worker tracks coverage independently, and results are aggregated before reporting.
:::

### Cobertura XML

> `bashunit test --coverage --coverage-report-cobertura [file]`

LCOV feeds Codecov and Coveralls; Cobertura is the format the CI platforms with built-in coverage UIs consume: GitLab merge-request coverage visualisation, Azure DevOps `PublishCodeCoverageResults` and the Jenkins Coverage plugin. The report groups files into packages by directory, emits per-line hits with `condition-coverage` on branch lines, and keeps `filename` attributes repository-relative — GitLab silently shows nothing for absolute paths. It coexists with the LCOV and HTML reports in a single run.

```bash
bashunit test tests/ --coverage --coverage-report-cobertura
```

```yaml
# .gitlab-ci.yml
test:
  script: bashunit test tests/ --coverage --coverage-report-cobertura
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura.xml
```

### Diff coverage

> `bashunit test --coverage --coverage-diff <base-ref>`

Restrict the console report to the lines changed since a base ref, so a pull request is
judged on the code it touched. See [Coverage > Diff coverage](/coverage#diff-coverage).

## assert

> `bashunit assert <function> [args...]`
>
> `bashunit assert "<command>" <assertion> <arg> [<assertion> <arg>...]`

Run assertions without creating a test file. The function name works with or without the
`assert_` prefix.

::: code-group
```bash [Single assertion]
bashunit assert equals "foo" "foo"
bashunit assert exit_code 0 "echo 'success'"
```
```bash [Several assertions on one command]
bashunit assert "./my_script.sh" exit_code "0" contains "success" not_contains "error"
```
:::

See [Standalone](/standalone) for the full story. `bashunit test --assert` is the
deprecated form of the first mode.

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
| `--no-color` | Disable colored output (honors `NO_COLOR`) |
| `-h, --help` | Show the bench help |

## watch

> `bashunit watch [path] [test-options]`

Dedicated watch subcommand that uses **OS file-event notifications** (no
polling) to re-run tests as soon as a `.sh` file changes. Any option accepted
by `bashunit test` is also accepted here, **but put the path first**: apart from
`-f/--filter`, an option's value is otherwise taken as the watch path, so
`bashunit watch --tag slow` watches a directory named `slow`. Write
`bashunit watch tests/ --tag slow`.

When neither `inotifywait` nor `fswatch` is installed, it no longer fails:
it falls back to a **pure-shell polling loop** and prints a short notice.
Polling checks every `BASHUNIT_WATCH_INTERVAL` seconds (default `2`) using
`find -newer`, so it detects created and modified `.sh` files; deleted files
are not detected on the fallback path. Install one of the tools above for
instant, event-driven triggers.

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

::: tip Recommended for instant triggers
- **Linux:** `inotifywait` (`sudo apt install inotify-tools`)
- **macOS:** `fswatch` (`brew install fswatch`)

Without either tool, bashunit degrades to polling (see above) instead of
failing. The portable [`-w/--watch`](#watch-mode) flag on `bashunit test` also polls, but
on a fixed 1-second loop: `BASHUNIT_WATCH_INTERVAL` applies to this subcommand's fallback
only.
:::

## doc

> `bashunit doc [options] [filter]`

Display documentation for assertion functions.

| Option | Description |
|--------|-------------|
| `--custom` | Show only the assertions your project defines |
| `-e, --env, --boot <file>` | Load a bootstrap file defining custom assertions |

With a bootstrap loaded, `bashunit doc` appends a **Custom assertions** section
rendering the comment block above each of your own `assert_*` functions. See
[Custom asserts](/custom-asserts).

::: code-group
```bash [Examples]
# Show all assertions
bashunit doc

# Filter by name
bashunit doc equals

# Show file-related assertions
bashunit doc file

# Show only your project's assertions
bashunit doc --custom --boot tests/bootstrap.sh
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
> Created tests/bootstrap.sh
> Created tests/example_test.sh
> Created .github/workflows/tests.yml
> bashunit initialized in tests
```
:::

Creates:
- `tests/bootstrap.sh` - Setup file for test configuration
- `tests/example_test.sh` - Sample test file to get started
- `.github/workflows/tests.yml` - CI workflow using the official action
- `.env` with `BASHUNIT_BOOTSTRAP=tests/bootstrap.sh`

An existing `BASHUNIT_BOOTSTRAP=` line in `.env` is commented out first, so the new value
takes effect.

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
> bashunit upgraded successfully to latest version <x.y.z>
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

## Invalid input

bashunit validates its options before running anything and exits non-zero on a bad one.
It never silently ignores an option it does not understand — a typo would otherwise
produce a passing run that did something other than what you asked.

### Unknown options

An argument that looks like an option but matches nothing is an error, not a test path:

```bash
bashunit --parralel tests/
```
```[Output]
Error: unknown option '--parralel'. Run 'bashunit test --help' to list the available options.
```

Without this, `--parralel` ran the suite **sequentially** and still exited `0`, and
`--filterr foo` swallowed both the flag and its value and ran the whole suite.

### Invalid values

`--jobs`, `--retry`, `--test-timeout`, `--coverage-min` and `--seed` require a
non-negative integer; `--repeat` requires an integer of at least `1`; `--output` accepts
only `text`, `tap`, `json` and `junit`; `--shard` requires `<index>/<total>`;
and `--gha-annotations`, `--order-by` and
`--list-format` accept only their listed modes:

```bash
bashunit --jobs abc tests/
```
```[Output]
Error: BASHUNIT_PARALLEL_JOBS (--jobs) must be a non-negative integer, got 'abc'.
```

The same check applies to the equivalent `BASHUNIT_*` environment variables, including
the env-only `BASHUNIT_COVERAGE_THRESHOLD_LOW` / `BASHUNIT_COVERAGE_THRESHOLD_HIGH`.

### Unusable paths

The bootstrap file must be readable, and every report destination must be writable.
Both are checked **before** the suite runs, so a bad path fails immediately rather than
after a green run has already reported success:

```bash
bashunit --env missing.sh tests/
bashunit --report-json /nope/dir/out.json tests/
```
```[Output]
Error: cannot read the bootstrap file: 'missing.sh'.
Error: BASHUNIT_REPORT_JSON cannot be written: '/nope/dir/out.json'.
```

::: tip
A `0` exit code means nothing *failed* — a run that was entirely skipped, incomplete or
risky also exits `0`. Add [`--fail-on-risky`](#test-options) or read the counts from
[`--report-json`](#reports).
:::

## Related

- [Configuration](/configuration) — set the same options via env vars and config files
- [Test files](/test-files) — how bashunit discovers and names test files
- [Coverage](/coverage) — code coverage tracking
- [Benchmarks](/benchmarks) — performance benchmarks with `bashunit bench`

<script setup>
import pkg from '../package.json'
</script>
- [Standalone](/standalone) — run assertions without a test file
