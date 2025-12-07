#!/usr/bin/env bash
# shellcheck disable=SC2016

##
# Interactive learning module for bashunit
# Provides guided tutorials and exercises to learn bashunit
##

declare -r LEARN_TEMP_DIR="/tmp/bashunit_learn_$$"
declare -r LEARN_PROGRESS_FILE="$HOME/.bashunit_learn_progress"

##
# Initialize learning environment
##
function bashunit::learn::init() {
  mkdir -p "$LEARN_TEMP_DIR"
  mkdir -p tests
}

##
# Cleanup learning environment
##
function bashunit::learn::cleanup() {
  rm -rf "$LEARN_TEMP_DIR"
}

##
# Print the learning menu
##
function bashunit::learn::print_menu() {
  cat <<EOF
${_BASHUNIT_COLOR_BOLD}${_BASHUNIT_COLOR_PASSED}bashunit${_BASHUNIT_COLOR_DEFAULT} - Interactive Learning

Choose a lesson:

  ${_BASHUNIT_COLOR_BOLD}1.${_BASHUNIT_COLOR_DEFAULT} Basics - Your First Test
  ${_BASHUNIT_COLOR_BOLD}2.${_BASHUNIT_COLOR_DEFAULT} Assertions - Testing Different Conditions
  ${_BASHUNIT_COLOR_BOLD}3.${_BASHUNIT_COLOR_DEFAULT} Setup & Teardown - Managing Test Lifecycle
  ${_BASHUNIT_COLOR_BOLD}4.${_BASHUNIT_COLOR_DEFAULT} Testing Functions - Unit Testing Patterns
  ${_BASHUNIT_COLOR_BOLD}5.${_BASHUNIT_COLOR_DEFAULT} Testing Scripts - Integration Testing
  ${_BASHUNIT_COLOR_BOLD}6.${_BASHUNIT_COLOR_DEFAULT} Mocking - Test Doubles and Mocks
  ${_BASHUNIT_COLOR_BOLD}7.${_BASHUNIT_COLOR_DEFAULT} Spies - Verifying Function Calls
  ${_BASHUNIT_COLOR_BOLD}8.${_BASHUNIT_COLOR_DEFAULT} Data Providers - Parameterized Tests
  ${_BASHUNIT_COLOR_BOLD}9.${_BASHUNIT_COLOR_DEFAULT} Exit Codes - Testing Success and Failure
  ${_BASHUNIT_COLOR_BOLD}10.${_BASHUNIT_COLOR_DEFAULT} Complete Challenge - Real World Scenario

  ${_BASHUNIT_COLOR_BOLD}p.${_BASHUNIT_COLOR_DEFAULT} Show Progress
  ${_BASHUNIT_COLOR_BOLD}r.${_BASHUNIT_COLOR_DEFAULT} Reset Progress
  ${_BASHUNIT_COLOR_BOLD}q.${_BASHUNIT_COLOR_DEFAULT} Quit

Enter your choice:
EOF
}

##
# Main learning loop
##
function bashunit::learn::start() {
  bashunit::learn::init

  trap 'bashunit::learn::cleanup' EXIT

  while true; do
    echo ""
    bashunit::learn::print_menu
    read -r choice
    echo ""

    case "$choice" in
      1) bashunit::learn::lesson_basics || true ;;
      2) bashunit::learn::lesson_assertions || true ;;
      3) bashunit::learn::lesson_lifecycle || true ;;
      4) bashunit::learn::lesson_functions || true ;;
      5) bashunit::learn::lesson_scripts || true ;;
      6) bashunit::learn::lesson_mocking || true ;;
      7) bashunit::learn::lesson_spies || true ;;
      8) bashunit::learn::lesson_data_providers || true ;;
      9) bashunit::learn::lesson_exit_codes || true ;;
      10) bashunit::learn::lesson_challenge || true ;;
      p) bashunit::learn::show_progress ;;
      r) bashunit::learn::reset_progress ;;
      q)
        echo "${_BASHUNIT_COLOR_PASSED}Happy testing!${_BASHUNIT_COLOR_DEFAULT}"
        break
        ;;
      *)
        echo "${_BASHUNIT_COLOR_FAILED}Invalid choice. Please try again.${_BASHUNIT_COLOR_DEFAULT}"
        ;;
    esac
  done

  bashunit::learn::cleanup
}

