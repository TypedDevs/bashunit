#!/usr/bin/env bash

##
# Interactive learning module for bashunit
# Provides guided tutorials and exercises to learn bashunit
##

declare -r LEARN_TEMP_DIR="/tmp/bashunit_learn_$$"
declare -r LEARN_PROGRESS_FILE="$HOME/.bashunit_learn_progress"

##
# Initialize learning environment
##
function learn::init() {
  mkdir -p "$LEARN_TEMP_DIR"
}

##
# Cleanup learning environment
##
function learn::cleanup() {
  rm -rf "$LEARN_TEMP_DIR"
}

##
# Print the learning menu
##
function learn::print_menu() {
  cat <<EOF
${_COLOR_BOLD}${_COLOR_PASSED}bashunit${_COLOR_DEFAULT} - Interactive Learning

Choose a lesson:

  ${_COLOR_BOLD}1.${_COLOR_DEFAULT} Basics - Your First Test
  ${_COLOR_BOLD}2.${_COLOR_DEFAULT} Assertions - Testing Different Conditions
  ${_COLOR_BOLD}3.${_COLOR_DEFAULT} Setup & Teardown - Managing Test Lifecycle
  ${_COLOR_BOLD}4.${_COLOR_DEFAULT} Testing Functions - Unit Testing Patterns
  ${_COLOR_BOLD}5.${_COLOR_DEFAULT} Testing Scripts - Integration Testing
  ${_COLOR_BOLD}6.${_COLOR_DEFAULT} Mocking - Test Doubles and Mocks
  ${_COLOR_BOLD}7.${_COLOR_DEFAULT} Spies - Verifying Function Calls
  ${_COLOR_BOLD}8.${_COLOR_DEFAULT} Data Providers - Parameterized Tests
  ${_COLOR_BOLD}9.${_COLOR_DEFAULT} Exit Codes - Testing Success and Failure
  ${_COLOR_BOLD}10.${_COLOR_DEFAULT} Complete Challenge - Real World Scenario

  ${_COLOR_BOLD}p.${_COLOR_DEFAULT} Show Progress
  ${_COLOR_BOLD}r.${_COLOR_DEFAULT} Reset Progress
  ${_COLOR_BOLD}q.${_COLOR_DEFAULT} Quit

Enter your choice:
EOF
}

##
# Main learning loop
##
function learn::start() {
  learn::init

  trap 'learn::cleanup' EXIT

  while true; do
    echo ""
    learn::print_menu
    read -r choice
    echo ""

    case "$choice" in
      1) learn::lesson_basics ;;
      2) learn::lesson_assertions ;;
      3) learn::lesson_lifecycle ;;
      4) learn::lesson_functions ;;
      5) learn::lesson_scripts ;;
      6) learn::lesson_mocking ;;
      7) learn::lesson_spies ;;
      8) learn::lesson_data_providers ;;
      9) learn::lesson_exit_codes ;;
      10) learn::lesson_challenge ;;
      p) learn::show_progress ;;
      r) learn::reset_progress ;;
      q)
        echo "${_COLOR_PASSED}Happy testing!${_COLOR_DEFAULT}"
        break
        ;;
      *)
        echo "${_COLOR_FAILED}Invalid choice. Please try again.${_COLOR_DEFAULT}"
        ;;
    esac
  done

  learn::cleanup
}

##
# Mark lesson as completed
##
function learn::mark_completed() {
  local lesson=$1
  echo "$lesson" >> "$LEARN_PROGRESS_FILE"
}

##
# Check if lesson is completed
##
function learn::is_completed() {
  local lesson=$1
  [[ -f "$LEARN_PROGRESS_FILE" ]] && grep -q "^$lesson$" "$LEARN_PROGRESS_FILE"
}

##
# Show learning progress
##
function learn::show_progress() {
  if [[ ! -f "$LEARN_PROGRESS_FILE" ]]; then
    echo "${_COLOR_INCOMPLETE}No progress yet. Start with lesson 1!${_COLOR_DEFAULT}"
    return
  fi

  echo "${_COLOR_BOLD}Your Progress:${_COLOR_DEFAULT}"
  echo ""

  local total_lessons=10
  local completed=0

  for i in $(seq 1 $total_lessons); do
    if learn::is_completed "lesson_$i"; then
      echo "  ${_COLOR_PASSED}✓${_COLOR_DEFAULT} Lesson $i completed"
      ((completed++))
    else
      echo "  ${_COLOR_INCOMPLETE}○${_COLOR_DEFAULT} Lesson $i"
    fi
  done

  echo ""
  echo "Progress: $completed/$total_lessons lessons completed"

  if [[ $completed -eq $total_lessons ]]; then
    echo ""
    echo "${_COLOR_PASSED}${_COLOR_BOLD}🎉 Congratulations! You've completed all lessons!${_COLOR_DEFAULT}"
  fi

  read -p "Press Enter to continue..." -r
}

