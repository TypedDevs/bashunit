# Globals

You can use this list of global/common functions that exists to primarily to improve your developer experience.

> Using the existing tests as documentation.

## current_dir

```bash
function test_globals_current_dir() {
  assert_same "tests/unit" "$(current_dir)"
}
```

## current_filename

```bash
function test_globals_current_filename() {
  assert_same "globals_test.sh" "$(current_filename)"
}
```

## current_timestamp

```bash

function test_globals_current_timestamp() {
  assert_matches \
    "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$" \
    "$(current_timestamp)"
}
```

## is_command_available

```bash
function test_globals_is_command_available() {
  assert_successful_code "$(is_command_available ls)"
  assert_general_error "$(is_command_available non-existing-command)"
}
```

## random_str

```bash
function test_globals_random_str_default() {
  assert_matches "^[A-Za-z0-9]{6}$" "$(random_str)"
  assert_matches "^[A-Za-z0-9]{3}$" "$(random_str 3)"
}
```

## temp_file

```bash
function test_globals_temp_file() {
  # shellcheck disable=SC2155
  local temp_file=$(temp_file)
  assert_file_exists "$temp_file"
  cleanup_temp_files
  assert_file_not_exists "$temp_file"
}
```

## temp_dir

```bash
function test_globals_temp_dir() {
  # shellcheck disable=SC2155
  local temp_dir=$(temp_dir)
  assert_directory_exists "$temp_dir"
  cleanup_temp_files
  assert_directory_not_exists "$temp_dir"
}
```

## log

Write into the `BASHUNIT_LOG_PATH` a log message.

> See: [Log path](/configuration#log-path)

```bash
log "hello" "world" # default level: info
log "info" "hello" "world"
log "debug" "hello" "world"
log "warning" "hello" "world"
log "critical" "hello" "world"
log "error" "hello" "world"
```