##
# Mark lesson as completed
##
function bashunit::learn::mark_completed() {
  local lesson=$1
  echo "$lesson" >> "$LEARN_PROGRESS_FILE"
}

##
# Check if lesson is completed
##
function bashunit::learn::is_completed() {
  local lesson=$1
  [[ -f "$LEARN_PROGRESS_FILE" ]] && grep -q "^$lesson$" "$LEARN_PROGRESS_FILE"
}

##
# Show learning progress
##
function bashunit::learn::show_progress() {
  if [[ ! -f "$LEARN_PROGRESS_FILE" ]]; then
    echo "${_BASHUNIT_COLOR_INCOMPLETE}No progress yet. Start with lesson 1!${_BASHUNIT_COLOR_DEFAULT}"
    return
  fi

  echo "${_BASHUNIT_COLOR_BOLD}Your Progress:${_BASHUNIT_COLOR_DEFAULT}"
  echo ""

  local total_lessons=10
  local completed=0

  for i in $(seq 1 $total_lessons); do
    if bashunit::learn::is_completed "lesson_$i"; then
      echo "  ${_BASHUNIT_COLOR_PASSED}✓${_BASHUNIT_COLOR_DEFAULT} Lesson $i completed"
      ((completed++))
    else
      echo "  ${_BASHUNIT_COLOR_INCOMPLETE}○${_BASHUNIT_COLOR_DEFAULT} Lesson $i"
    fi
  done

  echo ""
  echo "Progress: $completed/$total_lessons lessons completed"

  if [[ $completed -eq $total_lessons ]]; then
    echo ""
    printf "%s%s🎉 Congratulations! You've completed all lessons!%s\n" \
      "$_BASHUNIT_COLOR_PASSED" "$_BASHUNIT_COLOR_BOLD" "$_BASHUNIT_COLOR_DEFAULT"
  fi

  read -p "Press Enter to continue..." -r
}

##
# Reset learning progress
##
function bashunit::learn::reset_progress() {
  rm -f "$LEARN_PROGRESS_FILE"
  echo "${_BASHUNIT_COLOR_PASSED}Progress reset successfully.${_BASHUNIT_COLOR_DEFAULT}"
  read -p "Press Enter to continue..." -r
}

##
# Create the example file automatically
# Arguments: $1 - filename, $2 - file content
##
function bashunit::learn::create_example_file() {
  local filename=$1
  local content=$2

  echo ""
  echo "Creating example file ${_BASHUNIT_COLOR_BOLD}$filename${_BASHUNIT_COLOR_DEFAULT}..."
  echo "$content" > "$filename"
  chmod +x "$filename"
  echo "${_BASHUNIT_COLOR_PASSED}✓ Created $filename${_BASHUNIT_COLOR_DEFAULT}"
  echo ""
  echo "File created! Edit it to complete the TODO items, then run this lesson again."
  read -p "Press Enter to continue..." -r
  return 0
}

##
# Run a lesson test and check results
##
function bashunit::learn::run_lesson_test() {
  local test_file=$1
  local lesson_number=$2

  echo "${_BASHUNIT_COLOR_BOLD}Running your test...${_BASHUNIT_COLOR_DEFAULT}"
  echo ""

  if "$BASHUNIT_ROOT_DIR/bashunit" "$test_file" --simple; then
    echo ""
    printf "%s%s✓ Excellent! Lesson %s completed!%s\n" \
      "$_BASHUNIT_COLOR_PASSED" "$_BASHUNIT_COLOR_BOLD" "$lesson_number" "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::learn::mark_completed "lesson_$lesson_number"
    read -p "Press Enter to continue..." -r
    return 0
  else
    echo ""
    echo "${_BASHUNIT_COLOR_FAILED}Not quite right. Review the requirements and try again.${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi
}

