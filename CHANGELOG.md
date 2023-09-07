# Changelog

### Unreleased

- Add option `--filter` to `./bashunit` script
  - To trigger tests filtered by name

### 0.3.0
### 2023-09-07

- Added `assertContains`
- Added `assertNotContains`
- Display Passed tests in green, and Failed tests in red
- Avoid stop running tests after a failing one test
 
### 0.2.0
### 2023-09-05

- Fix keeping in memory test func after running them
- Create a `./bashunit` entry point
- Change ROOT_DIR to BASH_UNIT_ROOT_DIR
- Allow writing test with camelCase as well
- Allow running example log_test from anywhere

### 0.1.0
### 2023-09-04

- Added `assertEquals` function
