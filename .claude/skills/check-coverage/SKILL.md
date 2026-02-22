---
name: check-coverage
description: Analyze test coverage and identify untested code paths
allowed-tools: Read, Bash, Grep, Glob
---

# Check Coverage Skill

Analyze test coverage and identify gaps in test coverage for bashunit.

## When to Use

Invoke with `/check-coverage` when:
- Want to understand current test coverage
- Looking for untested code paths
- Planning which tests to add next
- Preparing for release

## Workflow

### 1. Generate Coverage Report

**Check if coverage is available:**
```bash
# Check for coverage configuration
grep -r "BASHUNIT_COVERAGE" .env .env.example
```

**Run tests with coverage:**
```bash
BASHUNIT_COVERAGE=true ./bashunit tests/
```

**Check for coverage output:**
```bash
# Look for coverage reports
ls -la coverage/
cat coverage/report.txt 2>/dev/null || echo "No report found"
```

### 2. Analyze Source Files

**List all source files:**
```bash
find src/ -name "*.sh" -type f
```

**For each source file, identify:**
- Functions defined
- Public vs private functions
- Complexity (branches, loops, conditionals)

### 3. Analyze Test Files

**List all test files:**
```bash
find tests/ -name "*_test.sh" -type f
```

**For each test file, identify:**
- What source file it tests
- How many test functions
- What's covered vs what's not

### 4. Map Coverage

**Create coverage matrix:**

For each source file in `src/`:
1. **List all functions:**
    ```bash
    grep "^function " src/module.sh
    ```

2. **Find corresponding tests:**
    ```bash
    # Look for tests that reference this function
    grep -r "function_name" tests/
    ```

3. **Categorize coverage:**
    - ✅ **Well tested** - Multiple tests, edge cases covered
    - ⚠️ **Partially tested** - Basic test exists, missing edge cases
    - ❌ **Not tested** - No tests found

### 5. Identify Critical Gaps

**Priority 1: Public API functions with no tests**
```bash
# Find exported functions without tests
for func in $(grep "export -f" src/*.sh | awk '{print $3}'); do
  if ! grep -r "function test.*$func" tests/ > /dev/null; then
    echo "❌ Untested: $func"
  fi
done
```

**Priority 2: Error handling paths**
```bash
# Find error handling that might not be tested
grep -n "return 1\|exit 1" src/*.sh
```

**Priority 3: Complex logic**
```bash
# Find complex conditionals
grep -n "if.*&&.*||" src/*.sh
```

### 6. Generate Report

**Format coverage summary:**

```markdown
# Test Coverage Report

Generated: $(date +%Y-%m-%d)

## Summary

- Total source files: X
- Total functions: Y
- Total test files: Z
- Total test functions: W

## Coverage by Module

### src/assertions.sh
- Functions: 25
- Tested: 23 (92%)
- Untested: 2
  - ❌ `bashunit::internal_helper`
  - ❌ `bashunit::deprecated_function`

### src/io.sh
- Functions: 10
- Tested: 8 (80%)
- Partially tested: 2
  - ⚠️ `bashunit::read_file` - missing error case tests

## Critical Gaps

### High Priority (Public API, No Tests)
1. ❌ `src/module.sh:42` - `bashunit::new_function`
2. ❌ `src/helper.sh:15` - `bashunit::utility`

### Medium Priority (Error Paths Not Tested)
1. ⚠️ `src/assertions.sh:123` - File not found error path
2. ⚠️ `src/io.sh:56` - Permission denied handling

### Low Priority (Internal/Deprecated)
1. ❓ `src/internal.sh:10` - `_private_helper` (internal)

## Recommendations

1. **Add tests for public API gaps** (Priority 1)
    - Start with: `test_new_function_should_handle_valid_input`

2. **Cover error paths** (Priority 2)
    - Add: `test_should_fail_when_file_not_found`

3. **Document intentionally untested code**
    - Internal functions with comments explaining why
```

### 7. Suggest Next Tests

**Based on gaps, suggest specific tests to add:**

