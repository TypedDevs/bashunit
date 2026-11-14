---
description: "Reference of bashunit global helpers for logging, temporary files, test metadata and custom assertions."
---

# Globals

Global helpers use the `bashunit::` namespace prefix to prevent naming collisions with your code.

## bashunit::log

Write a message to `BASHUNIT_DEV_LOG`, including the source file and line number.

> See: [Dev log](/configuration#dev-log)

```bash
bashunit::log "hello" "world" # default level: info
bashunit::log "info" "hello" "world"
bashunit::log "debug" "hello" "world"
bashunit::log "warning" "hello" "world"
bashunit::log "critical" "hello" "world"
bashunit::log "error" "hello" "world"
```
Internal messages use the `[INTERNAL]` prefix. Control them with `BASHUNIT_INTERNAL_LOG=true|false`.

## bashunit::current_dir

> `bashunit::current_dir`: Gets the directory of the file that calls it.

bashunit runs every test file from the directory where you started it, so a relative path such as `./lib.sh` depends on where you ran the command. Call `bashunit::current_dir` from a test file to work relative to that file instead. It works at file level and inside tests.

The path follows how you passed the test path: `tests/unit` for `bashunit tests/`, `./tests/unit` for `bashunit ./tests/`, and an absolute path for an absolute argument. A relative result is relative to the directory where bashunit started.

To load a file or read a fixture that sits next to the test:

```bash
source "$(bashunit::current_dir)/lib.sh"

function test_greeting() {
  assert_file_exists "$(bashunit::current_dir)/fixtures/input.txt"
  assert_same "hello" "$(greeting)"
}
```

This is the recommended recipe. You can also run the whole file from its own directory, by changing into it once before the tests:

```bash
function set_up_before_script() {
  cd "$(bashunit::current_dir)" || return
}

function test_fixture_is_next_to_the_test() {
  assert_file_exists ./fixtures/input.txt
}
```

bashunit returns to the original directory after each file, so the `cd` does not carry over to the next test file.

::: warning Limits of the `cd` recipe
Some features resolve paths against the directory where bashunit started, so they break after the `cd`:

- **Snapshots** are stored in a nested folder such as `tests/unit/tests/unit/snapshots/`. A snapshot that already exists is not found, so the first run records a new one instead of comparing. Do not use the `cd` recipe in files that call `assert_match_snapshot`.
- **Coverage** stops counting the files the test sources.
- `bashunit::current_dir` still returns the original relative path, so after the `cd` use `./...` paths instead.
:::

## bashunit::current_filename

> `bashunit::current_filename`: Gets the current filename.

## bashunit::caller_filename

> `bashunit::caller_filename`: Gets the caller filename.

## bashunit::caller_line

> `bashunit::caller_line`: Gets the line number of the caller.

Useful inside custom assertions to report the line that triggered the failure.

## bashunit::current_timestamp

> `bashunit::current_timestamp`: Gets the current timestamp.

## bashunit::random_str

> `bashunit::random_str <?length>`: generate a random string

## bashunit::temp_file

> `bashunit::temp_file <?prefix>`: creates a temporal file

The file is automatically deleted when bashunit completes.

## bashunit::temp_dir

> `bashunit::temp_dir <?prefix>`: creates a temporal directory

The directory is automatically deleted when bashunit completes.

Temporary files and directories live under `$TMPDIR/bashunit`. When `TMPDIR` is not set, bashunit uses `/tmp/bashunit-<user id>/bashunit`. It creates these directories so only you can read them, and stops with an error if one is a link, belongs to another user, or lets another user write to it.

## bashunit::is_command_available

> `bashunit::is_command_available <command>`: Checks if a command is available in `PATH`.

Returns `0` when the command is found, `1` otherwise.

```bash
if bashunit::is_command_available jq; then
  # jq-based assertions
fi
```

## bashunit::print_line

> `bashunit::print_line <?length> <?char>`: Prints a horizontal separator.

Defaults to 70 characters of `-`. Both arguments are optional.

```bash
bashunit::print_line          # 70 dashes
bashunit::print_line 40 '='   # 40 equals signs
```

## Conditional skips

These mark the test skipped **and end it**, so no `&& return` is needed. See
[Skipping and incomplete tests](/skipping-incomplete#conditional-skips).

- `bashunit::skip_if <condition> [reason]` — skip when the condition succeeds.
- `bashunit::skip_unless <condition> [reason]` — skip when it fails.
- `bashunit::skip_unless_command <cmd> [cmd...]` — skip when a command is missing.
- `bashunit::skip_on <windows|macos|linux> [reason]` — skip on that platform.

## Custom assertion helpers

These helpers are intended for building [custom assertions](/custom-asserts).

- `bashunit::assert_that <expected> <actual> <cmd> [args...]` — Run `cmd` and mark
  the assertion passed or failed accordingly, in a single call.
- `bashunit::assert_once <?label> <?actual>` — Declare that the calling custom
  assertion counts and reports once, whatever it asserts internally.
- `bashunit::assertion_passed` — Mark the current assertion as passed.
- `bashunit::assertion_failed <expected> <actual> <?failure_condition_message> <?label>`
  — Mark the current assertion as failed and print a failure report. `label`
  names the assertion in that report, defaulting to the test function name.
- `bashunit::fail <?message>` — Fail the current test with an optional message.

See [Custom asserts](/custom-asserts) for full examples.

## Test doubles

The `bashunit::spy`, `bashunit::mock`, and `bashunit::unmock` helpers are
documented in [Test doubles](/test-doubles).

## Related

- [Custom asserts](/custom-asserts) — build your own assertions with these helpers
- [Assertions](/assertions) — the built-in assertion reference
- [Test doubles](/test-doubles) — spies and mocks
- [Configuration](/configuration) — configure the dev log used by `bashunit::log`
