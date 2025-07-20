#!/usr/bin/env bash

function console_header::print_version_with_env() {
  local filter=${1:-}
  local files=("${@:2}")

  if ! env::is_show_header_enabled; then
    return
  fi

  console_header::print_version "$filter" "${files[@]}"
}

function console_header::print_version() {
  local filter=${1:-}
  if [[ -n "$filter" ]]; then
   shift
  fi

  local files=("$@")
  local total_tests
  if [[ ${#files[@]} -eq 0 ]]; then
    total_tests=0
  else
    total_tests=$(helpers::find_total_tests "$filter" "${files[@]}")
  fi

  if env::is_header_ascii_art_enabled; then
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
    printf "${_COLOR_BOLD}${_COLOR_PASSED}bashunit${_COLOR_DEFAULT} - %s\n" "$BASHUNIT_VERSION"
  else
    printf "${_COLOR_BOLD}${_COLOR_PASSED}bashunit${_COLOR_DEFAULT} - %s | Tests: %s\n"\
      "$BASHUNIT_VERSION"\
      "$total_tests"
  fi
}

function console_header::print_help() {
    cat <<EOF
Usage:
  bashunit [PATH] [OPTIONS]

Arguments:
  PATH                      File or directory containing tests.
                            - Directories: runs all '*test.sh' files.
                            - Wildcards: supported to match multiple test files.
                            - Default search path is 'tests'

Options:
  -a, --assert <function args>
                            Run a core assert function standalone (outside test context).

  -b, --bench [file]
                            Run benchmark functions from file or '*.bench.sh' under
                            BASHUNIT_DEFAULT_PATH when no file is provided.

  --debug [file]
                            Enable shell debug mode. Logs to file if provided.

  -e, --env, --boot <file>
                            Load a custom env/bootstrap file to override .env or define globals.

  -f, --filter <name>
                            Only run tests matching the given name.

  -h, --help
                            Show this help message.

  --doc <?filter>
                            Display the documentation for assert functions. When a filter is
                            provided, only matching asserts will be shown.

  --init [dir]
                            Generate a sample test suite in current or specified directory.

  -l, --log-junit <file>
                            Write test results as JUnit XML report.

  -p, --parallel | --no-parallel
                            Run tests in parallel (default: enabled). Random execution order.

  -r, --report-html <file>
                            Write test results as an HTML report.

  -s, --simple | --detailed
                            Choose console output style (default: detailed).

  -S, --stop-on-failure
                            Stop execution immediately on the first failing test.

  --upgrade
                            Upgrade bashunit to the latest version.

  -vvv, --verbose
                            Show internal execution details per test.

  --version
                            Display the current version of bashunit.

More info: https://bashunit.typeddevs.com/command-line
EOF
}
