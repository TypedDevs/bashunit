---
paths:
  - "**/*.sh"
  - ".tasks/**/*.md"
---

# TDD Workflow

## Overview

**Test-Driven Development is mandatory** for all bashunit development. Follow the strict Red → Green → Refactor cycle.

This document provides a concise TDD approach. For complete instructions, see @AGENTS.md.

## The TDD Cycle

```
1. RED    → Write a failing test (fail for the RIGHT reason)
2. GREEN  → Write minimal code to make it pass
3. REFACTOR → Improve code while keeping tests green
```

**Repeat** until all acceptance criteria are met.

## Step 0: Create Task File (Mandatory)

**Before writing any code**, create `.tasks/YYYY-MM-DD-slug.md`:

```markdown
# [Feature/Fix Name]

**Date:** YYYY-MM-DD
**Status:** In Progress

## Context

Brief explanation of what needs to be done and why.

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Test Inventory

### Unit Tests
- [ ] `test_should_handle_valid_input`
- [ ] `test_should_fail_with_invalid_input`
- [ ] `test_should_handle_edge_cases`

### Functional Tests
- [ ] `test_should_integrate_with_component_x`

### Acceptance Tests
- [ ] `test_should_satisfy_user_workflow`

## Current Red Bar

Test currently failing: `test_should_handle_valid_input`
Reason: Function not yet implemented

## Logbook

### YYYY-MM-DD HH:MM
- Created task file
- Analyzed existing code in `src/module.sh`

### YYYY-MM-DD HH:MM
- RED: Added failing test `test_should_handle_valid_input`
- Expected: function returns "result"
- Actual: function does not exist

### YYYY-MM-DD HH:MM
- GREEN: Implemented minimal function
- Test now passes

[Continue logging each cycle...]
```

**Never start work without a task file.**

## Step 1: RED - Write Failing Test

### Before Writing the Test

1. **Read existing patterns:**
    ```bash
    # For the type of test you're writing, study:
    tests/unit/assert_test.sh         # Assertions
    tests/functional/doubles_test.sh  # Mocks/spies
    tests/acceptance/bashunit_test.sh # CLI/snapshots
    ```

2. **Pick the smallest next test** from your test inventory
3. **Update task file** with current red bar

### Writing the Test

```bash
function test_should_return_correct_value() {
  # Arrange - Set up test data
  local input="test_input"
  local expected="expected_output"

  # Act - Call the function (that doesn't exist yet!)
  local actual
  actual=$(my_function "$input")

  # Assert - Verify expected behavior
  assert_equals "$expected" "$actual"
}
```

### Run the Test - It MUST Fail

```bash
./bashunit tests/unit/my_test.sh
```

**Critical:** Verify it fails for the **RIGHT reason**:
- ✅ Function not found (if new function)
- ✅ Wrong output (if modifying existing)
- ❌ Syntax error (fix and re-run)
- ❌ Wrong test setup (fix and re-run)

### Update Task File

```markdown
## Current Red Bar

Test: `test_should_return_correct_value`
File: `tests/unit/my_test.sh`
Reason: Function `my_function` does not exist
Expected: Function to return "expected_output" for input "test_input"

## Logbook

### 2026-02-09 10:30
- RED: Added test `test_should_return_correct_value`
- Test fails correctly: function not defined
```

## Step 2: GREEN - Make It Pass

### Write Minimal Code

**Only enough to make THIS test pass** - no more, no less:

```bash
# src/my_module.sh

function my_function() {
  local input="$1"

  # Minimal implementation
  echo "expected_output"
}
```

**Resist the urge to:**
- ❌ Add extra features
- ❌ Handle cases not yet tested
- ❌ Optimize prematurely
- ❌ Add error handling not yet required

### Run the Test - It MUST Pass

```bash
./bashunit tests/unit/my_test.sh
```

**If it doesn't pass:**
1. Debug why
2. Fix the minimal code
3. Don't move forward until GREEN

### Update Task File

```markdown
## Current Red Bar

None - test passing

## Test Inventory

### Unit Tests
- [x] `test_should_return_correct_value` ✅
- [ ] `test_should_handle_invalid_input`
- [ ] `test_should_handle_empty_input`

## Logbook

### 2026-02-09 10:35
- GREEN: Implemented `my_function` in `src/my_module.sh`
- Test passes with minimal implementation
- Ready for refactor phase
```

## Step 3: REFACTOR - Improve Code

**Now** you can improve the code while keeping all tests GREEN.

### What to Refactor

- Improve readability
- Remove duplication
- Extract common patterns
- Optimize performance
- Add documentation
- Improve naming

### Refactoring Rules

1. **All tests must stay green** throughout refactoring
2. **Run tests frequently** (after each small change)
3. **Commit frequently** (small, focused commits)
4. **Don't change behavior** (that requires new tests)

### Example Refactoring

