# Bashunit — Copilot Instructions

> **Prime directive**: We practice **Test-Driven Development (TDD) by default**. Write a failing test first, make it fail **for the right reason**, implement the **smallest** change to pass, then **refactor** while keeping all tests green.

> **🚨 MANDATORY WORKFLOW RULE (NO EXCEPTIONS) 🚨:** **STOP! BEFORE READING FURTHER** - Create a task file `./.tasks/YYYY-MM-DD-feature-title.md` for **EVERY SINGLE CHANGE** including documentation updates, instruction modifications, bug fixes, new features, refactoring - **EVERYTHING**. Work within this file throughout the entire task, documenting all progress and thought process.

> **🚨 MANDATORY WORKFLOW RULE (NO EXCEPTIONS) 🚨:** **STOP! BEFORE READING FURTHER** - To finish any task the definition of done must be fully satisfied.

> **Clarity Rule:** If acceptance criteria or the intended outcomes are not clear or ambiguous, **ask clarifying questions before making any change** and record the answers in the active task file.

> **📋 External Developer Tools**: This repository includes `AGENTS.md` in the root directory with essential workflow information for external developer tools. When making significant changes to development workflow, TDD methodology, or core patterns, consider updating `AGENTS.md` to keep it synchronized with these comprehensive instructions.

---

## Cross-file synchronization with `AGENTS.md`

To keep guidance coherent and up to date, we enforce a two-way sync policy:
- When `copilot-instructions.md` changes, evaluate whether the change belongs in `AGENTS.md` and update `AGENTS.md` automatically if so.
- When `AGENTS.md` changes, evaluate whether the change belongs in `copilot-instructions.md` and update this file automatically if so.
- If a change is intentionally not mirrored, record the rationale in the active `./.tasks/YYYY-MM-DD-slug.md`.

---

## What this repository is

An open-source **library** providing a fast, portable Bash testing framework: **bashunit**. It offers:

* Minimal overhead, plain Bash test files.
* Rich **assertions**, **test doubles (mock/spy)**, **data providers**, **snapshots**, **skip/todo**, **globals utilities**, **custom assertions**, **benchmarks**, and **standalone** runs.

**Compatibility**: Bash 3.2+ (macOS, Linux, WSL). No external dependencies beyond standard Unix tools.

---

## 🛑 STEP 0: MANDATORY TASK FILE CREATION (READ THIS FIRST)

**DO NOT PROCEED WITHOUT COMPLETING THIS STEP**

### EVERY agent must do this BEFORE any work:

1. **STOP and CREATE task file**: `.tasks/YYYY-MM-DD-feature-title.md` (in English)
    - Example: `.tasks/2025-09-17-add-assert-json-functionality.md`
    - Example: `.tasks/2025-09-17-fix-mock-cleanup-bug.md`
    - Example: `.tasks/2025-09-17-update-documentation.md`
    - Example: `.tasks/2025-09-17-enhance-copilot-instructions.md`

2. **CHOOSE appropriate template**:
    - **New user capability**: Use Template A (new assertions, CLI features, test doubles)
    - **Internal modifications**: Use Template B (refactors, fixes, docs)

3. **FILL task information immediately**: Complete all sections with specific acceptance criteria

4. **WORK within this file throughout the task**: Update test inventory, track progress, document all decisions

### ⚠️ ABSOLUTE RULES - NO RATIONALIZATION ALLOWED:
- **"The task is simple"** → **STILL REQUIRES TASK FILE**
- **"It's just a bug fix"** → **STILL REQUIRES TASK FILE**
- **"It's just documentation"** → **STILL REQUIRES TASK FILE**
- **"I'm updating instructions"** → **STILL REQUIRES TASK FILE**
- **"It's a tiny change"** → **STILL REQUIRES TASK FILE**

**If you're reading this and haven't created a task file yet - STOP NOW and create one.**

---

## Learn from existing tests (essential reference)

**Before writing any code, study the patterns in `./tests/`:**

* `tests/unit/` - Unit tests for individual functions and modules (22+ test files)
* `tests/functional/` - Integration tests for feature combinations (6 test files)
* `tests/acceptance/` - End-to-end CLI and workflow tests (15+ test files)
* `tests/benchmark/` - Performance and timing tests

**Critical test files to study for patterns:**