```markdown
## Suggested Test Inventory

### src/module.sh Coverage
- [ ] `test_new_function_should_return_expected_value`
- [ ] `test_new_function_should_handle_empty_input`
- [ ] `test_new_function_should_fail_on_invalid_input`
- [ ] `test_new_function_should_handle_special_characters`

### src/io.sh Error Handling
- [ ] `test_read_file_should_fail_when_file_not_exists`
- [ ] `test_read_file_should_fail_when_permission_denied`
- [ ] `test_write_file_should_handle_disk_full`
```

### 8. Generate Task File Template

**If user wants to improve coverage, generate task file:**

```markdown
# Improve Test Coverage for module.sh

**Date:** $(date +%Y-%m-%d)
**Status:** Planning

## Context

Current coverage analysis shows module.sh has 75% coverage.
Need to add tests for uncovered functions and error paths.

## Acceptance Criteria

- [ ] `new_function` has unit tests
- [ ] Error paths tested for `helper_function`
- [ ] Edge cases covered for `utility_function`
- [ ] Coverage > 90% for module.sh

## Test Inventory

### Unit Tests
- [ ] test_new_function_should_handle_valid_input
- [ ] test_new_function_should_fail_on_invalid_input
[... from suggestions above ...]

## Current Red Bar

None yet - starting with first test

## Logbook

### $(date +%Y-%m-%d) $(date +%H:%M)
- Generated coverage report
- Identified 3 untested functions
- Created test inventory
```

## Analysis Techniques

### Function Coverage

```bash
# Count functions in source
total_funcs=$(grep -c "^function " src/module.sh)

# Count tests for this module
test_funcs=$(grep -c "^function test.*" tests/unit/module_test.sh)

echo "Functions: $total_funcs, Tests: $test_funcs"
```

### Branch Coverage

```bash
# Find conditionals
grep -n "if \|case \|while \|for " src/module.sh

# Check if both paths tested
# This requires manual review of tests
```

### Error Path Coverage

```bash
# Find error returns
grep -n "return [^0]\|exit [^0]" src/module.sh

# Check if tests verify these
grep -n "assert_fails\|assert_general_error" tests/unit/module_test.sh
```

## Coverage Goals

**Target coverage by type:**

- **Unit tests** - 90%+ of public functions
- **Functional tests** - Major integration paths
- **Acceptance tests** - All user-facing CLI commands
- **Error handling** - All error paths tested

**Acceptable to skip:**
- Internal/private helpers (if trivial)
- Deprecated functions (marked for removal)
- Platform-specific code (if mocked)

## Tools Integration

### If bashunit has coverage tool:

```bash
# Use built-in coverage
./bashunit --coverage tests/

# Generate HTML report
./bashunit --coverage --report-html tests/
```

### Manual analysis:

```bash
# Find all public functions
grep "^function bashunit::" src/**/*.sh

# For each, search for tests
# Report coverage percentage
```

## Output Format

Provide clear, actionable report:

```
📊 Coverage Analysis

Summary:
- Source files analyzed: 15
- Total functions: 127
- Test functions: 109
- Estimated coverage: 86%

🔴 Critical Gaps (Public API, No Tests):
1. src/module.sh:42 - bashunit::new_function
2. src/helper.sh:15 - bashunit::utility

🟡 Partial Coverage (Missing Edge Cases):
1. src/io.sh:56 - bashunit::read_file
2. src/assertions.sh:123 - bashunit::assert_custom

✅ Well Tested:
- src/assertions.sh - 95% coverage
- src/bashunit.sh - 92% coverage

📝 Recommended Next Steps:
1. Add test: test_new_function_should_handle_valid_input
2. Add test: test_read_file_should_fail_when_not_found
3. Add error path tests for assert_custom

Would you like me to:
- Generate task file for coverage improvement?
- Create test stubs for identified gaps?
- Focus on specific module?
```

## Integration with TDD

When used **before** starting work:
- Identifies what needs testing
- Populates test inventory
- Guides TDD cycle order

When used **after** completing work:
- Verifies acceptance criteria met
- Finds missed edge cases
- Validates Definition of Done

## Related Files

- Test patterns: @.claude/rules/testing.md
- TDD workflow: @.claude/rules/tdd-workflow.md
- Coverage tooling: Check `.env.example` for BASHUNIT_COVERAGE options