```bash
# Before (works but can improve)
function my_function() {
  local input="$1"
  echo "expected_output"
}

# After refactoring
##
# Processes input and returns formatted output
# Arguments: $1 - Input string
# Returns: Formatted output string
##
function bashunit::my_function() {
  local input="$1"

  _format_output "$input"
}

function _format_output() {
  local input="$1"
  echo "expected_output"
}
```

### Run Tests After Refactoring

```bash
./bashunit tests/unit/my_test.sh  # Specific test
./bashunit tests/                  # All tests
```

**If tests fail:**
1. You broke something - revert
2. Fix and verify tests pass
3. Continue refactoring

### Quality Checks

```bash
make sa         # ShellCheck
make lint       # EditorConfig
shfmt -w .      # Format
```

### Update Task File

```markdown
## Logbook

### 2026-02-09 10:45
- REFACTOR: Improved function naming and documentation
- Added `_format_output` helper for clarity
- Ran shellcheck and shfmt
- All tests still green
- Ready for next test in inventory
```

## Step 4: Repeat Until Done

### Pick Next Test

Look at your test inventory and pick the **next smallest test**:

```markdown
## Test Inventory

### Unit Tests
- [x] `test_should_return_correct_value` ✅
- [ ] `test_should_handle_invalid_input` ← NEXT
- [ ] `test_should_handle_empty_input`
```

### Continue the Cycle

1. **RED:** Write `test_should_handle_invalid_input`
2. **GREEN:** Make it pass with minimal code
3. **REFACTOR:** Improve if needed
4. **Repeat:** Move to next test

### Track Progress

Keep task file updated with:
- Which test is currently RED
- Test inventory checkboxes
- Timestamped logbook entries
- Any blockers or decisions

## Quality Gate (Before Commit)

Before committing, verify:

```bash
# Run all tests
./bashunit tests/

# Run quality checks
make sa          # ShellCheck must pass
make lint        # EditorConfig must pass
shfmt -w .       # Format all files

# Run tests in parallel (check for isolation issues)
./bashunit --parallel tests/
```

**All must be green before commit.**

## Definition of Done

Mark work complete only when:

- [x] All tests green for the **right reason**
- [x] All acceptance criteria met
- [x] `make sa` passes (shellcheck)
- [x] `make lint` passes (editorconfig)
- [x] Task file complete:
  - [x] All test inventory items checked
  - [x] Logbook entries timestamped
  - [x] Final status updated
- [x] Docs updated (if user-visible changes)
- [x] CHANGELOG updated (if user-visible changes)
- [x] ADR created/updated (if architectural decision)

## Common TDD Mistakes to Avoid

### ❌ Writing Too Much Code

```bash
# ❌ Don't implement features not yet tested
function my_function() {
  local input="$1"

  # Validate input (no test for this yet!)
  if [[ -z "$input" ]]; then
    return 1
  fi

  # Handle special cases (no test for this yet!)
  if [[ "$input" == "special" ]]; then
    echo "special_output"
    return
  fi

  echo "expected_output"
}

# ✅ Only implement what's tested
function my_function() {
  local input="$1"
  echo "expected_output"
}
```

### ❌ Skipping the RED Phase

Don't assume the test will fail - **always run it** to verify it fails for the right reason.

### ❌ Tests That Don't Fail

```bash
# ❌ Test that will never fail
function test_should_always_pass() {
  assert_equals "5" "5"  # Hardcoded - not testing anything!
}

# ✅ Test actual behavior
function test_should_add_numbers() {
  local result
  result=$(add 2 3)
  assert_equals "5" "$result"
}
```

### ❌ Refactoring Without Green Tests

Don't refactor until:
1. Test is written (RED)
2. Test passes (GREEN)
3. **Then** refactor

### ❌ Working Without Task File

**Never skip the task file.** It tracks:
- What you're building (acceptance criteria)
- How you're testing it (test inventory)
- Where you are (current red bar)
- What you've done (logbook)

## TDD Benefits

When done correctly:
- ✅ **Better design** - Tests force good interfaces
- ✅ **Living documentation** - Tests show how code works
- ✅ **Confidence** - Refactor without fear
- ✅ **Faster debugging** - Failing test pinpoints issue
- ✅ **No untested code** - Coverage naturally high
- ✅ **Clear progress** - Test inventory shows what's left

## Quick Reference

```bash
# The cycle
RED → GREEN → REFACTOR → REPEAT

# Before coding
Create .tasks/YYYY-MM-DD-slug.md

# RED phase
1. Write failing test
2. Run it - verify it fails for RIGHT reason
3. Update task file with red bar

# GREEN phase
1. Write minimal code
2. Run test - verify it passes
3. Update task file

# REFACTOR phase
1. Improve code
2. Run tests after each change
3. Keep all tests green
4. Run quality checks
5. Update task file

# Before committing
./bashunit tests/
make sa && make lint
shfmt -w .
./bashunit --parallel tests/
```

## Resources

- Full workflow: @AGENTS.md
- Testing patterns: @.claude/rules/testing.md
- Code style: @.claude/rules/bash-style.md
- Contributing guide: @.github/CONTRIBUTING.md