##
# Lesson 1: Basics - Your First Test
##
function bashunit::learn::lesson_basics() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║                    Lesson 1: Your First Test                   ║
╚════════════════════════════════════════════════════════════════╝

Welcome to bashunit! Let's write your first test.

CONCEPT: A test is a function that starts with 'test_' and uses
assertions to verify behavior.

TASK: Create a test file that checks if two values are equal.

File: tests/first_test.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function test_bashunit_works() {
  # TODO: Use assert_same to check if "hello" equals "hello"
  # Hint: assert_same "expected" "actual"
}
───────────────────────────────────────────────────────────────

TIPS:
  • The assert_same function takes two arguments:
    assert_same "expected" "actual"
  • Test functions must start with "test_" prefix
  • Always quote your strings to avoid word splitting
  • Keep test files in a tests/ directory for better organization
EOF

  local default_file="tests/first_test.sh"
  echo ""
  printf "When ready, enter file path %s[%s]%s: " \
    "${_BASHUNIT_COLOR_FAINT}" "$default_file" "${_BASHUNIT_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function test_bashunit_works() {
  # TODO: Use assert_same to check if "hello" equals "hello"
  # Hint: assert_same "expected" "actual"
}'

    bashunit::learn::create_example_file "$test_file" "$template"
    return 1
  fi

  # Check if file contains assert_same
  if ! grep -q "assert_same" "$test_file"; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should use assert_same${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 1
}

##
# Lesson 2: Assertions - Testing Different Conditions
##
function bashunit::learn::lesson_assertions() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║              Lesson 2: Testing Different Conditions            ║
╚════════════════════════════════════════════════════════════════╝

CONCEPT: bashunit provides many assertion functions for different checks:
  • assert_same - exact equality
  • assert_contains - substring check
  • assert_matches - regex pattern
  • assert_not_same - inequality
  • assert_empty - checks if value is empty
  • assert_not_empty - checks if value is not empty

TASK: Write a test file with 3 different assertions.

File: tests/assertions_test.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function test_multiple_assertions() {
  local message="Hello, bashunit!"

  # TODO: Check that message contains "bashunit"
  # Hint: assert_contains "substring" "$message"

  # TODO: Check that message matches the pattern "Hello.*!"
  # Hint: assert_matches "pattern" "$message"

  # TODO: Check that message is not empty
  # Hint: assert_not_empty "$message"
}
───────────────────────────────────────────────────────────────

TIPS:
  • assert_same checks exact equality (useful for strings/numbers)
  • assert_contains is more flexible for partial matches
  • assert_matches uses regex patterns (e.g., "^[0-9]+$" for numbers)
  • Explore more: assert_empty, assert_true, assert_false
EOF

  local default_file="tests/assertions_test.sh"
  echo ""
  printf "When ready, enter file path %s[%s]%s: " \
    "${_BASHUNIT_COLOR_FAINT}" "$default_file" "${_BASHUNIT_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function test_multiple_assertions() {
  local message="Hello, bashunit!"

  # TODO: Check that message contains "bashunit"
  # Hint: assert_contains "substring" "$message"

  # TODO: Check that message matches the pattern "Hello.*!"
  # Hint: assert_matches "pattern" "$message"

  # TODO: Check that message is not empty
  # Hint: assert_not_empty "$message"
}'

    bashunit::learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if ! grep -q "assert_contains" "$test_file" || \
      ! grep -q "assert_matches" "$test_file" || \
      ! grep -q "assert_not_empty" "$test_file"; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should use all three assertion types${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 2
}

##
# Lesson 3: Setup & Teardown - Managing Test Lifecycle
##
function bashunit::learn::lesson_lifecycle() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║           Lesson 3: Setup and Teardown Functions               ║
╚════════════════════════════════════════════════════════════════╝

