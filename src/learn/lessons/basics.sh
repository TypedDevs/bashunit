#!/usr/bin/env bash

# The "basics" lesson.

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

  if [ ! -f "$test_file" ]; then
    local template='#!/usr/bin/env bash

function test_bashunit_works() {
  # TODO: Use assert_same to check if "hello" equals "hello"
  # Hint: assert_same "expected" "actual"
}'

    bashunit::learn::create_example_file "$test_file" "$template"
    return 1
  fi

  # Check if file contains assert_same
  if [ "$("$GREP" -c "assert_same" "$test_file" || true)" -eq 0 ]; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should use assert_same${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 1
}