### Core assertion patterns (`tests/unit/assert_test.sh`)
```bash
# Data provider pattern with @data_provider comment
# @data_provider provider_successful_assert_true
function test_successful_assert_true() {
    assert_empty "$(assert_true $1)"
}

function provider_successful_assert_true() {
    data_set true
    data_set "true"
    data_set 0
}

# Testing assertion failures with expected console output
function test_unsuccessful_assert_true() {
    assert_same\
    "$(console_results::print_failed_test\
        "Unsuccessful assert true" \
        "true or 0" \
        "but got " "false")"\
    "$(assert_true false)"
}
```

### Setup/teardown patterns (`tests/unit/setup_teardown_test.sh`)
```bash
TEST_COUNTER=1

function set_up_before_script() {
    TEST_COUNTER=$(( TEST_COUNTER + 1 ))
}

function set_up() {
    TEST_COUNTER=$(( TEST_COUNTER + 1 ))
}

function tear_down() {
    TEST_COUNTER=$(( TEST_COUNTER - 1 ))
}

function tear_down_after_script() {
    TEST_COUNTER=$(( TEST_COUNTER - 1 ))
}

function test_counter_is_incremented_after_setup_before_script_and_setup() {
    assert_same "3" "$TEST_COUNTER"
}
```

### Test doubles patterns (`tests/functional/doubles_test.sh`)
```bash
function test_mock_ps_when_executing_a_script() {
    mock ps cat ./tests/functional/fixtures/doubles_ps_output

    assert_match_snapshot "$(source ./tests/functional/fixtures/doubles_script.sh)"
}

function test_spy_commands_called_when_executing_a_sourced_function() {
    source ./tests/functional/fixtures/doubles_function.sh
    spy ps
    spy awk
    spy head

    top_mem

    assert_have_been_called ps
    assert_have_been_called awk
    assert_have_been_called head
}

function test_spy_commands_called_once_when_executing_a_script() {
    spy ps
    ./tests/functional/fixtures/doubles_script.sh
    assert_have_been_called_times 1 ps
}
```

### Data provider patterns (`tests/functional/provider_test.sh`)
```bash
function set_up() {
    _GLOBAL="aa-bb"
}

# @data_provider provide_multiples_values
function test_multiple_values_from_data_provider() {
    local first=$1
    local second=$2
    assert_equals "${_GLOBAL}" "$first-$second"
}

function provide_multiples_values() {
    echo "aa" "bb"
}

# @data_provider provide_single_values
function test_single_values_from_data_provider() {
    local data="$1"
    assert_not_equals "zero" "$data"
}

function provide_single_values() {
    echo "one"
    echo "two"
    echo "three"
}
```

### CLI acceptance patterns (`tests/acceptance/bashunit_fail_test.sh`)
```bash
function set_up_before_script() {
    TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
    TEST_ENV_FILE_SIMPLE="tests/acceptance/fixtures/.env.simple"
}

function test_bashunit_when_a_test_fail_verbose_output_env() {
    local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

    assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
    assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}
```

### Custom assertions (`tests/functional/custom_asserts.sh`)
```bash
function assert_foo() {
    local actual="$1"
    local expected="foo"

    if [[ "$expected" != "$actual" ]]; then
    bashunit::assertion_failed "$expected" "${actual}"
    return
    fi

    bashunit::assertion_passed
}

function assert_positive_number() {
    local actual="$1"

    if [[ "$actual" -le 0 ]]; then
    bashunit::assertion_failed "positive number" "${actual}" "got"
    return
    fi

    bashunit::assertion_passed
}
```

---

## Before you touch any code

1. **Read ADRs first**
    * Review existing ADRs in the `adrs/` folder to understand decisions, constraints, and paved-road patterns.
    * Current ADRs: error detection, booleans, parallel testing, metadata prefix, copilot instructions
    * If your change introduces a significant decision, **create a new ADR** using `adrs/TEMPLATE.md`.

2. **Create a task file (required)**
    * Path: `./.tasks/YYYY-MM-DD-slug.md` (format: `YYYY-MM-DD-slug.md`)
    * This file is **versioned** and is the single source of truth for your current task.

3. **Study existing test patterns extensively**
    * **Unit tests**: Look at `tests/unit/assert_test.sh`, `tests/unit/globals_test.sh`, `tests/unit/test_doubles_test.sh`
    * **Functional tests**: Check `tests/functional/doubles_test.sh`, `tests/functional/provider_test.sh`
    * **Acceptance tests**: Study `tests/acceptance/bashunit_test.sh`, `tests/acceptance/mock_test.sh`
    * Follow established naming, structure, and assertion patterns exactly

---

