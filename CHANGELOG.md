# Changelog

## [Unreleased](https://github.com/TypedDevs/bashunit/compare/0.16.0...main)

- Added support for Alpine (Linux Distro)
- Added optional file-path as 2nd arg to `--debug` option
- Added runtime per test
- Simplified total tests display on the header
- Renamed `BASHUNIT_TESTS_ENV` to `BASHUNIT_LOAD_FILE`
- Better handler runtime errors
- Display failing tests after running the entire suite

## [0.16.0](https://github.com/TypedDevs/bashunit/compare/0.15.0...0.16.0) - 2024-09-15

- Fixed `clock::now` can't locate Time when is not available
- Fixed failing tests when `command not found` and `unbound variable`
- Fixed total tests wrong number
- Update GitHub actions installation steps documentation
- Added `assert_files_equals`, `assert_files_not_equals`
- Added `BASHUNIT_TESTS_ENV`

## [0.15.0](https://github.com/TypedDevs/bashunit/compare/0.14.0...0.15.0) - 2024-09-01

- Fixed `--filter|-f` to work with `test_*` matching function name input.
- Added assertions to log file
- Rename the current `assert_equals` to `assert_same`
- Rename `assert_equals_ignore_colors` to `assert_equals` and ignore all special chars
- Data providers support multiple arguments
- Remove `multi-invokers` in favor of `data providers`
- Removing trailing slashes `/` from the test directories naming output.
- Align "Expected" and "but got" on `assert_*` fails message.
- Change `-v` as shortcut for `--version`
- Add `-vvv` as shortcut for `--verbose`
- Fix wrong commit id when installing beta
- Add display total tests upfront when running bashunit
- Add `BASHUNIT_` suffix to all .env config keys
    - BASHUNIT_SHOW_HEADER
    - BASHUNIT_HEADER_ASCII_ART
    - BASHUNIT_SIMPLE_OUTPUT
    - BASHUNIT_STOP_ON_FAILURE
    - BASHUNIT_SHOW_EXECUTION_TIME
    - BASHUNIT_DEFAULT_PATH
    - BASHUNIT_LOG_JUNIT
    - BASHUNIT_REPORT_HTML

## [0.14.0](https://github.com/TypedDevs/bashunit/compare/0.13.0...0.14.0) - 2024-07-14

- Fix echo does not break test execution results
- Add bashunit facade to enable custom assertions
- Document how to verify the `sha256sum` of the final executable
- Generate checksum on build
- Enable display execution time on macOS with `SHOW_EXECUTION_TIME`
- Support for displaying the clock without `perl` (for non-macOS)
- Enable strict mode
- Add `-l|--log-junit <log.xml>` option
- Add `-r|--report-html <report.html>` option
- Add `--debug` option
- Add `dump` and `dd` functions for local debugging

## [0.13.0](https://github.com/TypedDevs/bashunit/compare/0.12.0...0.13.0) - 2024-06-23

- Allow calling assertions standalone outside tests
- Add the latest version when installing beta
- Add `assert_line_count`
- Add hash to the installation script when installing a beta version
- Add GitHub Actions to installation doc

## [0.12.0](https://github.com/TypedDevs/bashunit/compare/0.11.0...0.12.0) - 2024-06-11

- Add missing assertion in non-stable versions
- Fix test with `rm` command in macOS
- Add multi-invokers; consolidate parameterized-testing documentation
- Add `fail()` function
- Remove all test mocks after each test case

## [0.11.0](https://github.com/TypedDevs/bashunit/compare/0.10.1...0.11.0) - 2024-03-02

- Add `--upgrade` option to `./bashunit`
- Remove support to deprecated `setUp`, `tearDown`, `setUpBeforeScript` and `tearDownAfterScript` functions
- Optimize test execution time
- Test functions are now run in the order they're defined in a test file
- Increase contrast of test results

## [0.10.1](https://github.com/TypedDevs/bashunit/compare/0.10.0...0.10.1) - 2023-11-13

- Fix find tests inside folder
- Add current date on beta installation version

## [0.10.0](https://github.com/TypedDevs/bashunit/compare/0.9.0...0.10.0) - 2023-11-09

- Installer no longer needs git
- Add `assert_contains_ignore_case`
- Add `assert_equals_ignore_colors`
- Add `assert_match_snapshot`
- Add `SHOW_EXECUTION_TIME` to environment config
- Add docs for environment variables
- Improve data provider output
- Add .env variable `DEFAULT_PATH`
- Improve duplicated function names output
- Allow installing (non-stable) beta using the installer

## [0.9.0](https://github.com/TypedDevs/bashunit/compare/0.8.0...0.9.0) - 2023-10-15

- Optimised docs Fonts (Serving directly from origin instead of Google Fonts _proxy_)
- Add Brew installation to docs
- Add `--help` option
- Add `-e|--env` option
- Add `-S|--stop-on-failure` option
- Add data_provider
- Add blog posts to the website
- Add `assert_string_not_starts_with`
- Add `assert_string_starts_with`
- Add `assert_string_ends_with`
- Add `assert_string_not_ends_with`
- Add `assert_less_than`
- Add `assert_less_or_equal_than`
- Add `assert_greater_than`
- Add `assert_greater_or_equal_than`

