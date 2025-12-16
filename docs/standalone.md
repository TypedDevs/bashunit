# Standalone

Use bashunit assertions outside of test files for integration testing, end-to-end testing, or validating entire applications and executables.

## Quick Start

Execute assertions directly from the command line using the `assert` command:

::: code-group
```bash [Command]
./bashunit assert equals "expected" "expected"
```
```[Output]
# No output - exit code 0 (success)
```
:::

## Exit Codes

| Exit Code | Description |
|-----------|-------------|
| `0` | Assertion passed |
| `1` | Assertion failed |
| `127` | Non-existing function |

## Basic Usage

### With or Without Prefix

The `assert_` prefix is optional when calling assertions:

::: code-group
```bash [With prefix]
./bashunit assert assert_same "foo" "foo"
./bashunit assert assert_not_equals "foo" "bar"
```
```bash [Without prefix]
./bashunit assert same "foo" "foo"
./bashunit assert not_equals "foo" "bar"
```
:::

### Success and Failure

::: code-group
```bash [Success]
./bashunit assert equals "hello" "hello"
# Exit code: 0
```
```bash [Failure]
./bashunit assert equals "hello" "world"
```
```[Failure Output]
✗ Failed: assert equals
    Expected 'hello'
    but got  'world'
```
:::

## Lazy Evaluation

Evaluate exit codes without executing commands directly with `$(...)`. This prevents CI interruption when commands return non-zero exit codes:

::: code-group
```bash [Command]
./bashunit assert exit_code "1" "grep -q 'pattern' /nonexistent/file"
```
```bash [PHPStan example]
./bashunit assert exit_code "1" "$PHPSTAN_PATH analyze \
  --no-progress --level 8 \
  --error-format raw ./"
```
:::

::: tip
Pass the command as a raw string instead of executing it. bashunit will run the command and capture its exit code.
:::

### Capturing Output

Capture command output for further assertions:

::: code-group
```bash [Example]
OUTPUT=$(./bashunit assert exit_code "1" "grep -q 'pattern' ./file.txt")
./bashunit assert line_count 1 "$OUTPUT"
```
:::

### Stdout and Stderr Separation

Command output goes to stdout, bashunit messages go to stderr. Use this to redirect outputs independently:

::: code-group
```bash [Command]
./bashunit assert exit_code "0" "some_command" 2> /tmp/error.log
```
```[stdout]
# Command output appears here
```
```[/tmp/error.log]
✗ Failed: assert exit_code
    Expected '0'
    but got  '1'
```
:::

## Multiple Assertions

Chain multiple assertions on a single command using the `assert` subcommand:

::: code-group
```bash [Syntax]
./bashunit assert "command" assertion1 args... assertion2 args...
```
```bash [Example]
./bashunit assert "echo 'error message' && exit 1" \
  exit_code "1" \
  contains "error"
```
```[Output]
error message
# Exit code 0 (all assertions passed)
```
:::

### Chaining Multiple Assertions

::: code-group
```bash [Example]
./bashunit assert "./my_script.sh" \
  exit_code "0" \
  contains "success" \
  not_contains "error" \
  line_count "5"
```
:::

This is equivalent to running assertions separately:

```bash
OUTPUT=$(./bashunit assert exit_code "0" "./my_script.sh")
./bashunit assert contains "success" "$OUTPUT"
./bashunit assert not_contains "error" "$OUTPUT"
./bashunit assert line_count "5" "$OUTPUT"
```

::: info
Exit code assertions (`exit_code`, `successful_code`, `general_error`, etc.) receive the command's exit code. All other assertions (`contains`, `equals`, `matches`, etc.) receive the command's stdout output.
:::

## Practical Examples

### Validating Script Output

::: code-group
```bash [Example]
./bashunit assert "./build.sh" \
  exit_code "0" \
  contains "Build successful" \
  not_contains "ERROR"
```
:::

### Testing API Responses

::: code-group
```bash [Example]
./bashunit assert "curl -s http://localhost:8080/health" \
  exit_code "0" \
  contains '"status":"healthy"'
```
:::

### Checking File Operations

::: code-group
```bash [Example]
./bashunit assert "./deploy.sh --env staging" \
  exit_code "0" \
  contains "Deployed to staging"

./bashunit assert file_exists "/var/www/staging/index.html"
```
:::

## Available Assertions

All standard bashunit [assertions](/assertions) are available in standalone mode. Common ones include:

| Assertion | Description |
|-----------|-------------|
| `equals` | Check string equality |
| `contains` | Check substring presence |
| `matches` | Match against regex pattern |
| `exit_code` | Check command exit code |
| `successful_code` | Check for exit code 0 |
| `file_exists` | Check file existence |
| `line_count` | Check number of lines |

See the full [assertions reference](/assertions) for all available options.