##
# Reset learning progress
##
function learn::reset_progress() {
  rm -f "$LEARN_PROGRESS_FILE"
  echo "${_COLOR_PASSED}Progress reset successfully.${_COLOR_DEFAULT}"
  read -p "Press Enter to continue..." -r
}

##
# Create the example file automatically
# Arguments: $1 - filename, $2 - file content
##
function learn::create_example_file() {
  local filename=$1
  local content=$2

  echo ""
  echo "Creating example file ${_COLOR_BOLD}$filename${_COLOR_DEFAULT}..."
  echo "$content" > "$filename"
  chmod +x "$filename"
  echo "${_COLOR_PASSED}✓ Created $filename${_COLOR_DEFAULT}"
  echo ""
  echo "File created! Edit it to complete the TODO items, then run this lesson again."
  read -p "Press Enter to continue..." -r
  return 0
}

##
# Run a lesson test and check results
##
function learn::run_lesson_test() {
  local test_file=$1
  local lesson_number=$2

  echo "${_COLOR_BOLD}Running your test...${_COLOR_DEFAULT}"
  echo ""

  if "$BASHUNIT_ROOT_DIR/bashunit" "$test_file" --simple; then
    echo ""
    echo "${_COLOR_PASSED}${_COLOR_BOLD}✓ Excellent! Lesson $lesson_number completed!${_COLOR_DEFAULT}"
    learn::mark_completed "lesson_$lesson_number"
    read -p "Press Enter to continue..." -r
    return 0
  else
    echo ""
    echo "${_COLOR_FAILED}Not quite right. Review the requirements and try again.${_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi
}

##
# Lesson 1: Basics - Your First Test
##
function learn::lesson_basics() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║                    Lesson 1: Your First Test                   ║
╚════════════════════════════════════════════════════════════════╝

Welcome to bashunit! Let's write your first test.

A test is a function that starts with 'test_' and uses assertions
to verify behavior.

TASK: Create a test file that checks if two values are equal.

Create this file and fill in the assertion:

File: first_test.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function test_bashunit_works() {
  # Use assert_same to check if "hello" equals "hello"
  # TODO: Write your assertion here
}
───────────────────────────────────────────────────────────────

TIP: The assert_same function takes two arguments:
     assert_same "expected" "actual"
EOF

  local default_file="first_test.sh"
  echo ""
  printf "When ready, enter file path %s[%s]%s: " "${_COLOR_FAINT}" "$default_file" "${_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function test_bashunit_works() {
  # Use assert_same to check if "hello" equals "hello"
  # TODO: Write your assertion here
}'

    learn::create_example_file "$test_file" "$template"
    return 1
  fi

  # Check if file contains assert_same
  if ! grep -q "assert_same" "$test_file"; then
    echo "${_COLOR_FAILED}Your test should use assert_same${_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  learn::run_lesson_test "$test_file" 1
}

##
# Lesson 2: Assertions - Testing Different Conditions
##
function learn::lesson_assertions() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║              Lesson 2: Testing Different Conditions            ║
╚════════════════════════════════════════════════════════════════╝

bashunit provides many assertion functions for different checks:

  • assert_same - exact equality
  • assert_contains - substring check
  • assert_matches - regex pattern
  • assert_not_same - inequality
  • assert_empty - checks if value is empty
  • assert_not_empty - checks if value is not empty

TASK: Write a test file with 3 different assertions.

File: assertions_test.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function test_multiple_assertions() {
  local message="Hello, bashunit!"

  # 1. Check that message contains "bashunit"
  # TODO: Use assert_contains

  # 2. Check that message matches the pattern "Hello.*!"
  # TODO: Use assert_matches

  # 3. Check that message is not empty
  # TODO: Use assert_not_empty
}
───────────────────────────────────────────────────────────────
EOF

  local default_file="assertions_test.sh"
  echo ""
  printf "When ready, enter file path %s[%s]%s: " "${_COLOR_FAINT}" "$default_file" "${_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function test_multiple_assertions() {
  local message="Hello, bashunit!"

  # 1. Check that message contains "bashunit"
  # TODO: Use assert_contains

  # 2. Check that message matches the pattern "Hello.*!"
  # TODO: Use assert_matches

  # 3. Check that message is not empty
  # TODO: Use assert_not_empty
}'

    learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if ! grep -q "assert_contains" "$test_file" || \
     ! grep -q "assert_matches" "$test_file" || \
     ! grep -q "assert_not_empty" "$test_file"; then
    echo "${_COLOR_FAILED}Your test should use all three assertion types${_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  learn::run_lesson_test "$test_file" 2
}

