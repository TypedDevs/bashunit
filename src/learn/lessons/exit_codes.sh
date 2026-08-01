#!/usr/bin/env bash
# shellcheck disable=SC2016  # lesson text shows literal $vars in single quotes

# The "exit_codes" lesson.

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
  if [ ! -e "$1" ]; then
    echo "File not found" >&2
    return 127
  fi

  if [ ! -r "$1" ]; then
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

  if [ ! -f "$test_file" ]; then
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

  local _exit_assert_pattern="assert_successful_code\|assert_exit_code\|assert_general_error"
  if [ "$("$GREP" -c "$_exit_assert_pattern" "$test_file" || true)" -eq 0 ]; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should use exit code assertions${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 9
}