## Double-Loop TDD

We practice two nested feedback loops to deliver behavior safely and quickly.

### Outer loop: acceptance first

- Start from user value. For any new user-visible capability, write a high-level acceptance test that exercises the system through its public entry point (CLI, function API).
- Keep the acceptance test red. It defines the next slice of behavior we must implement.
- When the acceptance test is too broad, split it into thinner vertical slices that still provide visible progress.

### Inner loop: design-driving tests

- Drive the implementation with smaller tests created only when needed:
    - Unit tests for individual functions and modules
    - Functional tests for integration between components
- Follow the classic cycle:
    1) **Red**: write a failing test for the next micro-behavior
    2) **Green**: write the minimum production code to pass
    3) **Refactor**: improve design in both production and tests while keeping all tests green

### Test inventory and prioritization

- Maintain a living test inventory in `./.tasks/Task.md` for the active task
- Track acceptance tests, unit tests, and functional tests that define the capability
- After every refactor, review the inventory. Add missing cases, then re-prioritize
- The top priority is the test that is currently red

### Important rules

- **Never stop at tests only**: Always add the production code that actually uses the new behavior in the application flow
- **Avoid speculative tests**: Write the next test only when a failing acceptance path or design pressure calls for it
- **Keep tests deterministic**: No hidden time, randomness, or cross-test coupling
- **Prefer observable behavior over internal structure**: If refactoring breaks a test without changing behavior, fix the test, not the refactor

---

## Bash coding standards (bashunit-specific)

### Compatibility & Portability
```bash
# ✅ GOOD - Works on Bash 3.2+
[[ -n "${var:-}" ]] && echo "set"
array=("item1" "item2")

# ❌ BAD - Bash 4+ only
declare -A assoc_array
readarray -t lines < file
```

### Error handling & safety (observed patterns)
```bash
# ✅ GOOD - Safe parameter expansion (from tests)
local param="${1:-}"
[[ -z "${param}" ]] && return 1

# ✅ GOOD - Function existence check (from globals_test.sh)
function existing_fn(){
    return 0
}
assert_successful_code "$(is_command_available existing_fn)"

# ❌ BAD - Unsafe expansion
local param=$1  # fails if $1 is unset with set -u
```

### Function naming & organization (actual patterns)
```bash
# ✅ GOOD - Module namespacing (from actual codebase)
function console_results::print_failed_test() { ... }
function console_results::print_skipped_test() { ... }
function console_results::print_incomplete_test() { ... }
function state::add_assertions_failed() { ... }
function helper::normalize_test_function_name() { ... }

# ✅ GOOD - Test function naming (from actual tests)
function test_successful_assert_true() { ... }
function test_unsuccessful_assert_true_with_custom_message() { ... }
function test_bashunit_when_a_test_fail_verbose_output_env() { ... }

# Data provider naming (from functional/provider_test.sh)
function provide_multiples_values() { ... }
function provide_single_values() { ... }
```

### String handling & output (real examples)
```bash
# ✅ GOOD - Line continuation for readability (from assert_test.sh)
assert_same\
    "$(console_results::print_failed_test\
    "Unsuccessful assert true" \
    "true or 0" \
    "but got " "false")"\
    "$(assert_true false)"

# ✅ GOOD - Proper quoting and color handling
local colored=$(printf '\e[31mHello\e[0m World!')
assert_empty "$(assert_match_snapshot_ignore_colors "$colored")"
```

---

## Assertion patterns (real examples from tests/unit/assert_test.sh)

### Complete assertion catalog (verified in codebase)
```bash
# Equality assertions
assert_same "expected" "${actual}"
assert_not_same "unexpected" "${actual}"
assert_equals "expected" "${actual}"         # alias for assert_same
assert_not_equals "unexpected" "${actual}"  # alias for assert_not_same

# Truthiness assertions
assert_true "command_or_function"
assert_false "failing_command"
assert_successful_code "command"        # tests exit code 0
assert_general_error "failing_command"  # tests exit code != 0

# String assertions
assert_contains "needle" "${haystack}"
assert_not_contains "needle" "${haystack}"
assert_matches "^[0-9]+$" "${value}"         # regex matching
assert_string_starts_with "prefix" "${string}"
assert_string_ends_with "suffix" "${string}"

# Numeric assertions
assert_greater_than 10 "${n}"
assert_less_than 5 "${m}"
assert_greater_or_equal_than 10 "${n}"
assert_less_or_equal_than 5 "${m}"

# Emptiness assertions
assert_empty "${maybe_empty}"
assert_not_empty "${something}"

# File/directory assertions (from tests/unit/file_test.sh)
assert_file_exists "${filepath}"
assert_file_not_exists "${filepath}"
assert_directory_exists "${dirpath}"
assert_directory_not_exists "${dirpath}"

# Array assertions (from tests/unit/assert_arrays_test.sh if exists)
assert_array_contains "element" "${array[@]}"
assert_array_not_contains "element" "${array[@]}"

# Snapshot assertions (from tests/unit/assert_snapshot_test.sh)
assert_match_snapshot "${output}"
assert_match_snapshot "${output}" "custom_snapshot_name"
assert_match_snapshot_ignore_colors "${colored_output}"
```

