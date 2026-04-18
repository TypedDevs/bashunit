# Globals

You can use this list of global functions that exists to primarily to improve your developer experience.

All helper functions use the `bashunit::` namespace prefix to prevent naming collisions with your own code.

## bashunit::log

Write into the `BASHUNIT_DEV_LOG` a log message. The log line records the source file and line number for easier debugging.

> See: [Dev log](/configuration#dev-log)

```bash
bashunit::log "hello" "world" # default level: info
bashunit::log "info" "hello" "world"
bashunit::log "debug" "hello" "world"
bashunit::log "warning" "hello" "world"
bashunit::log "critical" "hello" "world"
bashunit::log "error" "hello" "world"
```
Internal messages from bashunit include the `[INTERNAL]` prefix so you can easily spot them. You can enable them with `BASHUNIT_INTERNAL_LOG=true|false`.

## bashunit::current_dir

> `bashunit::current_dir`: Gets the current directory name.

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

## Custom assertion helpers

These helpers are intended for building [custom assertions](/custom-asserts).

- `bashunit::assertion_passed` — Mark the current assertion as passed.
- `bashunit::assertion_failed <expected> <actual> <?label>` — Mark the current
  assertion as failed and print a failure report.
- `bashunit::fail <?message>` — Fail the current test with an optional message.

See [Custom asserts](/custom-asserts) for full examples.

## Test doubles

The `bashunit::spy`, `bashunit::mock`, and `bashunit::unmock` helpers are
documented in [Test doubles](/test-doubles).
