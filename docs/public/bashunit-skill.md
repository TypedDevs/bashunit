---
name: bashunit
description: Write and run tests for bash scripts with bashunit. Use when adding or fixing tests for shell code, when a bashunit run fails, or when asked to raise coverage of a bash script. Covers the assertion catalogue, the fast edit-run loop, and the API traps that produce silently-passing tests.
---

# bashunit

A testing framework for bash. Tests are plain bash functions; there is no runtime to
install and a run starts in tens of milliseconds.

Full docs: https://bashunit.com — machine-readable at https://bashunit.com/llms-full.txt

## Layout

Files end in `_test.sh`, functions start with `test_`:

```bash
#!/usr/bin/env bash

function set_up() {           # before each test (optional)
  TARGET_DIR="$(temp_dir)"
}

function test_it_writes_the_header() {
  create_report "$TARGET_DIR/out.txt"

  assert_file_contains "$TARGET_DIR/out.txt" "# Report"
}
```

Lifecycle hooks: `set_up_before_script`, `set_up`, `tear_down`, `tear_down_after_script`.

## The loop

```bash
bashunit tests/                                # everything
bashunit --filter "writes the header" tests/   # one test, by name
bashunit --rerun-failed tests/                 # only what failed last run
bashunit --failures-only --no-progress tests/  # quiet output for a transcript
bashunit --report-json out.json tests/         # structured results to parse
```

Work the cycle: run once, then loop on `--rerun-failed` until nothing fails. Do not
re-run the whole suite after every edit.

Exit code is 0 only when everything passed.

## Assertions

There are 66. `bashunit doc <filter>` prints them locally; the catalogue is at
https://bashunit.com/assertions. **Do not invent names** — a wrong name is a runtime
error, not a failed assertion.

The ones worth memorising:

- Equality: `assert_same` (exact), `assert_equals` (normalizing), `assert_not_same`
- Strings: `assert_contains`, `assert_not_contains`, `assert_matches`,
  `assert_string_starts_with`, `assert_string_ends_with`, `assert_empty`, `assert_not_empty`
- Numbers: `assert_greater_than`, `assert_less_than`, `assert_within_delta`
- Exit codes: `assert_successful_code`, `assert_general_error`, `assert_exit_code`,
  `assert_command_not_found`
- Files: `assert_file_exists`, `assert_file_contains`, `assert_is_file_empty`,
  `assert_directory_exists`, `assert_file_permissions`
- Arrays: `assert_array_contains`, `assert_array_length`, `assert_arrays_equal`
- JSON: `assert_json_equals`, `assert_json_contains`, `assert_json_key_exists`
- Snapshots: `assert_match_snapshot`

Prefer `assert_same` over `assert_equals` unless you specifically want normalization.

## Traps that produce silently-passing tests

**Exit-code assertions take the code as the third argument.** This is the single most
common mistake:

```bash
local ec=0
my_command || ec=$?

assert_general_error "" "" "$ec"     # correct
assert_general_error "$ec"           # WRONG — $1 is ignored, $? is read instead
```

With no arguments they read `$?` directly, which only works immediately after the
command.

**Capture exit codes before asserting.** Under `--strict` (or a caller's `set -e`) a
failing command ends the test before your assertion runs:

```bash
local ec=0
failing_command || ec=$?      # correct
local out; out=$(failing_command)   # WRONG under set -e
```

**A test with no assertions passes.** Always assert something. Run
`bashunit --fail-on-risky tests/` to turn that into a failure.

**Use `$(temp_file)` and `$(temp_dir)`** for scratch paths. They are cleaned up
automatically and are safe under `--parallel`.

**Do not delete shared fixtures in `tear_down_after_script`.** Under `--parallel` that
file's tests may still be running; they crash and disappear from the totals without
reporting a failure.

**No network calls.** Mock the command instead.

## Test doubles

```bash
mock curl echo "fixed response"      # replace behaviour
spy send_email                       # record calls, keep behaviour
assert_have_been_called_times 2 send_email
assert_have_been_called_with "--to a@b.c" send_email
```

## Data providers

```bash
function data_provider_sums() {
  echo "1 2 3"
  echo "0 0 0"
}

# @data_provider data_provider_sums
function test_add() {
  assert_same "$3" "$(add "$1" "$2")"
}
```

## Portability

bashunit runs on Bash 3.0+, including the bash 3.2 that ships with macOS. If the code
under test must run there too, avoid `declare -A`, `${var,,}`, `${array[-1]}` and `&>>`
in both the code and the tests.

## Verifying your own work

```bash
bashunit --fail-on-risky tests/   # assertion-free tests fail
bashunit --random-order tests/    # catches order dependence
bashunit --strict tests/          # set -euo pipefail
bashunit --parallel tests/        # catches shared-state leaks
```

Before claiming a test is done, confirm it fails when the behaviour it covers is broken.
A test that passes against both the fixed and the broken implementation is testing
nothing.