### Advanced assertion patterns (from real tests)
```bash
# Output capture and assertion (common pattern)
assert_empty "$(assert_true true)"  # success case produces no output

# Multiple assertions on same output
local output
output="$(complex_function)"
assert_contains "expected_part" "${output}"
assert_not_contains "unexpected_part" "${output}"

# Testing assertion failures (critical pattern from assert_test.sh)
assert_same\
    "$(console_results::print_failed_test\
    "Test name" \
    "expected_value" \
    "but got " "actual_value")"\
    "$(failing_assertion)"
```

---

## Test doubles patterns (from tests/functional/doubles_test.sh & tests/unit/test_doubles_test.sh)

### Mock patterns (with file fixtures)
```bash
function test_mock_with_file_content() {
    # Mock with file content
    mock ps cat ./tests/functional/fixtures/doubles_ps_output
    assert_match_snapshot "$(source ./tests/functional/fixtures/doubles_script.sh)"
}

function test_mock_with_inline_content() {
    # Mock with heredoc
    mock ps<<EOF
PID TTY          TIME CMD
13525 pts/7    00:00:01 bash
24162 pts/7    00:00:00 ps
8387  ?        00:00:00 /usr/sbin/apache2 -k start
EOF

    assert_successful_code "$(code_that_uses_ps)"
}

function test_mock_with_simple_command() {
    # Mock with simple echo
    mock ps echo hello world
    assert_same "hello world" "$(ps)"
}
```

### Spy patterns (verification focused)
```bash
function test_spy_function_calls() {
    spy ps
    spy awk
    spy head

    # Execute function that uses these commands
    ./tests/functional/fixtures/doubles_script.sh

    # Verify all were called
    assert_have_been_called ps
    assert_have_been_called awk
    assert_have_been_called head
}

function test_spy_call_counts() {
    spy ps

    ps first_call
    ps second_call

    assert_have_been_called_times 2 ps
}

function test_spy_with_arguments() {
    spy ps
    ps a_random_parameter_1 a_random_parameter_2

    assert_have_been_called_with ps "a_random_parameter_1 a_random_parameter_2"
}

function test_spy_sourced_functions() {
    source ./fixtures/fake_function_to_spy.sh
    spy function_to_be_spied_on

    function_to_be_spied_on

    assert_have_been_called function_to_be_spied_on
}

# CRITICAL: Mock cleanup is automatic between tests (tests/acceptance/mock_test.sh)
function test_runner_clear_mocks_first() {
    mock ls echo foo
    assert_same "foo" "$(ls)"
}

function test_runner_clear_mocks_second() {
    # Mocks are automatically cleared between tests
    assert_not_equals "foo" "$(ls)"
}
```

---

## Data providers (patterns from tests/functional/provider_test.sh)

### Multiple parameter data providers
```bash
# @data_provider provide_multiples_values
function test_multiple_values_from_data_provider() {
    local first=$1
    local second=$2
    assert_equals "${_GLOBAL}" "$first-$second"
}

function provide_multiples_values() {
    echo "aa" "bb"  # single line with multiple values
}
```

### Single parameter, multiple cases
```bash
# @data_provider provide_single_values
function test_single_values_from_data_provider() {
    local data="$1"
    assert_not_equals "zero" "$data"
}

function provide_single_values() {
    echo "one"    # each echo is a separate test case
    echo "two"
    echo "three"
}
```

### Empty/edge case handling
```bash
# @data_provider provide_empty_value
function test_empty_value_from_data_provider() {
    local first="$1"
    local second="$2"

    assert_same "" "$first"
    assert_same "two" "$second"
}

function provide_empty_value() {
    echo "" "two"  # empty first parameter
}
```

---