##
# Lesson 3: Setup & Teardown - Managing Test Lifecycle
##
function learn::lesson_lifecycle() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║           Lesson 3: Setup and Teardown Functions               ║
╚════════════════════════════════════════════════════════════════╝

Tests often need preparation and cleanup. bashunit provides:

  • set_up() - runs before EACH test
  • tear_down() - runs after EACH test
  • set_up_before_script() - runs once before ALL tests
  • tear_down_after_script() - runs once after ALL tests

TASK: Create a test that uses setup and teardown to manage files.

File: lifecycle_test.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function set_up() {
  # Create a temp file before each test
  # TODO: Create TEST_FILE variable with path /tmp/test_$$
  # TODO: Write "test content" to TEST_FILE
}

function tear_down() {
  # Clean up after each test
  # TODO: Remove TEST_FILE
}

function test_file_exists() {
  # TODO: Use assert_file_exists to check TEST_FILE exists
}

function test_file_has_content() {
  # TODO: Use assert_file_contains to check for "test content"
}
───────────────────────────────────────────────────────────────
EOF

  local default_file="lifecycle_test.sh"
  echo ""
  printf "When ready, enter file path %s[%s]%s: " "${_COLOR_FAINT}" "$default_file" "${_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function set_up() {
  # Create a temp file before each test
  # TODO: Create TEST_FILE variable with path /tmp/test_$$
  # TODO: Write "test content" to TEST_FILE
}

function tear_down() {
  # Clean up after each test
  # TODO: Remove TEST_FILE
}

function test_file_exists() {
  # TODO: Use assert_file_exists to check TEST_FILE exists
}

function test_file_has_content() {
  # TODO: Use assert_file_contains to check for "test content"
}'

    learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if ! grep -q "function set_up()" "$test_file" || \
     ! grep -q "function tear_down()" "$test_file"; then
    echo "${_COLOR_FAILED}Your test should define set_up and tear_down functions${_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  learn::run_lesson_test "$test_file" 3
}

##
# Lesson 4: Testing Functions
##
function learn::lesson_functions() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║              Lesson 4: Testing Bash Functions                  ║
╚════════════════════════════════════════════════════════════════╝

To test functions, source the file containing them, then call them
in your tests.

TASK: Create a script with a function, then test it.

File: calculator.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function add() {
  echo $(($1 + $2))
}
───────────────────────────────────────────────────────────────

File: calculator_test.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function set_up() {
  # TODO: Source calculator.sh
}

function test_add_positive_numbers() {
  # TODO: Test that add 2 3 returns "5"
}

function test_add_negative_numbers() {
  # TODO: Test that add -2 -3 returns "-5"
}
───────────────────────────────────────────────────────────────
EOF

  local default_file="calculator_test.sh"
  echo ""
  printf "When ready, enter TEST file path %s[%s]%s: " "${_COLOR_FAINT}" "$default_file" "${_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function set_up() {
  # TODO: Source calculator.sh
}

function test_add_positive_numbers() {
  # TODO: Test that add 2 3 returns "5"
}

function test_add_negative_numbers() {
  # TODO: Test that add -2 -3 returns "-5"
}'

    learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if ! grep -q "source" "$test_file"; then
    echo "${_COLOR_FAILED}Your test should source the calculator.sh file${_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  learn::run_lesson_test "$test_file" 4
}

##
# Lesson 5: Testing Scripts
##
function learn::lesson_scripts() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║                 Lesson 5: Testing Bash Scripts                 ║
╚════════════════════════════════════════════════════════════════╝

Scripts that execute commands directly are tested differently.
Run them and capture their output.

TASK: Create a script and test its output.

File: greeter.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash
name=${1:-World}
echo "Hello, $name!"
───────────────────────────────────────────────────────────────

File: greeter_test.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function test_default_greeting() {
  local output
  # TODO: Run greeter.sh and capture output

  # TODO: Assert output contains "Hello, World!"
}

function test_custom_greeting() {
  local output
  # TODO: Run greeter.sh with argument "Alice"

  # TODO: Assert output contains "Hello, Alice!"
}
───────────────────────────────────────────────────────────────

TIP: Use command substitution: output=$(./greeter.sh)
EOF

  local default_file="greeter_test.sh"
  echo ""
  printf "When ready, enter TEST file path %s[%s]%s: " "${_COLOR_FAINT}" "$default_file" "${_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function test_default_greeting() {
  local output
  # TODO: Run greeter.sh and capture output

  # TODO: Assert output contains "Hello, World!"
}

function test_custom_greeting() {
  local output
  # TODO: Run greeter.sh with argument "Alice"

  # TODO: Assert output contains "Hello, Alice!"
}'

    learn::create_example_file "$test_file" "$template"
    return 1
  fi

  learn::run_lesson_test "$test_file" 5
}

