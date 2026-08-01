#!/usr/bin/env bash

# The interactive menu and the top-level dispatch loop.

##
# Print the learning menu
##
function bashunit::learn::print_menu() {
  cat <<EOF
${_BASHUNIT_COLOR_BOLD}${_BASHUNIT_COLOR_PASSED}bashunit${_BASHUNIT_COLOR_DEFAULT} - Interactive Learning

Choose a lesson:

  ${_BASHUNIT_COLOR_BOLD}1.${_BASHUNIT_COLOR_DEFAULT} Basics - Your First Test
  ${_BASHUNIT_COLOR_BOLD}2.${_BASHUNIT_COLOR_DEFAULT} Assertions - Testing Different Conditions
  ${_BASHUNIT_COLOR_BOLD}3.${_BASHUNIT_COLOR_DEFAULT} Setup & Teardown - Managing Test Lifecycle
  ${_BASHUNIT_COLOR_BOLD}4.${_BASHUNIT_COLOR_DEFAULT} Testing Functions - Unit Testing Patterns
  ${_BASHUNIT_COLOR_BOLD}5.${_BASHUNIT_COLOR_DEFAULT} Testing Scripts - Integration Testing
  ${_BASHUNIT_COLOR_BOLD}6.${_BASHUNIT_COLOR_DEFAULT} Mocking - Test Doubles and Mocks
  ${_BASHUNIT_COLOR_BOLD}7.${_BASHUNIT_COLOR_DEFAULT} Spies - Verifying Function Calls
  ${_BASHUNIT_COLOR_BOLD}8.${_BASHUNIT_COLOR_DEFAULT} Data Providers - Parameterized Tests
  ${_BASHUNIT_COLOR_BOLD}9.${_BASHUNIT_COLOR_DEFAULT} Exit Codes - Testing Success and Failure
  ${_BASHUNIT_COLOR_BOLD}10.${_BASHUNIT_COLOR_DEFAULT} Complete Challenge - Real World Scenario

  ${_BASHUNIT_COLOR_BOLD}p.${_BASHUNIT_COLOR_DEFAULT} Show Progress
  ${_BASHUNIT_COLOR_BOLD}r.${_BASHUNIT_COLOR_DEFAULT} Reset Progress
  ${_BASHUNIT_COLOR_BOLD}q.${_BASHUNIT_COLOR_DEFAULT} Quit

Enter your choice:
EOF
}


##
# Main learning loop
##
function bashunit::learn::start() {
  bashunit::learn::init

  trap 'bashunit::learn::cleanup' EXIT

  while true; do
    echo ""
    bashunit::learn::print_menu
    read -r choice
    echo ""

    case "$choice" in
    1) bashunit::learn::lesson_basics || true ;;
    2) bashunit::learn::lesson_assertions || true ;;
    3) bashunit::learn::lesson_lifecycle || true ;;
    4) bashunit::learn::lesson_functions || true ;;
    5) bashunit::learn::lesson_scripts || true ;;
    6) bashunit::learn::lesson_mocking || true ;;
    7) bashunit::learn::lesson_spies || true ;;
    8) bashunit::learn::lesson_data_providers || true ;;
    9) bashunit::learn::lesson_exit_codes || true ;;
    10) bashunit::learn::lesson_challenge || true ;;
    p) bashunit::learn::show_progress ;;
    r) bashunit::learn::reset_progress ;;
    q)
      echo "${_BASHUNIT_COLOR_PASSED}Happy testing!${_BASHUNIT_COLOR_DEFAULT}"
      break
      ;;
    *)
      echo "${_BASHUNIT_COLOR_FAILED}Invalid choice. Please try again.${_BASHUNIT_COLOR_DEFAULT}"
      ;;
    esac
  done

  bashunit::learn::cleanup
}

