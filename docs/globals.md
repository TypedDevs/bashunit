# Globals

You can use this list of global functions that exists to primarily to improve your developer experience.


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

## current_dir

> `current_dir`: Gets the current directory name.

## current_filename

> `current_filename`: Gets the current filename.

## caller_filename

> `caller_filename`: Gets the caller filename.

## current_timestamp

> `current_timestamp`: Gets the caller filename.

## random_str

> `random_str <?length>`: generate a random string

## temp_file

> `temp_file <?prefix>`: creates a temporal file

## temp_dir

> `temp_dir <?prefix>`: creates a temporal directory

## is_command_available

> `is_command_available`: Checks if command is available