CONCEPT: Tests often need preparation and cleanup. bashunit provides:
  • set_up() - runs before EACH test
  • tear_down() - runs after EACH test
  • set_up_before_script() - runs once before ALL tests
  • tear_down_after_script() - runs once after ALL tests

TASK: Create a test that uses setup and teardown to manage files.

File: tests/lifecycle_test.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function set_up() {
  # Create a temp file before each test
  # TODO: export TEST_FILE="/tmp/test_$$"
  # TODO: echo "test content" > "$TEST_FILE"
}

function tear_down() {
  # Clean up after each test
  # TODO: rm -f "$TEST_FILE"
}

function test_file_exists() {
  # TODO: assert_file_exists "$TEST_FILE"
}

function test_file_has_content() {
  # TODO: assert_file_contains "test content" "$TEST_FILE"
}
───────────────────────────────────────────────────────────────

TIPS:
  • set_up() runs before EACH test (good for test isolation)
  • set_up_before_script() runs ONCE before all tests (good for expensive setup)
  • Always clean up in tear_down() to avoid polluting other tests
  • Use $$ for unique temp file names to avoid conflicts
EOF

  local default_file="tests/lifecycle_test.sh"
  echo ""
  printf "When ready, enter file path %s[%s]%s: " \
    "${_BASHUNIT_COLOR_FAINT}" "$default_file" "${_BASHUNIT_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function set_up() {
  # Create a temp file before each test
  # TODO: export TEST_FILE="/tmp/test_$$"
  # TODO: echo "test content" > "$TEST_FILE"
}

function tear_down() {
  # Clean up after each test
  # TODO: rm -f "$TEST_FILE"
}

function test_file_exists() {
  # TODO: assert_file_exists "$TEST_FILE"
}

function test_file_has_content() {
  # TODO: assert_file_contains "test content" "$TEST_FILE"
}'

    bashunit::learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if ! grep -q "function set_up()" "$test_file" || \
      ! grep -q "function tear_down()" "$test_file"; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should define set_up and tear_down functions${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 3
}

##
# Lesson 4: Testing Functions
##
function bashunit::learn::lesson_functions() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║              Lesson 4: Testing Bash Functions                  ║
╚════════════════════════════════════════════════════════════════╝

CONCEPT: To test functions, source the file containing them, then
call them in your tests.

TASK: Create a script with a function, then test it.

File: calculator.sh (source code)
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function add() {
  echo $(($1 + $2))
}
───────────────────────────────────────────────────────────────

File: tests/calculator_test.sh (test file)
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function set_up() {
  # TODO: Source calculator.sh from parent directory
  # Hint: source ../calculator.sh
}

function test_add_positive_numbers() {
  # TODO: Test that add 2 3 returns "5"
  # Hint: result=$(add 2 3)
  # Hint: assert_same "5" "$result"
}

function test_add_negative_numbers() {
  # TODO: Test that add -2 -3 returns "-5"
  # Hint: result=$(add -2 -3)
  # Hint: assert_same "-5" "$result"
}
───────────────────────────────────────────────────────────────

TIPS:
  • Source files in set_up() to reload them fresh for each test
  • Capture function output with: result=$(function_name args)
  • Test edge cases: positive, negative, zero, large numbers
  • Source files from parent directory: source ../file.sh
EOF

  local default_file="tests/calculator_test.sh"
  echo ""
  printf "When ready, enter TEST file path %s[%s]%s: " \
    "${_BASHUNIT_COLOR_FAINT}" "$default_file" "${_BASHUNIT_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function set_up() {
  # TODO: Source calculator.sh from parent directory
  # Hint: source ../calculator.sh
}

function test_add_positive_numbers() {
  # TODO: Test that add 2 3 returns "5"
  # Hint: result=$(add 2 3)
  # Hint: assert_same "5" "$result"
}

