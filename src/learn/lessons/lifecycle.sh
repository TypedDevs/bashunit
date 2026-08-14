#!/usr/bin/env bash
# shellcheck disable=SC2016  # lesson text shows literal $vars in single quotes

# The "lifecycle" lesson.

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

  if [ ! -f "$test_file" ]; then
    local template='#!/usr/bin/env bash

function set_up() {
  # Create a temp file before each test
  # TODO: export TEST_FILE="/tmp/test_$$"
  # TODO: echo "test content" > "$TEST_FILE"
  :
}

function tear_down() {
  # Clean up after each test
  # TODO: rm -f "$TEST_FILE"
  :
}

function test_file_exists() {
  # TODO: assert_file_exists "$TEST_FILE"
  :
}

function test_file_has_content() {
  # TODO: assert_file_contains "test content" "$TEST_FILE"
  :
}'

    bashunit::learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if [ "$("$GREP" -c "function set_up()" "$test_file" || true)" -eq 0 ] ||
    [ "$("$GREP" -c "function tear_down()" "$test_file" || true)" -eq 0 ]; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should define set_up and tear_down functions${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 3
}

