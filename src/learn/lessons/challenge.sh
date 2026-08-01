#!/usr/bin/env bash

# The "challenge" lesson.

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

  if [ ! -d "$source" ]; then
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

  if [ ! -f "$test_file" ]; then
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
  local -a missing_components=()
  local missing_components_count=0

  if [ "$("$GREP" -c "function set_up()" "$test_file" || true)" -eq 0 ]; then
    missing_components[missing_components_count]="set_up function"
    missing_components_count=$((missing_components_count + 1))
  fi

  if [ "$("$GREP" -c "function tear_down()" "$test_file" || true)" -eq 0 ]; then
    missing_components[missing_components_count]="tear_down function"
    missing_components_count=$((missing_components_count + 1))
  fi

  if [ "$missing_components_count" -gt 0 ]; then
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
║    • Explore https://bashunit.com                              ║
║    • Check out /common-patterns for more examples              ║
║    • Start testing your own bash scripts!                      ║
╚════════════════════════════════════════════════════════════════╝
EOF
    echo "${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
  fi
}