function test_add_negative_numbers() {
  # TODO: Test that add -2 -3 returns "-5"
  # Hint: result=$(add -2 -3)
  # Hint: assert_same "-5" "$result"
}'

    bashunit::learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if ! grep -q "source" "$test_file"; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should source the calculator.sh file${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 4
}

##
# Lesson 5: Testing Scripts
##
function bashunit::learn::lesson_scripts() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║                 Lesson 5: Testing Bash Scripts                 ║
╚════════════════════════════════════════════════════════════════╝

CONCEPT: Scripts that execute commands directly are tested differently.
Run them and capture their output.

TASK: Create a script and test its output.

File: greeter.sh (source code)
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash
name=${1:-World}
echo "Hello, $name!"
───────────────────────────────────────────────────────────────

File: tests/greeter_test.sh (test file)
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function test_default_greeting() {
  # TODO: Run greeter.sh from parent directory and capture output
  # Hint: output=$(../greeter.sh)

  # TODO: Assert output contains "Hello, World!"
  # Hint: assert_contains "Hello, World!" "$output"
}

function test_custom_greeting() {
  # TODO: Run greeter.sh with argument "Alice"
  # Hint: output=$(../greeter.sh "Alice")

  # TODO: Assert output contains "Hello, Alice!"
  # Hint: assert_contains "Hello, Alice!" "$output"
}
───────────────────────────────────────────────────────────────

TIPS:
  • Use command substitution: output=$(./script.sh)
  • Make scripts executable: chmod +x script.sh
  • Test both default behavior and with various arguments
  • Scripts run in subshells, so they can't modify parent environment
  • Run scripts from parent directory: ../script.sh
EOF

  local default_file="tests/greeter_test.sh"
  echo ""
  printf "When ready, enter TEST file path %s[%s]%s: " \
    "${_BASHUNIT_COLOR_FAINT}" "$default_file" "${_BASHUNIT_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function test_default_greeting() {
  # TODO: Run greeter.sh from parent directory and capture output
  # Hint: output=$(../greeter.sh)

  # TODO: Assert output contains "Hello, World!"
  # Hint: assert_contains "Hello, World!" "$output"
}

function test_custom_greeting() {
  # TODO: Run greeter.sh with argument "Alice"
  # Hint: output=$(../greeter.sh "Alice")

  # TODO: Assert output contains "Hello, Alice!"
  # Hint: assert_contains "Hello, Alice!" "$output"
}'

    bashunit::learn::create_example_file "$test_file" "$template"
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 5
}

##
# Lesson 6: Mocking
##
function bashunit::learn::lesson_mocking() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║               Lesson 6: Mocking External Commands              ║
╚════════════════════════════════════════════════════════════════╝

CONCEPT: Mocks let you override external commands or functions to
control their behavior in tests.

TASK: Test a function that uses external commands.

File: system_info.sh (source code)
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function get_system_info() {
  echo "OS: $(uname -s)"
}
───────────────────────────────────────────────────────────────

File: tests/system_info_test.sh (test file)
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function set_up() {
  source ../system_info.sh
}

function test_system_info_on_linux() {
  # TODO: Mock uname to return "Linux"
  # Hint: mock uname echo "Linux"

  local output
  output=$(get_system_info)

  # TODO: Assert output contains "OS: Linux"
}

function test_system_info_on_macos() {
  # TODO: Mock uname to return "Darwin"

  local output
  output=$(get_system_info)

  # TODO: Assert output contains "OS: Darwin"
}
───────────────────────────────────────────────────────────────

TIPS:
  • Mocks replace commands/functions with custom behavior
  • Syntax: mock command_name echo "mocked output"
  • Mocks are automatically cleaned up after each test
  • Use mocks to avoid calling expensive external commands
EOF

  local default_file="tests/system_info_test.sh"
  echo ""
  printf "When ready, enter TEST file path %s[%s]%s: " \
    "${_BASHUNIT_COLOR_FAINT}" "$default_file" "${_BASHUNIT_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function set_up() {
  source ../system_info.sh
}

