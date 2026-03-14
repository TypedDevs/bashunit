---
name: add-assertion
description: Add new assertion function with comprehensive tests following TDD
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
---

# Add Assertion Skill

Add a new assertion function to bashunit following strict TDD methodology.

## Prerequisites

1. **Task file must exist** — create `.tasks/YYYY-MM-DD-add-assertion-name.md`
2. **Study patterns** — read `tests/unit/assert_test.sh` and `src/assertions.sh`

## Workflow

### 1. Plan

Ask user: assertion name, parameters, success/failure behavior, error messages.

Document acceptance criteria and test inventory in task file.

### 2. Study Existing Patterns

Read `src/assertions.sh` and `tests/unit/assert_test.sh` to understand:
- Parameter validation, assertion logic, error message format
- Return codes (0 = success, 1 = failure)
- How tests verify both success and failure cases

### 3. TDD Cycles

For each test in inventory, follow RED -> GREEN -> REFACTOR:

1. **Basic success case** — assertion passes with valid input
2. **Failure case** — assertion fails correctly, use `assert_fails`
3. **Edge cases** — empty input, special characters, nested structures, malformed data

### 4. Integration

- Source new file in `src/bashunit.sh` if created
- `export -f` the assertion function
- Run full test suite: `./bashunit tests/`
- Quality checks: `make sa && make lint && shfmt -w .`

### 5. Documentation

- Add function header with Arguments/Returns/Example
- Update CHANGELOG.md
- Update user-facing docs if applicable

## Final Checklist

- [ ] All tests passing (success, failure, edge cases)
- [ ] Function documented and exported
- [ ] Quality gate passes
- [ ] CHANGELOG updated
- [ ] Task file completed
