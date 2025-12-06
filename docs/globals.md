# Globals

You can use this list of global functions that exists to primarily to improve your developer experience.

::: warning
If you `source` a script in your tests that defines a function with the same
name as one of these globals (like `log`), your script will override bashunit's
version. To keep using bashunit's implementation, copy the original function
under a new name before sourcing and call that copy explicitly:

```bash
eval "bashunit_$(declare -f log)"
source script.sh
bashunit_log "this will be logged now"
```

The `eval` line duplicates `log` as `bashunit_log`, allowing you to call
`bashunit_log` even after `script.sh` redefines `log`.
:::

## log

Write into the `BASHUNIT_DEV_LOG` a log message. The log line records the source file and line number for easier debugging.

> See: [Dev log](/configuration#dev-log)

```bash
log "hello" "world" # default level: info
log "info" "hello" "world"
log "debug" "hello" "world"
log "warning" "hello" "world"
log "critical" "hello" "world"
log "error" "hello" "world"
```
Internal messages from bashunit include the `[INTERNAL]` prefix so you can easily spot them. You can enable them with `BASHUNIT_INTERNAL_LOG=true|false`.

## bashunit::current_dir

> `bashunit::current_dir`: Gets the current directory name.

## bashunit::current_filename

> `bashunit::current_filename`: Gets the current filename.

## bashunit::caller_filename

> `bashunit::caller_filename`: Gets the caller filename.

## current_timestamp

> `current_timestamp`: Gets the caller filename.

## bashunit::random_str

> `bashunit::random_str <?length>`: generate a random string

## bashunit::temp_file

> `bashunit::temp_file <?prefix>`: creates a temporal file

The file is automatically deleted when bashunit completes.

## bashunit::temp_dir

> `bashunit::temp_dir <?prefix>`: creates a temporal directory

The directory is automatically deleted when bashunit completes.

## bashunit::is_command_available

> `bashunit::is_command_available`: Checks if command is available
