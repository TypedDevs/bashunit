#!/usr/bin/env bash
# shellcheck disable=SC2016  # lesson text shows literal $vars in single quotes

# The "mocking" lesson.

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

  if [ ! -f "$test_file" ]; then
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

  if [ "$(bashunit::learn::count_in_code "$test_file" "mock")" -eq 0 ]; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should use mock${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 6
}

