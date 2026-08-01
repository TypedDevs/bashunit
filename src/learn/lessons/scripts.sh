#!/usr/bin/env bash
# shellcheck disable=SC2016  # lesson text shows literal $vars in single quotes

# The "scripts" lesson.

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

  if [ ! -f "$test_file" ]; then
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