## [0.8.0](https://github.com/TypedDevs/bashunit/compare/0.7.0...0.8.0) - 2023-10-08

- Rename these functions from camelCase to snake_case:
    - `setUp` -> `set_up`
    - `tearDown` -> `tear_down`
    - `setUpBeforeScript` -> `set_up_before_script`
    - `tearDownAfterScript` -> `tear_down_after_script`
- Add --version option
- Add -v|--verbose option
- Add ASCII art logo
- Find all test on a directory
- Add skip and todo functions
- Add SIMPLE_OUTPUT to `.env`
- Allow using `main` or `latest` when using install.sh

## [0.7.0](https://github.com/TypedDevs/bashunit/compare/0.6.0...0.7.0) - 2023-10-02

- Added `--simple` argument for a simpler output
- Manage error when test execution fails
- Split install and build scripts
- Added these functions
    - `mock`
    - `spy`
    - `assert_have_been_called`
    - `assert_have_been_called_with`
    - `assert_have_been_called_times`
    - `assert_file_exists`
    - `assert_file_not_exists`
    - `assert_is_file_empty`
    - `assert_is_file`
    - `assert_directory_exists`
    - `assert_directory_not_exists`
    - `assert_is_directory`
    - `assert_is_directory_empty`
    - `assert_is_directory_not_empty`
    - `assert_is_directory_readable`
    - `assert_is_directory_not_readable`
    - `assert_is_directory_writable`
    - `assert_is_directory_not_writable`
- Rename assertions from camelCase to snake_case:
    - `assertEquals` -> `assert_equals`
    - `assertNotEquals` -> `assert_not_equals`
    - `assertEmpty` -> `assert_empty`
    - `assertNotEmpty` -> `assert_not_empty`
    - `assertContains` -> `assert_contains`
    - `assertNotContains` -> `assert_not_contains`
    - `assertMatches` -> `assert_matches`
    - `assertNotMatches` -> `assert_not_matches`
    - `assertExitCode` -> `assert_exit_code`
    - `assertSuccessfulCode` -> `assert_successful_code`
    - `assertGeneralError` -> `assert_general_error`
    - `assertCommandNotFound` -> `assert_command_not_found`
    - `assertArrayContains` -> `assert_array_contains`
    - `assertArrayNotContains` -> `assert_array_not_contains`

## [0.6.0](https://github.com/TypedDevs/bashunit/compare/0.5.0...0.6.0) - 2023-09-19

- Added `assertExitCode`
- Added `assertSuccessfulCode`
- Added `assertGeneralError`
- Added `assertCommandNotFound`
- Added `assertArrayContains`
- Added `assertArrayNotContains`
- Added `assertEmpty`
- Added `assertNotEmpty`
- Added `setUp`, `setUpBeforeScript`, `tearDown` and `tearDownAfterScript` function execution before and/or after test and/or script execution
- Improved the readability of the assert by using guard clause
- Update documentation
- Add support for the static analysis on macOS
- Fix bug with watcher for the development of bashunit
- Fix error on count assertions
- Added pipeline to add contributors to the readme
- Added documentation with VitePress
- Stop runner when found duplicate test functions

## [0.5.0](https://github.com/TypedDevs/bashunit/compare/0.4.0...0.5.0) - 2023-09-10

- Added logo
- Added `assertNotEquals`
- Added `assertMatches`
- Added `assertNotMatches`
- Added `make test/watch` to run your test every second
- Added time taken to run the test in ms (only to Linux)
- Simplified assertions over test results
- Added acceptance test to the library
- Added pre-commit to the project
- Allow parallel tests to run base on a .env configuration enabled by default
- Added static analysis tools to the deployment pipelines
- New summary output

## [0.4.0](https://github.com/TypedDevs/bashunit/compare/0.3.0...0.4.0) - 2023-09-08

- Better output colors and symbols
- Add option `--filter` to `./bashunit` script
    - Trigger tests filtered by name
- Change the output styles
    - Emojis
    - Colors
    - Bolds
- Added count to all test

## [0.3.0](https://github.com/TypedDevs/bashunit/compare/0.2.0...0.3.0) - 2023-09-07

- Added `assertContains`
- Added `assertNotContains`
- Display Passed tests in green, and Failed tests in red
- Avoid stop running tests after a failing one test

## [0.2.0](https://github.com/TypedDevs/bashunit/compare/0.1.0...0.2.0) - 2023-09-05

- Fix keeping in memory test func after running them
- Create a `./bashunit` entry point
- Change ROOT_DIR to BASHUNIT_ROOT_DIR
- Allow writing test with camelCase as well
- Allow running example log_test from anywhere

## [0.1.0](https://github.com/TypedDevs/bashunit/compare/27269c2...0.1.0) - 2023-09-04

- Added `assertEquals` function