## Lifecycle hooks (from tests/unit/setup_teardown_test.sh & tests/unit/globals_test.sh)

### Complete lifecycle pattern
```bash
# Script-level setup (once before all tests in file)
function set_up_before_script() {
    SCRIPT_TEMP_FILE=$(temp_file "custom-prefix")
    SCRIPT_TEMP_DIR=$(temp_dir "custom-prefix")
    TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

# Test-level setup (before each individual test)
function set_up() {
    _GLOBAL="aa-bb"
    TEST_FILE="$(temp_file "test_case")"
    BASHUNIT_DEV_LOG=$(temp_file)
    export BASHUNIT_DEV_LOG
}

# Test-level teardown (after each individual test)
function tear_down() {
    [[ -f "${TEST_FILE:-}" ]] && rm -f "${TEST_FILE}"
    rm "$BASHUNIT_DEV_LOG"
    unset code
    unset ps
}

# Script-level teardown (once after all tests in file)
function tear_down_after_script() {
    [[ -d "${SCRIPT_TEMP_DIR:-}" ]] && rm -rf "${SCRIPT_TEMP_DIR}"
    export BASHUNIT_DEV_LOG=""
}
```

### State management patterns (from setup_teardown_test.sh)
```bash
TEST_COUNTER=1

function set_up_before_script() {
    TEST_COUNTER=$(( TEST_COUNTER + 1 ))  # 2
}

function set_up() {
    TEST_COUNTER=$(( TEST_COUNTER + 1 ))  # 3 for each test
}

function tear_down() {
    TEST_COUNTER=$(( TEST_COUNTER - 1 ))  # back to 2
}

function test_counter_state() {
    assert_same "3" "$TEST_COUNTER"  # setup_before_script + setup
}
```

---

## Custom assertions (from tests/functional/custom_asserts.sh)

### Implementation pattern
```bash
function assert_foo() {
    local actual="$1"
    local expected="foo"

    if [[ "$expected" != "$actual" ]]; then
    bashunit::assertion_failed "$expected" "${actual}"
    return
    fi

    bashunit::assertion_passed
}

function assert_positive_number() {
    local actual="$1"

    if [[ "$actual" -le 0 ]]; then
    bashunit::assertion_failed "positive number" "${actual}" "got"
    return
    fi

    bashunit::assertion_passed
}
```

### Testing custom assertions
```bash
function test_assert_foo_passed() {
    assert_foo "foo"
}

function test_assert_foo_failed() {
    assert_same\
    "$(console_results::print_failed_test "Assert foo" "foo" "but got " "bar")"\
    "$(assert_foo "bar")"
}
```

---

## CLI testing patterns (from tests/acceptance/)

### Environment and configuration
```bash
function set_up_before_script() {
    TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
    TEST_ENV_FILE_SIMPLE="tests/acceptance/fixtures/.env.simple"
}
```

### Testing CLI output and exit codes
```bash
function test_bashunit_should_display_help() {
    assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --help)"
    assert_successful_code "./bashunit --no-parallel --env "$TEST_ENV_FILE" --help"
}

function test_bashunit_when_a_test_fail_verbose_output() {
    local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

    assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
    assert_general_error "./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file""
}
```

### Testing different output modes
```bash
function test_bashunit_simple_vs_verbose_output() {
    local test_file=./tests/acceptance/fixtures/test_failing.sh

    # Test simple output
    assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file")"

    # Test detailed output
    assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" "$test_file" --detailed)"
}
```

---

## Additional patterns and guidelines

### Common utility functions (from globals.sh)
```bash
# Command checking
is_command_available "command_name"           # returns 0 if command exists

# Random strings for test isolation
local random_name="test_$(random_str 8)"      # 8-character random string

# Line printing for formatting (if available)
print_line 50 "="                            # prints 50 equals signs
```

### Global variables and state (observed in tests)
```bash
# Assertion counters (from assert_snapshot_test.sh)
_ASSERTIONS_SNAPSHOT                          # tracks snapshot assertions

# Environment variables
BASHUNIT_DEV_LOG                             # dev logging file path
BASHUNIT_SIMPLE_OUTPUT                       # output mode flag
BASHUNIT_SNAPSHOT_PLACEHOLDER                # snapshot placeholder text
```

---

## Repository structure awareness

