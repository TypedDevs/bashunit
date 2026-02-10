---
name: fix-test
description: Debug and fix failing tests systematically
allowed-tools: Read, Edit, Bash, Grep, Glob
---

# Fix Test Skill

Systematically debug and fix failing test(s).

## When to Use

Invoke with `/fix-test` when:
- Tests are failing unexpectedly
- Need to debug test failures
- CI/CD reports failing tests

## Workflow

### 1. Identify Failing Tests

**Run tests and capture failures:**
```bash
./bashunit tests/ 2>&1
```

**Parse output** to identify:
- Which test files are failing
- Which specific test functions
- Error messages/stack traces

### 2. Analyze Each Failure

For each failing test:

1. **Read the test file** to understand what's being tested
2. **Read the implementation** being tested
3. **Categorize the failure:**
    - ❌ **Test bug** - Test itself is wrong
    - ❌ **Implementation bug** - Code doesn't match behavior
    - ❌ **Environment issue** - Missing dependencies, wrong setup
    - ❌ **Race condition** - Parallel execution issue
    - ❌ **Flaky test** - Network, time, or random dependencies

### 3. Fix Based on Category

#### Test Bug (Wrong Test)

```bash
# ✅ Fix the test to match actual expected behavior
# Example: Wrong assertion
assert_equals "wrong_expected" "$actual"
# →
assert_equals "correct_expected" "$actual"
```

#### Implementation Bug (Wrong Code)

```bash
# ✅ Fix the implementation to match test expectations
# Follow TDD: Make test pass with minimal change
function broken_function() {
  # Fix logic here
}
```

#### Environment Issue

```bash
# ✅ Add missing setup in set_up or set_up_before_script
function set_up_before_script() {
  # Initialize required state
  export REQUIRED_VAR="value"
}
```

#### Race Condition

```bash
# ✅ Add proper synchronization
process &
local pid=$!
wait "$pid"  # Don't assume timing
```

#### Flaky Test

```bash
# ✅ Mock external dependencies
mock curl echo "stable_response"
# Instead of actual network call
```

### 4. Verify Fix

**Run the specific test:**
```bash
./bashunit path/to/fixed_test.sh
```

**Run full test suite:**
```bash
./bashunit tests/
```

**Run in parallel** to check for isolation issues:
```bash
./bashunit --parallel tests/
```

**Run multiple times** to verify stability:
```bash
for i in {1..10}; do ./bashunit path/to/test.sh || exit 1; done
```

### 5. Root Cause Analysis

**Document the fix:**
- What was failing?
- Why was it failing?
- What was changed?
- How to prevent similar issues?

**Update task file** if one exists:
```markdown
## Logbook

### 2026-02-09 14:30
- Fixed failing test: `test_should_handle_edge_case`
- Root cause: Missing null check in implementation
- Solution: Added validation in `src/module.sh:42`
- All tests now passing
```

### 6. Prevent Regression

Consider adding:
- Additional edge case tests
- Better error messages in assertions
- Documentation of assumptions

## Debugging Techniques

### Add Debug Output

```bash
function test_failing() {
  local result
  result=$(my_function "input")

  # Temporarily add debug output
  echo "DEBUG: result='$result'" >&2

  assert_equals "expected" "$result"
}
```

### Run Test in Isolation

```bash
# Run just one test function
./bashunit --filter "test_specific_failure" tests/unit/file_test.sh
```

### Check Test Fixtures

```bash
# Verify fixture files exist and have expected content
cat tests/fixtures/example.txt
```

### Verify Mocks/Spies

```bash
# Add assertions to verify doubles are working
assert_have_been_called my_mock
assert_have_been_called_with "expected_arg" my_mock
```

## Common Issues & Solutions

### Issue: "Command not found"

**Cause:** Missing mock or dependency

**Solution:**
```bash
function set_up() {
  mock missing_command echo "mocked"
}
```

### Issue: "File not found"

**Cause:** Wrong path or missing fixture

**Solution:**
```bash
# Use correct relative path
local fixture="$PWD/tests/fixtures/file.txt"
assert_file_exists "$fixture"
```

### Issue: "Assertion failed: expected X, got Y"

**Cause:** Logic bug in implementation

**Solution:**
1. Read implementation code
2. Trace through logic
3. Fix the bug
4. Verify test passes

### Issue: "Test passes locally, fails in CI"

**Cause:** Environment difference

**Solution:**
```bash
# Don't assume specific environment
# Mock system commands
mock date echo "1234567890"
```

### Issue: "Parallel tests fail, sequential pass"

**Cause:** Shared state or race condition

**Solution:**
```bash
# Use $temp_dir for isolation
local test_file="$temp_dir/unique_name_$$.txt"
```

## Quality Checks After Fix

Run these before marking as done:

```bash
# All tests pass
./bashunit tests/

# Static analysis clean
make sa

# Format clean
make lint
shfmt -w .

# Parallel execution works
./bashunit --parallel tests/

# Test stability (run 5 times)
for i in {1..5}; do ./bashunit tests/ || exit 1; done
```

## Output Format

Provide clear summary:

```
🔍 Analyzed Failures:
- test_foo: Implementation bug in src/module.sh
- test_bar: Flaky test due to network call

🔧 Fixes Applied:
1. Fixed logic in src/module.sh:42
2. Added mock for curl in test_bar

✅ Verification:
- All tests passing
- Parallel execution OK
- Static analysis clean
```

## When to Ask for Help

If after analysis:
- Root cause unclear
- Fix requires breaking API changes
- Multiple tests failing for same reason
- Systematic issue discovered

**Ask user:**
- For clarification on expected behavior
- For approval of breaking changes
- For architectural decision guidance

## Related Files

- Testing guidelines: @.claude/rules/testing.md
- TDD workflow: @.claude/rules/tdd-workflow.md
- Full instructions: @AGENTS.md