function test_system_info_on_linux() {
  # TODO: Mock uname to return "Linux"
  # Hint: mock uname echo "Linux"

  local output
  output=$(get_system_info)

  # TODO: Assert output contains "OS: Linux"
}

function test_system_info_on_macos() {
  # TODO: Mock uname to return "Darwin"

  local output
  output=$(get_system_info)

  # TODO: Assert output contains "OS: Darwin"
}'

    bashunit::learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if ! grep -q "mock" "$test_file"; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should use mock${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 6
}

##
# Lesson 7: Spies
##
function bashunit::learn::lesson_spies() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║              Lesson 7: Spies - Verifying Calls                 ║
╚════════════════════════════════════════════════════════════════╝

CONCEPT: Spies let you verify that functions were called with specific
arguments or a certain number of times.

KEY DIFFERENCE: Spies track calls without changing behavior, while
mocks (Lesson 6) replace the function entirely with custom behavior.

TASK: Use spies to verify function calls.

File: deploy.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function deploy_app() {
  git push origin main
  docker build -t myapp .
  docker push myapp
}
───────────────────────────────────────────────────────────────

File: deploy_test.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function set_up() {
  source deploy.sh
}

function test_deploy_calls_git_push() {
  # TODO: Create spies for git and docker
  # Hint: spy git
  # Hint: spy docker

  deploy_app

  # TODO: Assert git was called
  # Hint: assert_have_been_called git

  # TODO: Assert docker was called
}

function test_deploy_calls_docker_twice() {
  # TODO: Spy on docker

  deploy_app

  # TODO: Assert docker was called exactly 2 times
  # Hint: assert_have_been_called_times 2 docker
}
───────────────────────────────────────────────────────────────

TIPS:
  • Spies track calls but don't change behavior (unlike mocks)
  • assert_have_been_called - verifies at least one call
  • assert_have_been_called_times N - verifies exact call count
  • assert_have_been_called_with - verifies specific arguments
  • Spies are cleaned up automatically after each test
EOF

  local default_file="deploy_test.sh"
  echo ""
  printf "When ready, enter TEST file path %s[%s]%s: " \
    "${_BASHUNIT_COLOR_FAINT}" "$default_file" "${_BASHUNIT_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function set_up() {
  source deploy.sh
}

function test_deploy_calls_git_push() {
  # TODO: Create spies for git and docker
  # Hint: spy git
  # Hint: spy docker

  deploy_app

  # TODO: Assert git was called
  # Hint: assert_have_been_called git

  # TODO: Assert docker was called
}

function test_deploy_calls_docker_twice() {
  # TODO: Spy on docker

  deploy_app

  # TODO: Assert docker was called exactly 2 times
  # Hint: assert_have_been_called_times 2 docker
}'

    bashunit::learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if ! grep -q "spy" "$test_file"; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should use spy${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 7
}

##
# Lesson 8: Data Providers
##
function bashunit::learn::lesson_data_providers() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║           Lesson 8: Data Providers - Parameterized Tests       ║
╚════════════════════════════════════════════════════════════════╝

CONCEPT: Data providers let you run the same test with different inputs.
Define a function that echoes test data, one per line.

HOW IT WORKS: Each line from data_provider_* becomes $1 in your test.
The test runs once for each line of data.

TASK: Test multiple email formats using a data provider.