### Source code organization (`src/`)
```
src/
├── assertions.sh          # Core assertion functions
├── assert.sh             # Individual assert functions
├── assert_arrays.sh      # Array-specific assertions
├── assert_files.sh       # File/directory assertions
├── assert_folders.sh     # Folder-specific assertions
├── assert_snapshot.sh    # Snapshot assertion logic
├── bashunit.sh          # Public API facade
├── benchmark.sh         # Benchmarking utilities
├── console_results.sh   # Result formatting and display
├── globals.sh           # Global utilities and helpers
├── main.sh             # Main entry point
├── runner.sh           # Test execution engine
├── state.sh            # State management
├── test_doubles.sh     # Mock/spy implementation
└── test_title.sh       # Custom test titles
```

### Testing organization (`tests/`)
```
tests/
├── unit/              # Unit tests for individual modules
│   ├── assert_test.sh       # Core assertion testing
│   ├── globals_test.sh      # Global utilities testing
│   ├── setup_teardown_test.sh # Lifecycle testing
│   └── test_doubles_test.sh # Mock/spy testing
├── functional/        # Integration testing
│   ├── doubles_test.sh      # Test doubles integration
│   ├── provider_test.sh     # Data provider testing
│   └── custom_asserts_test.sh # Custom assertion testing
├── acceptance/        # End-to-end CLI testing
│   ├── bashunit_test.sh     # Core CLI functionality
│   ├── mock_test.sh         # Mock cleanup testing
│   └── bashunit_*_test.sh   # Specific feature testing
└── benchmark/         # Performance testing
```

### Configuration and build files
```bash
# Test configuration
.bashunit.yml                    # Main configuration file
tests/acceptance/fixtures/.env.default    # Default test environment
tests/acceptance/fixtures/.env.simple     # Simple output environment

# Build and quality
Makefile                        # Build tasks and shortcuts
shellcheck + shfmt              # Linting and formatting tools
```

---

## Commands (developer workflow)

```bash
# Development cycle
./bashunit tests/              # Run all tests
shellcheck -x $(find . -name "*.sh")  # Static analysis
shfmt -w .                     # Format code

# Testing specific patterns
./bashunit tests/unit/         # Unit tests only
./bashunit tests/functional/   # Functional tests only
./bashunit tests/acceptance/   # Acceptance tests only

# Quality checks
make lint                      # Run linters (if Makefile exists)
make format                    # Format code (if Makefile exists)
```

---

## Error patterns and debugging (from real test failures)

### Testing error conditions (from tests/unit/assert_test.sh)
```bash
function test_unsuccessful_assert_true() {
    assert_same\
    "$(console_results::print_failed_test\
        "Unsuccessful assert true" \
        "true or 0" \
        "but got " "false")"\
    "$(assert_true false)"
}

function test_unsuccessful_spy_called() {
    spy ps

    assert_same\
    "$(console_results::print_failed_test "Unsuccessful spy called" "ps" "to have been called" "once")"\
    "$(assert_have_been_called ps)"
}
```

### Exit code testing patterns
```bash
function test_bashunit_exit_codes() {
    local test_file="./tests/acceptance/fixtures/test_failing.sh"

    # Test that failing tests return error exit code
    assert_general_error "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"

    # Test that passing tests return success exit code
    assert_successful_code "$(./bashunit --env "$TEST_ENV_FILE" "passing_test.sh")"
}
```

---

## Task templates

### Task Template A - New Capability

Use this template for new user-visible capabilities (assertions, CLI features, test doubles).

```markdown
# Task: <capability title>

## Context and intent

- Business value:
- User story or job to be done:
- Scope boundaries and out of scope:

## Acceptance test - outer loop

- Entry point: <CLI command, function call, assertion usage>
- Scenarios:
    - Happy path:
    - Alternatives and errors:
- Data and fixtures:
- How to run:
    - Command: ./bashunit <test_file>

## Test inventory

### Acceptance tests

- [ ] AT-1: <name>
- [ ] AT-2: <name>

### Unit tests

- [ ] U-1: <name, function behavior>
- [ ] U-2: <name, error conditions>

### Functional tests

- [ ] F-1: <name, integration behavior>
- [ ] F-2: <name, mock/spy integration>

## Current red bar

- Failing test:
- Test file:
- Smallest next step:

## Design notes during refactor

- Coupling reduced:
- Names improved:
- Risks mitigated:

## Logbook (agent thought process)

### [YYYY-MM-DD HH:mm] Initial analysis
- What I understand about the task:
- Key assumptions I'm making:
- Test patterns I'll follow from existing code:

### [YYYY-MM-DD HH:mm] TDD cycle progress
- Current test being worked on:
- Why I chose this test first:
- What I expect this test to validate:

### [YYYY-MM-DD HH:mm] Implementation decisions
- Functions/patterns I'm using and why:
- Existing code patterns I'm following:
- Error handling approach:

### [YYYY-MM-DD HH:mm] Obstacles and solutions
- Issues encountered:
- How I'm resolving them:
- Alternative approaches considered:

## Done checklist

- [ ] All acceptance, unit, and functional tests green
- [ ] Production code used in real application flow
- [ ] Lint clean (shellcheck + shfmt)
- [ ] All existing tests still pass
- [ ] Follows exact patterns from existing test files
- [ ] **AGENTS.md updated** if changes affect development workflow, TDD methodology, or core patterns
- [ ] **Two-way sync validated** (`AGENTS.md` ↔ `.github/copilot-instructions.md`)
- [ ] Docs updated if needed
- [ ] ADR created if architectural decision made
- [ ] Timestamp: <YYYY-MM-DD HH:mm:ss>
```

