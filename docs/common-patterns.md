# Common Patterns

This guide shows real-world testing patterns to help you write effective tests for your bash scripts. Each pattern includes practical examples and explains when to use it.

## Table of Contents

- [Testing Functions vs Scripts](#testing-functions-vs-scripts)
- [Setup and Teardown](#setup-and-teardown)
- [Testing Exit Codes](#testing-exit-codes)
- [Testing File Operations](#testing-file-operations)
- [Testing Scripts with Input](#testing-scripts-with-input)
- [Testing Error Conditions](#testing-error-conditions)
- [Testing External Dependencies](#testing-external-dependencies)
- [Testing Output Formats](#testing-output-formats)
- [Organizing Large Test Suites](#organizing-large-test-suites)
- [Testing Private Functions](#testing-private-functions)
- [Parameterized Testing](#parameterized-testing)

## Testing Functions vs Scripts

### Testing Individual Functions

When you have a script with functions you want to test individually, source the script and test each function:

::: code-group
```bash [src/calculator.sh]
#!/usr/bin/env bash

function add() {
  echo $(($1 + $2))
}

function multiply() {
  echo $(($1 * $2))
}
```

```bash [tests/calculator_test.sh]
#!/usr/bin/env bash

function set_up() {
  source "src/calculator.sh"
}

function test_add_two_positive_numbers() {
  assert_same "5" "$(add 2 3)"
}

function test_add_negative_numbers() {
  assert_same "-5" "$(add -2 -3)"
}

function test_multiply() {
  assert_same "6" "$(multiply 2 3)"
}
```
:::

### Testing Complete Scripts

When testing a script that executes commands directly, treat it as an executable:

::: code-group
```bash [src/deploy.sh]
#!/usr/bin/env bash
set -euo pipefail

environment=${1:-staging}

echo "Deploying to $environment..."
# deployment logic here
echo "Deployment complete!"
```

```bash [tests/deploy_test.sh]
#!/usr/bin/env bash

function test_deploy_with_default_environment() {
  local output
  output=$(bash src/deploy.sh)

  assert_contains "Deploying to staging" "$output"
  assert_contains "Deployment complete" "$output"
}

function test_deploy_with_custom_environment() {
  local output
  output=$(bash src/deploy.sh production)

  assert_contains "Deploying to production" "$output"
}
```
:::

## Setup and Teardown

### Using set_up and tear_down

Use lifecycle hooks to prepare test environments and clean up afterward:

::: code-group
```bash [tests/database_test.sh]
#!/usr/bin/env bash

function set_up() {
  # Runs before each test
  export TEST_DB="/tmp/test_db_$$"
  mkdir -p "$TEST_DB"
  source "src/database.sh"
}

function tear_down() {
  # Runs after each test
  rm -rf "$TEST_DB"
}

function test_create_table() {
  create_table "users"
  assert_file_exists "$TEST_DB/users.txt"
}

function test_insert_record() {
  create_table "users"
  insert_record "users" "john@example.com"

  assert_file_contains "john@example.com" "$TEST_DB/users.txt"
}
```
:::

### Using set_up_before_script and tear_down_after_script

Use these for expensive operations that only need to run once per file:

::: code-group
```bash [tests/integration_test.sh]
#!/usr/bin/env bash

function set_up_before_script() {
  # Runs once before all tests in this file
  export TEST_SERVER_PID
  ./scripts/start_test_server.sh &
  TEST_SERVER_PID=$!
  sleep 2  # Wait for server to start
}

function tear_down_after_script() {
  # Runs once after all tests in this file
  kill "$TEST_SERVER_PID" 2>/dev/null || true
}

function test_server_responds_to_ping() {
  assert_successful_code "curl -s http://localhost:8080/ping"
}

function test_server_returns_json() {
  local response
  response=$(curl -s http://localhost:8080/api/data)

  assert_contains '"status":"ok"' "$response"
}
```
:::

## Testing Exit Codes

### Testing Successful Execution

::: code-group
```bash [tests/validation_test.sh]
#!/usr/bin/env bash

function test_valid_email_returns_success() {
  assert_successful_code "./src/validate_email.sh user@example.com"
}

function test_backup_succeeds() {
  assert_exit_code 0 "./src/backup.sh --dry-run"
}
```
:::

### Testing Failure Cases

::: code-group
```bash [tests/validation_test.sh]
#!/usr/bin/env bash

function test_invalid_email_returns_error() {
  assert_general_error "./src/validate_email.sh invalid-email"
}

function test_missing_file_returns_specific_code() {
  assert_exit_code 127 "./src/process_file.sh /nonexistent/file.txt"
}
```
:::

## Testing File Operations

### Testing File Creation and Content

::: code-group
```bash [tests/logger_test.sh]
#!/usr/bin/env bash

function set_up() {
  export TEST_LOG="/tmp/test_log_$$_$RANDOM.log"
  source "src/logger.sh"
}

function tear_down() {
  rm -f "$TEST_LOG"
}

function test_log_creates_file() {
  log_message "Test message" "$TEST_LOG"

  assert_file_exists "$TEST_LOG"
}

function test_log_writes_timestamp_and_message() {
  log_message "Error occurred" "$TEST_LOG"

  assert_file_contains "Error occurred" "$TEST_LOG"
  # Check for timestamp pattern (YYYY-MM-DD HH:MM:SS)
  assert_matches "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" "$TEST_LOG"
}

function test_log_appends_multiple_messages() {
  log_message "First message" "$TEST_LOG"
  log_message "Second message" "$TEST_LOG"

  local line_count
  line_count=$(wc -l < "$TEST_LOG")
  assert_same "2" "$line_count"
}
```
:::

### Testing Directory Operations

::: code-group
```bash [tests/directory_test.sh]
#!/usr/bin/env bash

function set_up() {
  export TEST_DIR="/tmp/bashunit_test_$$"
  source "src/file_manager.sh"
}

function tear_down() {
  rm -rf "$TEST_DIR"
}

function test_create_directory_structure() {
  create_project_structure "$TEST_DIR"

  assert_directory_exists "$TEST_DIR"
  assert_directory_exists "$TEST_DIR/src"
  assert_directory_exists "$TEST_DIR/tests"
  assert_directory_exists "$TEST_DIR/docs"
}

function test_cleanup_removes_old_files() {
  mkdir -p "$TEST_DIR"
  touch "$TEST_DIR/old_file.txt"
  touch "$TEST_DIR/new_file.txt"

  # Backdate old_file
  touch -t 202301010000 "$TEST_DIR/old_file.txt"

  cleanup_old_files "$TEST_DIR" 365

  assert_file_not_exists "$TEST_DIR/old_file.txt"
  assert_file_exists "$TEST_DIR/new_file.txt"
}
```
:::

## Testing Scripts with Input

### Testing with Command Line Arguments

::: code-group
```bash [tests/cli_test.sh]
#!/usr/bin/env bash

function test_help_flag_shows_usage() {
  local output
  output=$(./src/cli.sh --help)

  assert_contains "Usage:" "$output"
  assert_contains "Options:" "$output"
}

function test_multiple_flags() {
  local output
  output=$(./src/cli.sh --verbose --output /tmp/test.log process)

  assert_contains "Verbose mode enabled" "$output"
}
```
:::

### Testing with Piped Input

::: code-group
```bash [tests/filter_test.sh]
#!/usr/bin/env bash

function test_filter_removes_empty_lines() {
  local input="line1

line2

line3"
  local output
  output=$(echo "$input" | ./src/filter.sh --remove-empty)

  local line_count
  line_count=$(echo "$output" | wc -l)
  assert_same "3" "$line_count"
}

function test_grep_pattern() {
  local output
  output=$(echo -e "error: failed\ninfo: started\nerror: crashed" | ./src/filter.sh error)

  assert_contains "failed" "$output"
  assert_contains "crashed" "$output"
  assert_not_contains "started" "$output"
}
```
:::

### Testing with Here-Documents

::: code-group
```bash [tests/parser_test.sh]
#!/usr/bin/env bash

function test_parse_multiline_config() {
  local output
  output=$(./src/config_parser.sh <<EOF
name=myapp
version=1.0.0
debug=true
EOF
)

  assert_contains "Loaded config: myapp" "$output"
  assert_contains "Version: 1.0.0" "$output"
}
```
:::

## Testing Error Conditions

### Testing Error Messages

::: code-group
```bash [tests/errors_test.sh]
#!/usr/bin/env bash

function test_missing_required_argument() {
  local output
  output=$(./src/backup.sh 2>&1 || true)

  assert_contains "Error: Missing required argument" "$output"
}

function test_invalid_option() {
  local output
  output=$(./src/backup.sh --invalid-option 2>&1 || true)

  assert_contains "Unknown option" "$output"
  assert_exit_code 1 "./src/backup.sh --invalid-option"
}
```
:::

### Testing set -e Behavior

::: code-group
```bash [tests/strict_mode_test.sh]
#!/usr/bin/env bash

function test_script_fails_on_error() {
  # Scripts with 'set -e' should exit on first error
  local exit_code=0
  ./src/strict_script.sh || exit_code=$?

  assert_not_equals "0" "$exit_code"
}

function test_error_handled_gracefully() {
  # Script should catch and handle expected errors
  assert_successful_code "./src/resilient_script.sh"
}
```
:::

## Testing External Dependencies

### Mocking External Commands

::: code-group
```bash [tests/git_wrapper_test.sh]
#!/usr/bin/env bash

function set_up() {
  source "src/git_wrapper.sh"
}

function test_get_current_branch() {
  mock git echo "feature/new-feature"

  local branch
  branch=$(get_current_branch)

  assert_same "feature/new-feature" "$branch"
}

function test_check_for_changes() {
  mock git <<EOF
M  src/file1.sh
A  src/file2.sh
EOF

  local result
  result=$(has_uncommitted_changes && echo "yes" || echo "no")

  assert_same "yes" "$result"
}

function test_handles_git_error() {
  # Mock git to return an error
  function git() {
    echo "fatal: not a git repository" >&2
    return 128
  }
  export -f git

  local exit_code=0
  check_git_status || exit_code=$?

  assert_equals "128" "$exit_code"
}
```
:::

### Using Spies to Verify Calls

::: code-group
```bash [tests/deployment_test.sh]
#!/usr/bin/env bash

function set_up() {
  source "src/deploy.sh"
}

function test_deployment_calls_docker_push() {
  spy docker

  deploy_image "myapp:latest"

  assert_have_been_called docker
}

function test_docker_called_with_correct_arguments() {
  spy docker

  deploy_image "myapp:v1.0.0"

  assert_have_been_called_with "push myapp:v1.0.0" docker
}

function test_deploy_calls_docker_twice() {
  spy docker

  deploy_image "myapp:latest"
  deploy_image "myapp:v1.0.0"

  assert_have_been_called_times 2 docker
}
```
:::

## Testing Output Formats

### Testing JSON Output

::: code-group
```bash [tests/json_test.sh]
#!/usr/bin/env bash

function test_json_contains_expected_fields() {
  local output
  output=$(./src/generate_report.sh --format json)

  assert_contains '"status"' "$output"
  assert_contains '"timestamp"' "$output"
  assert_contains '"data"' "$output"
}

function test_json_is_valid() {
  local output
  output=$(./src/generate_report.sh --format json)

  # Use jq to validate JSON (mock it if jq not available)
  assert_successful_code "echo '$output' | jq . > /dev/null"
}
```
:::

### Testing Colored Output

::: code-group
```bash [tests/colors_test.sh]
#!/usr/bin/env bash

function test_colored_output_contains_escape_codes() {
  local output
  output=$(./src/print_status.sh --color)

  # Check for ANSI color codes
  assert_matches '\[3[0-9]m' "$output"
}

function test_no_color_flag_removes_colors() {
  local output
  output=$(./src/print_status.sh --no-color)

  # Should not contain ANSI color codes
  assert_not_matches '\[3[0-9]m' "$output"
}
```
:::

### Testing Table Output

::: code-group
```bash [tests/table_test.sh]
#!/usr/bin/env bash

function test_table_has_headers() {
  local output
  output=$(./src/list_users.sh)

  assert_contains "Name" "$output"
  assert_contains "Email" "$output"
  assert_contains "Status" "$output"
}

function test_table_formatting() {
  local output
  output=$(./src/list_users.sh)

  # Check for separator line (dashes)
  assert_matches '[-]+' "$output"
}
```
:::

## Organizing Large Test Suites

### Grouping Related Tests

Organize tests by feature or component:

```
tests/
├── unit/
│   ├── parser_test.sh
│   ├── validator_test.sh
│   └── formatter_test.sh
├── integration/
│   ├── api_test.sh
│   └── database_test.sh
├── functional/
│   ├── user_workflow_test.sh
│   └── admin_workflow_test.sh
└── helpers/
    └── test_helpers.sh
```

### Creating Test Helpers

::: code-group
```bash [tests/helpers/test_helpers.sh]
#!/usr/bin/env bash

# Create a temporary test database
function create_test_db() {
  local db_path="/tmp/test_db_$$_$RANDOM"
  mkdir -p "$db_path"
  echo "$db_path"
}

# Clean up test database
function cleanup_test_db() {
  local db_path=$1
  rm -rf "$db_path"
}

# Create a test user
function create_test_user() {
  local name=$1
  local email=$2
  echo "$name,$email,active" >> "$TEST_DB/users.csv"
}
```

```bash [tests/unit/user_test.sh]
#!/usr/bin/env bash

function set_up() {
  source "tests/helpers/test_helpers.sh"
  source "src/user.sh"
  export TEST_DB
  TEST_DB=$(create_test_db)
}

function tear_down() {
  cleanup_test_db "$TEST_DB"
}

function test_create_user() {
  create_test_user "John Doe" "john@example.com"

  assert_file_contains "John Doe" "$TEST_DB/users.csv"
}
```
:::

### Using Environment Bootstrap Files

::: code-group
```bash [tests/bootstrap.sh]
#!/usr/bin/env bash

# Set test environment variables
export TEST_MODE=true
export LOG_LEVEL=debug
export CONFIG_PATH=/tmp/test_config

# Load common test utilities
source "tests/helpers/test_helpers.sh"

# Setup test database connection
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=test_db
```

```bash [Run with bootstrap]
# Run tests with bootstrap file
./bashunit --env tests/bootstrap.sh tests/
```
:::

## Testing Private Functions

When you need to test functions that aren't exported:

::: code-group
```bash [src/processor.sh]
#!/usr/bin/env bash

# Private helper function
function _validate_input() {
  [[ -n $1 ]] && [[ $1 =~ ^[0-9]+$ ]]
}

# Public function
function process_number() {
  if _validate_input "$1"; then
    echo "Processing: $1"
  else
    echo "Invalid input" >&2
    return 1
  fi
}
```

```bash [tests/processor_test.sh]
#!/usr/bin/env bash

function set_up() {
  source "src/processor.sh"
}

# Test private function directly after sourcing
function test_private_validate_input_accepts_numbers() {
  assert_successful_code "_validate_input 123"
}

function test_private_validate_input_rejects_text() {
  assert_general_error "_validate_input abc"
}

# Test through public interface
function test_process_number_with_valid_input() {
  assert_contains "Processing: 42" "$(process_number 42)"
}

function test_process_number_with_invalid_input() {
  local output
  output=$(process_number "invalid" 2>&1 || true)

  assert_contains "Invalid input" "$output"
}
```
:::

## Parameterized Testing

### Using Data Providers

::: code-group
```bash [tests/validation_test.sh]
#!/usr/bin/env bash

function set_up() {
  source "src/validator.sh"
}

function data_provider_valid_emails() {
  echo "user@example.com"
  echo "test.user@example.co.uk"
  echo "user+tag@example.org"
}

function test_valid_email_formats() {
  assert_successful_code "validate_email '$1'"
}

function data_provider_invalid_emails() {
  echo "invalid-email"
  echo "@example.com"
  echo "user@"
  echo "user name@example.com"
}

function test_invalid_email_formats() {
  assert_general_error "validate_email '$1'"
}
```
:::

### Testing Multiple Scenarios

::: code-group
```bash [tests/calculator_test.sh]
#!/usr/bin/env bash

function set_up() {
  source "src/calculator.sh"
}

function data_provider_addition_cases() {
  echo "2 3 5"
  echo "0 0 0"
  echo "-1 1 0"
  echo "100 200 300"
  echo "-5 -5 -10"
}

function test_addition() {
  local a=$1
  local b=$2
  local expected=$3

  local result
  result=$(add "$a" "$b")

  assert_same "$expected" "$result"
}
```
:::

## Best Practices Summary

1. **Keep tests independent**: Each test should run successfully in isolation
2. **Use descriptive names**: Test names should clearly describe what they test
3. **Follow AAA pattern**: Arrange, Act, Assert
4. **Clean up resources**: Always clean up temporary files and processes
5. **Test both success and failure**: Don't just test the happy path
6. **Use mocks wisely**: Mock external dependencies but don't over-mock
7. **One assertion per test**: When possible, focus each test on a single behavior
8. **Use lifecycle hooks**: Leverage `set_up` and `tear_down` for common setup
9. **Organize logically**: Group related tests in the same file or directory
10. **Document complex tests**: Add comments explaining why you're testing something unusual

## Next Steps

- Explore [Test Doubles](/test-doubles) for advanced mocking and spying
- Learn about [Data Providers](/data-providers) for parameterized testing
- Check out [Snapshots](/snapshots) for testing complex output
- Read about [Custom Asserts](/custom-asserts) for domain-specific testing