File: validator.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function is_valid_email() {
  [[ $1 =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}
───────────────────────────────────────────────────────────────

File: validator_test.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function set_up() {
  source validator.sh
}

function data_provider_valid_emails() {
  # TODO: Echo valid email addresses, one per line
  # Example: echo "user@example.com"
}

function test_valid_emails() {
  # $1 contains the email from data provider
  # TODO: Assert is_valid_email succeeds
  # Hint: assert_successful_code "is_valid_email \"$1\""
}

function data_provider_invalid_emails() {
  # TODO: Echo invalid email addresses, one per line
  # Example: echo "not-an-email"
}

function test_invalid_emails() {
  # TODO: Assert is_valid_email fails
  # Hint: assert_general_error "is_valid_email \"$1\""
}
───────────────────────────────────────────────────────────────

TIPS:
  • Data providers must be named: data_provider_<test_name>
  • Each line of output becomes one test case
  • The test function receives the line as $1
  • Great for testing multiple inputs without duplicating code
  • You can have multiple data provider/test pairs in one file
EOF

  local default_file="validator_test.sh"
  echo ""
  printf "When ready, enter TEST file path %s[%s]%s: " \
    "${_BASHUNIT_COLOR_FAINT}" "$default_file" "${_BASHUNIT_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function set_up() {
  source validator.sh
}

function data_provider_valid_emails() {
  # TODO: Echo valid email addresses, one per line
  # Example: echo "user@example.com"
}

function test_valid_emails() {
  # $1 contains the email from data provider
  # TODO: Assert is_valid_email succeeds
  # Hint: assert_successful_code "is_valid_email \"$1\""
}

function data_provider_invalid_emails() {
  # TODO: Echo invalid email addresses, one per line
  # Example: echo "not-an-email"
}

function test_invalid_emails() {
  # TODO: Assert is_valid_email fails
  # Hint: assert_general_error "is_valid_email \"$1\""
}'

    bashunit::learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if ! grep -q "function data_provider_" "$test_file"; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should define data provider functions${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 8
}

##
# Lesson 9: Exit Codes
##
function bashunit::learn::lesson_exit_codes() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║             Lesson 9: Testing Exit Codes                       ║
╚════════════════════════════════════════════════════════════════╝

CONCEPT: Exit codes indicate success (0) or failure (non-zero).
bashunit provides assertions to test them:
  • assert_successful_code - expects exit code 0
  • assert_general_error - expects exit code 1
  • assert_exit_code N - expects specific exit code N

TASK: Test different exit codes.

File: checker.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function check_file() {
  if [[ ! -e "$1" ]]; then
    echo "File not found" >&2
    return 127
  fi

  if [[ ! -r "$1" ]]; then
    echo "Permission denied" >&2
    return 1
  fi

  echo "File OK"
  return 0
}
───────────────────────────────────────────────────────────────

File: checker_test.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function set_up() {
  source checker.sh
  # Create a test file
  export TEST_FILE="/tmp/test_file_$$"
  touch "$TEST_FILE"
}

function tear_down() {
  rm -f "$TEST_FILE"
}

function test_existing_file_returns_success() {
  # TODO: Assert check_file succeeds with TEST_FILE
  # Hint: assert_successful_code "check_file '$TEST_FILE'"
}

function test_missing_file_returns_127() {
  # TODO: Assert check_file returns exit code 127 for missing file
  # Hint: assert_exit_code 127 "check_file '/nonexistent/file'"
}
───────────────────────────────────────────────────────────────

TIPS:
  • Exit code 0 = success (assert_successful_code)
  • Exit code 1 = general error (assert_general_error)
  • Other codes = specific errors (assert_exit_code N)
  • Bash uses 'return N' in functions, 'exit N' in scripts
  • Common codes: 127=not found, 126=not executable, 2=misuse
EOF

  local default_file="checker_test.sh"
  echo ""
  printf "When ready, enter TEST file path %s[%s]%s: " \
    "${_BASHUNIT_COLOR_FAINT}" "$default_file" "${_BASHUNIT_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function set_up() {
  source checker.sh
  # Create a test file
  export TEST_FILE="/tmp/test_file_$$"
  touch "$TEST_FILE"
}

function tear_down() {
  rm -f "$TEST_FILE"
}

function test_existing_file_returns_success() {
  # TODO: Assert check_file succeeds with TEST_FILE
  # Hint: assert_successful_code "check_file '\''$TEST_FILE'\''"
}

