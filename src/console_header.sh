#!/usr/bin/env bash

function bashunit::console_header::print_version_with_env() {
  local filter=${1:-}
  local files=("${@:2}")

  if ! bashunit::env::is_show_header_enabled; then
    return
  fi

  bashunit::console_header::print_version "$filter" "${files[@]}"

  if bashunit::env::is_dev_mode_enabled; then
    printf "%sDev log:%s %s\n" "${_BASHUNIT_COLOR_INCOMPLETE}" "${_BASHUNIT_COLOR_DEFAULT}" "$BASHUNIT_DEV_LOG"
  fi
}

function bashunit::console_header::print_version() {
  local filter=${1:-}
  if [[ -n "$filter" ]]; then
   shift
  fi

  local files=("$@")
  local total_tests
  if [[ ${#files[@]} -eq 0 ]]; then
    total_tests=0
  elif bashunit::parallel::is_enabled && bashunit::env::is_simple_output_enabled; then
    # Skip counting in parallel+simple mode for faster startup
    total_tests=0
  else
    total_tests=$(bashunit::helper::find_total_tests "$filter" "${files[@]}")
  fi

  if bashunit::env::is_header_ascii_art_enabled; then
    cat <<EOF
 _               _                   _
| |__   __ _ ___| |__  __ __ ____ (_) |_
| '_ \ / _' / __| '_ \| | | | '_ \| | __|
| |_) | (_| \__ \ | | | |_| | | | | | |_
|_.__/ \__,_|___/_| |_|\___/|_| |_|_|\__|
EOF
    if [ "$total_tests" -eq 0 ]; then
      printf "%s\n" "$BASHUNIT_VERSION"
    else
      printf "%s | Tests: %s\n" "$BASHUNIT_VERSION" "$total_tests"
    fi
    return
  fi

  if [ "$total_tests" -eq 0 ]; then
    printf "${_BASHUNIT_COLOR_BOLD}${_BASHUNIT_COLOR_PASSED}bashunit${_BASHUNIT_COLOR_DEFAULT} - %s\n" "$BASHUNIT_VERSION"
  else
    printf "${_BASHUNIT_COLOR_BOLD}${_BASHUNIT_COLOR_PASSED}bashunit${_BASHUNIT_COLOR_DEFAULT} - %s | Tests: %s\n"\
      "$BASHUNIT_VERSION"\
      "$total_tests"
  fi
}

function bashunit::console_header::print_help() {
    cat <<EOF
Usage: bashunit <command> [arguments] [options]

Commands:
  test [path]       Run tests (default command)
  bench [path]      Run benchmarks
  doc [filter]      Display assertion documentation
  init [dir]        Initialize a new test directory
  learn             Start interactive tutorial
  upgrade           Upgrade bashunit to latest version

Global Options:
  -h, --help        Show this help message
  -v, --version     Display the current version

Run 'bashunit <command> --help' for command-specific options.

Examples:
  bashunit test tests/              Run all tests in directory
  bashunit tests/                   Run all tests (shorthand)
  bashunit bench                    Run all benchmarks
  bashunit doc contains             Show docs for 'contains' assertions
  bashunit init                     Initialize test directory

More info: https://bashunit.typeddevs.com/command-line
EOF
}

function bashunit::console_header::print_test_help() {
    cat <<EOF
Usage: bashunit test [path] [options]
       bashunit [path] [options]

Run test files. If no path is provided, searches for tests in BASHUNIT_DEFAULT_PATH.

Arguments:
  path                        File or directory containing tests
                              - Directories: runs all '*test.sh' files
                              - Wildcards: supported to match multiple files

Options:
  -a, --assert <fn> <args>    Run a standalone assert function
  -e, --env, --boot <file>    Load a custom env/bootstrap file
  -f, --filter <name>         Only run tests matching the name
  -l, --log-junit <file>      Write JUnit XML report
  -p, --parallel              Run tests in parallel (default)
  --no-parallel               Run tests sequentially
  -r, --report-html <file>    Write HTML report
  -s, --simple                Simple output (dots)
  --detailed                  Detailed output (default)
  -S, --stop-on-failure       Stop on first failure
  -vvv, --verbose             Show execution details
  --debug [file]              Enable shell debug mode
  --no-output                 Suppress all output
  -h, --help                  Show this help message

Examples:
  bashunit test tests/
  bashunit test tests/unit/ --parallel
  bashunit test --filter "user" tests/
  bashunit test -a equals "foo" "foo"
EOF
}

function bashunit::console_header::print_bench_help() {
    cat <<EOF
Usage: bashunit bench [path] [options]

Run benchmark files. Searches for '*bench.sh' files.

Arguments:
  path                        File or directory containing benchmarks

Options:
  -e, --env, --boot <file>    Load a custom env/bootstrap file
  -f, --filter <name>         Only run benchmarks matching the name
  -s, --simple                Simple output
  --detailed                  Detailed output (default)
  -vvv, --verbose             Show execution details
  -h, --help                  Show this help message

Examples:
  bashunit bench
  bashunit bench benchmarks/
  bashunit bench --filter "parse"
EOF
}

function bashunit::console_header::print_doc_help() {
    cat <<EOF
Usage: bashunit doc [filter]

Display documentation for assertion functions.

Arguments:
  filter                      Optional filter to show only matching assertions

Examples:
  bashunit doc                Show all assertions
  bashunit doc equals         Show assertions containing 'equals'
  bashunit doc file           Show file-related assertions
EOF
}

function bashunit::console_header::print_init_help() {
    cat <<EOF
Usage: bashunit init [directory]

Initialize a new test directory with sample files.

Arguments:
  directory                   Target directory (default: tests)

Creates:
  - bootstrap.sh              Setup file for test configuration
  - example_test.sh           Sample test file to get started

Examples:
  bashunit init               Create tests/ directory
  bashunit init spec          Create spec/ directory
EOF
}

function bashunit::console_header::print_learn_help() {
    cat <<EOF
Usage: bashunit learn

Start the interactive learning tutorial.

The tutorial includes 10 progressive lessons:
  1. Basics - Your First Test
  2. Assertions - Testing Different Conditions
  3. Setup & Teardown - Managing Test Lifecycle
  4. Testing Functions - Unit Testing Patterns
  5. Testing Scripts - Integration Testing
  6. Mocking - Test Doubles and Mocks
  7. Spies - Verifying Function Calls
  8. Data Providers - Parameterized Tests
  9. Exit Codes - Testing Success and Failure
  10. Complete Challenge - Real World Scenario

Your progress is saved automatically.
EOF
}

function bashunit::console_header::print_upgrade_help() {
    cat <<EOF
Usage: bashunit upgrade

Upgrade bashunit to the latest version.

Downloads and installs the newest release from GitHub.
EOF
}
