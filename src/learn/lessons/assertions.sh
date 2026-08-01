#!/usr/bin/env bash
# shellcheck disable=SC2016  # lesson text shows literal $vars in single quotes

# The "assertions" lesson.

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

  if [ ! -f "$test_file" ]; then
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

  if [ "$("$GREP" -c "assert_contains" "$test_file" || true)" -eq 0 ] ||
    [ "$("$GREP" -c "assert_matches" "$test_file" || true)" -eq 0 ] ||
    [ "$("$GREP" -c "assert_not_empty" "$test_file" || true)" -eq 0 ]; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should use all three assertion types${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 2
}

