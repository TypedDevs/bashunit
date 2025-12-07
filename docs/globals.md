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

> `bashunit::is_command_available`: Checks if command is available