##
# Lesson 6: Mocking
##
function learn::lesson_mocking() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║               Lesson 6: Mocking External Commands              ║
╚════════════════════════════════════════════════════════════════╝

Mocks let you override external commands or functions to control
their behavior in tests.

TASK: Test a function that uses external commands.

File: system_info.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function get_system_info() {
  echo "OS: $(uname -s)"
}
───────────────────────────────────────────────────────────────

File: system_info_test.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function set_up() {
  source system_info.sh
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
EOF

  local default_file="system_info_test.sh"
  echo ""
  printf "When ready, enter TEST file path %s[%s]%s: " "${_COLOR_FAINT}" "$default_file" "${_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [[ ! -f "$test_file" ]]; then
    local template='#!/usr/bin/env bash

function set_up() {
  source system_info.sh
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

    learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if ! grep -q "mock" "$test_file"; then
    echo "${_COLOR_FAILED}Your test should use mock${_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  learn::run_lesson_test "$test_file" 6
}

##
# Lesson 7: Spies
##
function learn::lesson_spies() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║              Lesson 7: Spies - Verifying Calls                 ║
╚════════════════════════════════════════════════════════════════╝

Spies let you verify that functions were called with specific
arguments or a certain number of times.

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
EOF

  local default_file="deploy_test.sh"
  echo ""
  printf "When ready, enter TEST file path %s[%s]%s: " "${_COLOR_FAINT}" "$default_file" "${_COLOR_DEFAULT}"
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

    learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if ! grep -q "spy" "$test_file"; then
    echo "${_COLOR_FAILED}Your test should use spy${_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  learn::run_lesson_test "$test_file" 7
}

##
# Lesson 8: Data Providers
##
function learn::lesson_data_providers() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║           Lesson 8: Data Providers - Parameterized Tests       ║
╚════════════════════════════════════════════════════════════════╝

Data providers let you run the same test with different inputs.
Define a function that echoes test data, one per line.

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
  # Hint: assert_successful_code "is_valid_email '$1'"
}

function data_provider_invalid_emails() {
  # TODO: Echo invalid email addresses, one per line
  # Example: echo "not-an-email"
}

function test_invalid_emails() {
  # TODO: Assert is_valid_email fails
  # Hint: assert_general_error "is_valid_email '$1'"
}
───────────────────────────────────────────────────────────────
EOF

  local default_file="validator_test.sh"
  echo ""
  printf "When ready, enter TEST file path %s[%s]%s: " "${_COLOR_FAINT}" "$default_file" "${_COLOR_DEFAULT}"
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
  # Hint: assert_successful_code "is_valid_email '\''$1'\''"
}

function data_provider_invalid_emails() {
  # TODO: Echo invalid email addresses, one per line
  # Example: echo "not-an-email"
}

function test_invalid_emails() {
  # TODO: Assert is_valid_email fails
  # Hint: assert_general_error "is_valid_email '\''$1'\''"
}'

    learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if ! grep -q "function data_provider_" "$test_file"; then
    echo "${_COLOR_FAILED}Your test should define data provider functions${_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  learn::run_lesson_test "$test_file" 8
}

##
# Lesson 9: Exit Codes
##
function learn::lesson_exit_codes() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║             Lesson 9: Testing Exit Codes                       ║
╚════════════════════════════════════════════════════════════════╝

Exit codes indicate success (0) or failure (non-zero). bashunit
provides assertions to test them:

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
EOF

  local default_file="checker_test.sh"
  echo ""
  printf "When ready, enter TEST file path %s[%s]%s: " "${_COLOR_FAINT}" "$default_file" "${_COLOR_DEFAULT}"
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

    learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if ! grep -q "assert_successful_code\|assert_exit_code\|assert_general_error" "$test_file"; then
    echo "${_COLOR_FAILED}Your test should use exit code assertions${_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  learn::run_lesson_test "$test_file" 9
}

##
# Lesson 10: Complete Challenge
##
function learn::lesson_challenge() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║          Lesson 10: Complete Challenge - Backup Script         ║
╚════════════════════════════════════════════════════════════════╝

FINAL CHALLENGE: Combine everything you've learned!

Create a backup script and comprehensive tests.

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
  printf "When ready, enter TEST file path %s[%s]%s: " "${_COLOR_FAINT}" "$default_file" "${_COLOR_DEFAULT}"
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
# - Check output message'

    learn::create_example_file "$test_file" "$template"
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
    echo "${_COLOR_FAILED}Missing required components:${_COLOR_DEFAULT}"
    printf "  - %s\n" "${missing_components[@]}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  if learn::run_lesson_test "$test_file" 10; then
    echo ""
    echo "${_COLOR_PASSED}${_COLOR_BOLD}"
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
    echo "${_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
  fi
}
