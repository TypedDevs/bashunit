#!/usr/bin/env bash
# shellcheck disable=SC2016  # lesson text shows literal $vars in single quotes

# The "data_providers" lesson.

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
  local email_pattern='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
  [ "$(echo "$1" | "$GREP" -cE "$email_pattern" || true)" -gt 0 ]
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

  if [ ! -f "$test_file" ]; then
    local template='#!/usr/bin/env bash

function set_up() {
  source validator.sh
}

function data_provider_valid_emails() {
  # TODO: Echo valid email addresses, one per line
  # Example: echo "user@example.com"
  :
}

function test_valid_emails() {
  # $1 contains the email from data provider
  # TODO: Assert is_valid_email succeeds
  # Hint: assert_successful_code "is_valid_email \"$1\""
  :
}

function data_provider_invalid_emails() {
  # TODO: Echo invalid email addresses, one per line
  # Example: echo "not-an-email"
  :
}

function test_invalid_emails() {
  # TODO: Assert is_valid_email fails
  # Hint: assert_general_error "is_valid_email \"$1\""
  :
}'

    bashunit::learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if [ "$(bashunit::learn::count_in_code "$test_file" "function data_provider_")" -eq 0 ]; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should define data provider functions${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 8
}

