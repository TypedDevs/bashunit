# Code Coverage

Code coverage measures how much of your source code is executed when running tests. It helps identify untested code paths and ensures your test suite exercises the important parts of your application.

## Quick Start

Enable coverage tracking with the `--coverage` flag:

::: code-group
```bash [Basic usage]
bashunit tests/ --coverage
```
```bash [With custom paths]
bashunit tests/ --coverage --coverage-paths src/
```
```bash [Output]
bashunit - 0.30.0 | Tests: 5
.....

Tests:      5 passed, 5 total
Assertions: 12 passed, 12 total

 All tests passed
Time taken: 1 s

Coverage Report
---------------
src/math.sh                                2/  3 lines ( 66%)
src/utils.sh                               8/ 10 lines ( 80%)
---------------
Total: 10/13 (76%)

Coverage report written to: coverage/lcov.info
```
:::

## How It Works

bashunit uses Bash's built-in `DEBUG` trap mechanism to track line execution:

1. **Trap Setup**: When coverage is enabled, a DEBUG trap is set that fires before every command execution
2. **Line Recording**: Each executed line's file path and line number are recorded
3. **Filtering**: Only files matching your coverage paths (and not excluded) are tracked
4. **Aggregation**: After tests complete, hit data is aggregated and reported

::: tip Performance
The DEBUG trap adds overhead to test execution. For large test suites, consider running coverage periodically rather than on every test run.
:::

## Configuration

### Command Line Options

| Option | Description |
|--------|-------------|
| `--coverage` | Enable code coverage tracking |
| `--coverage-paths <paths>` | Comma-separated paths to track (default: `src/`) |
| `--coverage-exclude <patterns>` | Comma-separated exclusion patterns |
| `--coverage-report <file>` | LCOV report output path (default: `coverage/lcov.info`) |
| `--coverage-min <percent>` | Minimum coverage threshold (fails if below) |
| `--no-coverage-report` | Disable LCOV file generation (console only) |

### Environment Variables

You can also configure coverage via environment variables in your `.env` file:

```bash
# Enable coverage
BASHUNIT_COVERAGE=true

# Paths to track (comma-separated)
BASHUNIT_COVERAGE_PATHS=src/,lib/

# Patterns to exclude (comma-separated)
BASHUNIT_COVERAGE_EXCLUDE=tests/*,vendor/*,*_test.sh

# LCOV report output path
BASHUNIT_COVERAGE_REPORT=coverage/lcov.info

# Minimum coverage percentage (optional)
BASHUNIT_COVERAGE_MIN=80

# Color thresholds for console output
BASHUNIT_COVERAGE_THRESHOLD_LOW=50   # Red below this
BASHUNIT_COVERAGE_THRESHOLD_HIGH=80  # Green above this, yellow between
```

## Examples

### Basic Coverage

Track coverage for the default `src/` directory:

::: code-group
```bash [Command]
bashunit tests/ --coverage
```
:::

### Custom Source Paths

Track multiple directories:

::: code-group
```bash [Command]
bashunit tests/ --coverage --coverage-paths "src/,lib/,bin/"
```
```bash [.env]
BASHUNIT_COVERAGE_PATHS=src/,lib/,bin/
```
:::

### Exclusion Patterns

Exclude specific files or directories:

::: code-group
```bash [Command]
bashunit tests/ --coverage --coverage-exclude "vendor/*,*_mock.sh,deprecated/"
```
```bash [.env]
BASHUNIT_COVERAGE_EXCLUDE=vendor/*,*_mock.sh,deprecated/
```
:::

### Setting Minimum Threshold

Fail the test run if coverage drops below a threshold:

::: code-group
```bash [Command]
bashunit tests/ --coverage --coverage-min 80
```
```[Output - Passing]
Coverage Report
---------------
src/math.sh                               10/ 12 lines ( 83%)
---------------
Total: 10/12 (83%)
```
```[Output - Failing]
Coverage Report
---------------
src/math.sh                                5/ 12 lines ( 41%)
---------------
Total: 5/12 (41%)

Coverage 41% is below minimum 80%
```
:::

### Console-Only Output

Skip generating the LCOV file:

::: code-group
```bash [Command]
bashunit tests/ --coverage --no-coverage-report
```
:::

### CI/CD Integration

Generate coverage for CI tools like Codecov or Coveralls:

