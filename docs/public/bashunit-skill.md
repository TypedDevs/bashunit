---
name: bashunit
description: Write and run tests for bash scripts with bashunit. Use when adding or fixing tests for shell code, when a bashunit run fails, or when asked to raise coverage of a bash script. Covers loading the code under test, the assertion catalogue, the fast edit-run loop, and the API traps that produce silently-passing tests.
---

# bashunit

A testing framework for bash. Tests are plain bash functions; there is no runtime to
install and a run starts in tens of milliseconds.

Full docs: https://bashunit.com — machine-readable at https://bashunit.com/llms-full.txt

## Anatomy of a test file

Files end in `_test.sh`, functions start with `test_`. **Load the code under test
yourself** — bashunit does not do it for you:

```bash
#!/usr/bin/env bash

function set_up() {
  source "src/calculator.sh"      # relative to where you RUN bashunit
}

function test_add_two_positive_numbers() {
  assert_same "5" "$(add 2 3)"
}
```

Run it from the project root: `bashunit tests/`. If the suite must work from any
directory, anchor the path to the test file instead:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/../src/calculator.sh"
```

Testing a whole script rather than a function? Execute it and assert on the result:

```bash
function test_script_rejects_a_missing_argument() {
  local output ec=0
  output=$(./src/deploy.sh 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "usage:" "$output"
}
```

Lifecycle hooks: `set_up_before_script` (once per file), `set_up` (per test),
`tear_down` (per test), `tear_down_after_script` (once per file).

## The loop

```bash
bashunit tests/                                # everything
bashunit --filter add_two_positive tests/      # one test — matches the FUNCTION name
bashunit --rerun-failed tests/                 # only what failed last run
bashunit --failures-only --no-progress tests/  # quiet output for a transcript
bashunit --test-timeout 10 tests/              # kill a test that hangs
```

Run once, then loop on `--rerun-failed` until nothing fails. Do not re-run the whole
suite after every edit.

Set `--test-timeout` on any unattended run. A generated `while` loop that never
terminates otherwise hangs until *your* timeout fires, and the transcript shows nothing.

`--rerun-failed` reads `.bashunit/last-failed` (add it to `.gitignore`). When that cache
is empty it falls back to running everything — so the run that suddenly grows back to
the full suite is the signal you are green, not a bug.

`--filter` matches the **function name** (`test_add_two_positive_numbers`), not the
humanized title in the report, so a filter containing spaces silently matches nothing
and reports `0 total`.

## Read results, do not scrape them

```bash
bashunit --report-json out.json tests/   # summary + one entry per test
bashunit --output tap tests/             # TAP 13 on stdout
```

`--report-json` gives you the failure message and the exact source line, which is what
you need to fix the test — parse it instead of reading the terminal rendering:

```json
{
  "summary": { "total": 2, "passed": 1, "failed": 1, "skipped": 0, "incomplete": 0 },
  "tests": [
    { "file": "tests/math_test.sh", "name": "Fails", "status": "failed",
      "message": "✗ Failed: Fails\n    Expected 'a'\n    but got  'b'\n    at tests/math_test.sh:7" }
  ]
}
```

**A `0` exit code does not mean everything passed.** It means nothing *failed*: a run
that is entirely skipped, incomplete, risky, or that only recorded new snapshots still
exits `0`. Compare `summary.passed` against `summary.total`, or add `--fail-on-risky`.

## The namespace rule

**`assert_*` is bare. Every helper needs the `bashunit::` prefix.** The unprefixed name
is not an alias — it is a runtime failure, and it is the single most common mistake:

```bash
d="$(bashunit::temp_dir)"       # correct   | temp_dir        -> command not found
f="$(bashunit::temp_file)"      # correct   | temp_file       -> command not found
bashunit::spy send_email        # correct   | spy             -> command not found
bashunit::mock date echo "x"    # correct   | mock            -> command not found
bashunit::skip "reason"         # correct   | skip            -> command not found
bashunit::set_test_title "..."  # correct   | set_test_title  -> command not found
bashunit::log "msg"             # correct   | log             -> on macOS this silently
                                #           |                    runs /usr/bin/log
```

Use `$(bashunit::temp_file)` / `$(bashunit::temp_dir)` for all scratch paths: they are
cleaned up automatically and are safe under `--parallel`.

## Assertions

`bashunit doc` prints the full catalogue (71 assertions) locally; `bashunit doc contains`
filters it. The same list is at https://bashunit.com/assertions. **Do not invent names**
— a wrong name is a runtime error, not a failed assertion.

- Equality: `assert_same`, `assert_not_same`, `assert_equals`, `assert_not_equals`
- Strings: `assert_contains`, `assert_not_contains`, `assert_matches`,
  `assert_string_starts_with`, `assert_string_ends_with`, `assert_empty`, `assert_not_empty`
- Numbers: `assert_greater_than`, `assert_less_than`, `assert_within_delta`
- Exit codes: `assert_successful_code`, `assert_general_error`, `assert_exit_code`,
  `assert_command_not_found`
- Files: `assert_file_exists`, `assert_file_contains`, `assert_is_file_empty`,
  `assert_directory_exists`, `assert_file_permissions`
- Arrays: `assert_array_contains`, `assert_array_length`, `assert_arrays_equal`
- JSON: `assert_json_equals`, `assert_json_contains`, `assert_json_key_exists`
- Snapshots: `assert_match_snapshot`, `assert_match_snapshot_ignore_colors`
- Spies: `assert_have_been_called`, `assert_not_called`, `assert_have_been_called_with`,
  `assert_have_been_called_with_any`, `assert_have_been_called_with_args`,
  `assert_have_been_called_times`, `assert_have_been_called_nth_with`

`assert_same` compares exactly. `assert_equals` first strips ANSI colour codes, tabs and
newlines — useful for asserting on coloured CLI output, misleading everywhere else.
**Default to `assert_same`**; reach for `assert_equals` only when you mean to ignore
formatting.

## Traps that produce silently-passing tests

**Exit-code assertions take the code as the third argument:**

```bash
local ec=0
my_command || ec=$?

assert_general_error "" "" "$ec"     # correct
assert_general_error "$ec"           # WRONG — $1 is ignored, $? is read instead
```

With no arguments they read `$?`, which only works immediately after the command.

**Capture exit codes; never let a failing command run bare.** Under `--strict` (or a
caller's `set -e`) it ends the test before your assertion runs:

```bash
local ec=0
failing_command || ec=$?            # correct
local out; out=$(failing_command)   # WRONG under set -e
```

**Spies do not survive across tests, and a call assertion on an unregistered name fails**
with `was never registered as a spy` (it used to report zero calls, so `assert_not_called`
with a typo passed while asserting nothing). Register the spy in the test that asserts on it.

**`assert_have_been_called_with` compares one call only** — the last, or the one at the
optional trailing index. Adding an unrelated later call breaks it. When the requirement is
"this happened at some point", use `assert_have_been_called_with_any`.

**`assert_have_been_called_with` joins arguments with spaces**, so it cannot see argument
boundaries: `touch "a b"` also satisfies `assert_have_been_called_with touch "a" "b"`. When
an argument may contain a space — any path — use `assert_have_been_called_with_args`, which
compares argument by argument.

**A test with no assertions passes.** Always assert something; `--fail-on-risky` turns
that into a failure.

**Do not delete shared fixtures in `tear_down_after_script`.** Under `--parallel` that
file's tests may still be running; they crash and vanish from the totals without
reporting a failure. Create per-test fixtures with `bashunit::temp_dir` instead and add
no teardown.

**Re-record snapshots with `--snapshot-update`** (scope it: `--snapshot-update --filter
"my test"`), never by deleting snapshot files. A missing snapshot is written silently and
passes, so a wrong `rm` converts a real assertion into a rubber stamp with no error. Read
`git diff` after re-recording. A snapshot containing the placeholder is left alone and
reported on stderr, because rewriting it would drop the part the author chose not to pin.

**No network calls.** Mock the command.

## Test doubles

```bash
bashunit::mock date echo "2024-05-01"   # replace behaviour
bashunit::mock uname <<< "Linux"        # heredoc form ignores the call's arguments
bashunit::mock curl 1                   # all-digits arg = exit code, no output (as for spy)
bashunit::spy send_email                # record calls, keep behaviour
bashunit::unmock date                   # restore the real command for the rest of this test

assert_have_been_called send_email
assert_have_been_called_times 2 send_email               # count FIRST, then spy
assert_have_been_called_with send_email "--to a@b.c"     # spy FIRST, then expected
assert_have_been_called_with send_email "--to a@b.c" 1   # ...of call #1
assert_have_been_called_nth_with 1 send_email "--to a@b.c"
assert_have_been_called_with_any send_email "--to a@b.c"     # any call, not just the last
assert_have_been_called_with_args send_email "--to" "a@b.c"  # boundary-exact, no index
```

The argument order is inconsistent between `_times` and `_with`. A swapped pair *fails
the assertion* rather than erroring, so it reads like a real defect — check this list
rather than guessing.

A double declared inside a test is removed when that test ends, so never unmock in
`tear_down` — it is noise. One declared in `set_up_before_script` lives for the whole
file; `bashunit::unmock` on it only suspends it for the current test, because each test
runs in its own subshell.

## Data providers

Each line of the provider becomes one run, split on whitespace into `$1`, `$2`, …:

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

## Selecting and annotating tests

```bash
# @tag slow
function test_heavy_computation() { ...; }
```

```bash
bashunit tests/ --tag slow            # only tagged tests (repeatable, OR)
bashunit tests/ --exclude-tag slow    # everything else (exclusion wins)
```

Inside a test:

```bash
bashunit::skip "not supported on this platform" && return   # conditional skip
bashunit::todo "needs a fixture for the error path"         # mark incomplete
bashunit::set_test_title "handles a malformed header"       # display name only
```

## Portability

bashunit runs on Bash 3.0+, including the bash 3.2 that ships with macOS. If the code
under test must run there too, avoid `declare -A`, `${var,,}`, `${array[-1]}` and `&>>`
in both the code and the tests.

## Verifying your own work

```bash
bashunit --fail-on-risky tests/   # assertion-free tests fail
bashunit --random-order tests/    # catches order dependence (--seed N to reproduce)
bashunit --strict tests/          # set -euo pipefail
bashunit --parallel tests/        # catches shared-state leaks
```

Before claiming a test is done, confirm it fails when the behaviour it covers is broken.
A test that passes against both the fixed and the broken implementation is testing
nothing.