### Task Template B - Modification

Use this template for internal changes, fixes, refactors, documentation.

```markdown
# Task: <modification title>

## Context and intent

- Why this change is needed:
- Impacted area or module:
- Out of scope:

## Acceptance criteria

- AC-1: <observable outcome, including input, trigger, and expected result>
- AC-2: <observable outcome>
- AC-3: <edge or error handling, if relevant>

## Test inventory

### Unit tests

- [ ] U-1: <name, behavior validation>
- [ ] U-2: <name, error conditions>

### Functional tests (if needed)

- [ ] F-1: <name, integration validation>

### Acceptance tests (only if externally observable)

- [ ] AT-1: <name>

## Current red bar

- Failing test:
- Test file:
- Smallest next step:

## Logbook (agent thought process)

### [YYYY-MM-DD HH:mm] Initial analysis
- Current state understanding:
- Why this change is needed:
- Risk assessment:

### [YYYY-MM-DD HH:mm] Implementation approach
- Strategy chosen and rationale:
- Tests that need updating:
- Backward compatibility considerations:

### [YYYY-MM-DD HH:mm] Progress updates
- What's working:
- What's challenging:
- Adjustments made:

## Done checklist

- [ ] All listed tests green
- [ ] Production code actually used by the application flow
- [ ] Lint clean (shellcheck + shfmt)
- [ ] All existing tests still pass
- [ ] Follows exact patterns from existing test files
- [ ] Mock/spy cleanup verified if applicable
- [ ] Snapshot tests updated if output changed
- [ ] Docs updated if needed
- [ ] ADR added/updated if architectural decision
- [ ] Updated copilot-instructions if relevant and needed
- [ ] **AGENTS.md updated** if changes affect development workflow, TDD methodology, or core patterns
- [ ] **Two-way sync validated** (`AGENTS.md` ↔ `.github/copilot-instructions.md`)
- [ ] Timestamp: <YYYY-MM-DD HH:mm:ss>
```

---

## Definition of Done (enhanced)

### ✅ Code quality (verified standards)
- **All tests pass** (`./bashunit tests/`)
- **Shellcheck passes** with existing exceptions (`shellcheck -x $(find . -name "*.sh")`)
- **Code formatted** (`shfmt -w .`)
- **Bash 3.2+ compatible** (no `declare -A`, no `readarray`, no `${var^^}`)
- **Follows established module namespacing** patterns

### ✅ Testing (following observed patterns)
- **Unit tests** follow exact patterns from `tests/unit/assert_test.sh`
    - Use line continuation for complex assertions
    - Test both success and failure cases
    - Follow `test_successful_*` and `test_unsuccessful_*` naming
- **Functional tests** use patterns from `tests/functional/doubles_test.sh`
    - Proper mock/spy setup and cleanup verification
    - Integration with fixture files when appropriate
- **CLI tests** follow patterns from `tests/acceptance/bashunit_*_test.sh`
    - Use proper environment file setup
    - Test both output content and exit codes
    - Snapshot testing for stable CLI output
- **Data providers** use exact `@data_provider` comment syntax
- **Lifecycle hooks** follow `set_up_before_script` patterns exactly

### ✅ TDD compliance (critical)
- **Production code actually used** by the application flow
- **Tests written first** and failed for the right reason
- **Refactoring performed** while keeping all tests green
- **Test inventory completed** as documented in task file