function test_missing_file_returns_127() {
  # TODO: Assert check_file returns exit code 127 for missing file
  # Hint: assert_exit_code 127 "check_file '\''/nonexistent/file'\''"
}'

    bashunit::learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if ! grep -q "assert_successful_code\|assert_exit_code\|assert_general_error" "$test_file"; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should use exit code assertions${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 9
}

##
# Lesson 10: Complete Challenge
##
function bashunit::learn::lesson_challenge() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║          Lesson 10: Complete Challenge - Backup Script         ║
╚════════════════════════════════════════════════════════════════╝

FINAL CHALLENGE: Combine everything you've learned!

CONCEPT: Real-world tests combine multiple concepts: lifecycle
management, assertions, exit codes, and test doubles.

TASK: Create a backup script and comprehensive tests.

File: backup.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function create_backup() {
  local source=$1
  local dest=$2

  if [[ ! -d "$source" ]]; then
    echo "Source directory not found" >&2
    return 1
  fi

  tar -czf "$dest" -C "$source" .
  echo "Backup created: $dest"
}
───────────────────────────────────────────────────────────────

File: backup_test.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

Your test must include:
  1. set_up and tear_down functions
  2. Test successful backup creation
  3. Test failure when source doesn't exist
  4. Mock or spy on tar command
  5. Verify backup file exists
  6. Check output message

TIP: Combine patterns from all previous lessons!
EOF

  local default_file="backup_test.sh"
  echo ""
  printf "When ready, enter TEST file path %s[%s]%s: " \
    "${_BASHUNIT_COLOR_FAINT}" "$default_file" "${_BASHUNIT_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function set_up() {
  source backup.sh
  # TODO: Create test directories and variables
}

function tear_down() {
  # TODO: Clean up test files
}

function test_successful_backup() {
  # TODO: Test backup creation
}

function test_backup_failure_when_source_missing() {
  # TODO: Test failure case
}

# Add more tests as needed:
# - Mock or spy on tar command
# - Verify backup file exists
# - Check output message
#
# TIPS:
# - Combine lifecycle (set_up/tear_down) with file assertions
# - Use spies to verify tar was called correctly
# - Test both success and failure scenarios
# - Mock external commands to avoid side effects'

    bashunit::learn::create_example_file "$test_file" "$template"
    return 1
  fi

  # Verify the test has key components
  local missing_components=()

  if ! grep -q "function set_up()" "$test_file"; then
    missing_components+=("set_up function")
  fi

  if ! grep -q "function tear_down()" "$test_file"; then
    missing_components+=("tear_down function")
  fi

  if [[ ${#missing_components[@]} -gt 0 ]]; then
    echo "${_BASHUNIT_COLOR_FAILED}Missing required components:${_BASHUNIT_COLOR_DEFAULT}"
    printf "  - %s\n" "${missing_components[@]}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  if bashunit::learn::run_lesson_test "$test_file" 10; then
    echo ""
    echo "${_BASHUNIT_COLOR_PASSED}${_BASHUNIT_COLOR_BOLD}"
    cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║                   🎉 CONGRATULATIONS! 🎉                       ║
║                                                                ║
║          You've completed all bashunit lessons!                ║
║                                                                ║
║  You now know how to:                                          ║
║    ✓ Write and run tests                                       ║
║    ✓ Use various assertions                                    ║
║    ✓ Manage test lifecycle                                     ║
║    ✓ Test functions and scripts                                ║
║    ✓ Mock external dependencies                                ║
║    ✓ Spy on function calls                                     ║
║    ✓ Use data providers                                        ║
║    ✓ Test exit codes                                           ║
║                                                                ║
║  Next steps:                                                   ║
║    • Explore https://bashunit.typeddevs.com                    ║
║    • Check out /common-patterns for more examples              ║
║    • Start testing your own bash scripts!                      ║
╚════════════════════════════════════════════════════════════════╝
EOF
    echo "${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
  fi
}