::: code-group
```yaml [GitHub Actions]
- name: Run tests with coverage
  run: bashunit tests/ --coverage --coverage-min 80

- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v4
  with:
    files: ./coverage/lcov.info
    fail_ci_if_error: true
```
```yaml [GitLab CI]
test:
  script:
    - bashunit tests/ --coverage
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/lcov.info
```
:::

## Understanding the Console Report

The console report shows coverage per file with color coding:

```
Coverage Report
---------------
src/math.sh                       10/ 12 lines ( 83%)  # Green (>= 80%)
src/parser.sh                      7/ 10 lines ( 70%)  # Yellow (50-79%)
src/legacy.sh                      2/ 15 lines ( 13%)  # Red (< 50%)
---------------
Total: 19/37 (51%)
```

**Color thresholds** (configurable via environment variables):
- **Green**: Coverage >= 80% (`BASHUNIT_COVERAGE_THRESHOLD_HIGH`)
- **Yellow**: Coverage 50-79%
- **Red**: Coverage < 50% (`BASHUNIT_COVERAGE_THRESHOLD_LOW`)

## Understanding LCOV Format

The `coverage/lcov.info` file uses the industry-standard LCOV format, compatible with most CI coverage tools.

### File Structure

```
TN:
SF:/path/to/source/file.sh
DA:1,0
DA:2,5
DA:3,5
LF:3
LH:2
end_of_record
```

### Field Reference

| Field | Description | Example |
|-------|-------------|---------|
| `TN:` | Test Name (usually empty) | `TN:` |
| `SF:` | Source File path | `SF:/home/user/project/src/math.sh` |
| `DA:` | Line Data: `line_number,hit_count` | `DA:15,3` (line 15 hit 3 times) |
| `LF:` | Lines Found (total executable lines) | `LF:25` |
| `LH:` | Lines Hit (lines with hits > 0) | `LH:20` |
| `end_of_record` | Marks end of file entry | `end_of_record` |

### Example Breakdown

Given this source file `src/math.sh`:

```bash
#!/usr/bin/env bash           # Line 1 - executable (shebang)
function add() {              # Line 2 - not executable (function declaration)
  echo $(($1 + $2))           # Line 3 - executable
}                             # Line 4 - not executable (closing brace)
function multiply() {         # Line 5 - not executable (function declaration)
  echo $(($1 * $2))           # Line 6 - executable
}                             # Line 7 - not executable (closing brace)
```

If tests call `add` twice but never call `multiply`, the LCOV output would be:

```
TN:
SF:/path/to/src/math.sh
DA:1,0
DA:3,2
DA:6,0
LF:3
LH:1
end_of_record
```

**Interpretation:**
- Line 1 (shebang): 0 hits (only executed when script is run directly)
- Line 3 (`add` body): 2 hits
- Line 6 (`multiply` body): 0 hits
- 3 executable lines found, 1 line was hit (33% coverage)

## Parallel Execution

Coverage works seamlessly with parallel test execution (`-p` flag):

::: code-group
```bash [Command]
bashunit tests/ --coverage -p
```
:::

**How it works:**
- Each parallel worker writes to its own coverage file
- After all tests complete, coverage data is aggregated
- The final report combines hits from all workers

::: tip
Coverage percentages should be identical whether running in parallel or sequential mode.
:::

## What Gets Tracked

### Executable Lines

bashunit counts these as executable lines:
- Shebang line (`#!/usr/bin/env bash`)
- Commands and statements
- Single-line function bodies (`function foo() { echo "hi"; }`)

### Non-Executable Lines (Skipped)

These lines are not counted toward coverage:
- Empty lines
- Comment-only lines (except shebang)
- Function declaration lines (`function foo() {`)
- Lines with only braces (`{` or `}`)

## Limitations

### bashunit's Own Code

bashunit automatically excludes its own source files from coverage tracking. When running bashunit's internal tests, coverage shows 0/0 because the test framework's code is excluded.

::: warning
Coverage is designed to track **your application code**, not the test framework itself.
:::

### External Commands

Coverage only tracks Bash code. External commands (like `grep`, `sed`, etc.) are not tracked, though the lines that call them are.

### Subshell Behavior

Due to Bash's process model, some subshell contexts may not have full coverage tracking. The DEBUG trap is inherited into subshells, but complex nested scenarios may have edge cases.