### ✅ Pattern compliance (critical)
- **Function naming** follows module::function or test_description patterns
- **Variable declarations** use safe `"${var:-}"` expansion
- **Error handling** follows existing `if [[ condition ]]; then` patterns
- **Output capture** uses `"$(command)"` pattern consistently
- **Mock/spy tests** verify cleanup between tests

### ✅ Documentation
- **README updated** if public API changes
- **Relevant docs/** files updated when functionality changes
- **Code comments** only for complex logic (prefer clear code)
- **Examples** are executable and follow existing test patterns

### ✅ Process
- **Task file completed** with specific patterns studied and all progress documented
- **ADR created** if architectural decision made
- **Git history** follows existing commit message patterns
- **No deviation** from established patterns without documented reason
- **AGENTS.md updated** if changes affect development workflow, TDD methodology, or core patterns

---

## Examples from the codebase (mandatory study list)

**Critical files to study for any change:**

### Core patterns (study first, always)
- `tests/unit/assert_test.sh` - Master template for assertion patterns and failure testing
- `tests/unit/setup_teardown_test.sh` - Definitive lifecycle hook patterns
- `tests/unit/globals_test.sh` - Canonical utility function testing patterns
- `src/console_results.sh` - Output formatting functions used in tests

### Feature-specific patterns (study for relevant changes)
- `tests/functional/doubles_test.sh` - Master template for mock/spy patterns
- `tests/functional/provider_test.sh` - Canonical data provider implementation
- `tests/functional/custom_asserts_test.sh` - Template for custom assertion testing
- `tests/acceptance/bashunit_test.sh` - Primary CLI testing patterns
- `tests/acceptance/mock_test.sh` - Critical mock cleanup verification patterns

### Advanced patterns (study for complex features)
- `tests/unit/assert_snapshot_test.sh` - Complete snapshot testing patterns
- `tests/unit/skip_todo_test.sh` - Skip/todo functionality patterns
- `tests/unit/test_doubles_test.sh` - Advanced test double usage and edge cases
- `tests/acceptance/bashunit_fail_test.sh` - Error handling and output testing

### Fixture and environment patterns
- `tests/acceptance/fixtures/.env.default` - Standard test environment
- `tests/functional/fixtures/` - External script and data patterns
- `tests/*/snapshots/` - Expected output storage patterns

**Golden rule: If a pattern exists in the tests, use it exactly. Never invent new patterns when established ones exist.**

---

## Quick reference checklist

### Before starting any work:
1. ✅ **CREATE TASK FILE** `.tasks/YYYY-MM-DD-feature-title.md` (MANDATORY)
2. ✅ Study relevant test files from the mandatory list above
3. ✅ Read relevant ADRs in `adrs/` folder

### During TDD cycle:
1. ✅ Create a list of all the test you plan to write in the task file
2. ✅ Prioritize tests based on the smallest next step to deliver value
3. ✅ Always write the first test prioritized
4. ✅ Write failing test following exact existing patterns
5. ✅ Verify test fails for the right reason
6. ✅ Implement minimal code to pass
7. ✅ Run full test suite to ensure no regressions
8. ✅ Refactor while keeping all tests green
9. ✅ Analyze if the test code can be improved if so do it
10. ✅ Analyze if the production code can be improved if so do it
11. ✅ Update test list and mark the test as done
12. ✅ Analyze if you are missing any tests if so add them to te list
13. ✅ Re-prioritize remaining tests
14. ✅ Update task file logbook with progress
15. ✅ Repeat until all tests are green and the test list is complete and the acceptance criteria are met

### Before finishing:
1. ✅ All tests green (`./bashunit tests/`)
2. ✅ Linting clean (`shellcheck` + `shfmt`)
3. ✅ Production code actually used in application flow
4. ✅ Patterns match existing codebase exactly
5. ✅ Task file completed with timestamp
6. ✅ ADR created if architectural decision made

---

## Pull Request Checklist

Use this checklist before requesting review:

- [ ] All tests green for the right reason (`./bashunit tests/`)
- [ ] Lint/format clean (`shellcheck -x $(find . -name "*.sh")` + `shfmt -w .`)
- [ ] Task file updated (acceptance criteria, test inventory, logbook, done timestamp)
- [ ] Docs/README updated; CHANGELOG updated if user-visible
- [ ] ADR added/updated if a decision was made
- [ ] **Two-way sync validated** between `AGENTS.md` and `.github/copilot-instructions.md`

**Remember: This project has 40+ test files with established patterns. Always follow them exactly. NEVER proceed without creating a task file first.**
