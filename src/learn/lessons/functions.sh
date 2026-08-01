#!/usr/bin/env bash
# shellcheck disable=SC2016  # lesson text shows literal $vars in single quotes

# The "functions" lesson.

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

  if [ ! -f "$test_file" ]; then
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

  if [ "$("$GREP" -c "source" "$test_file" || true)" -eq 0 ]; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should source the calculator.sh file${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 4
}

