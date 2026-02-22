---
name: add-assertion
description: Add new assertion function with comprehensive tests following TDD
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
---

# Add Assertion Skill

Add a new assertion function to bashunit following strict TDD methodology.

## When to Use

Invoke with `/add-assertion` when:
- Adding a new assertion to the framework
- User requests a new `assert_*` function
- Enhancing existing assertion capabilities

## Prerequisites

1. **Task file must exist** - Create `.tasks/YYYY-MM-DD-add-assertion-name.md`
2. **Understand patterns** - Study `tests/unit/assert_test.sh`
3. **Know the requirement** - What should the assertion do?

## Workflow

### 1. Planning Phase

**Ask user:**
- What should the assertion check?
- What should it be called? (e.g., `assert_json_contains`)
- What parameters does it take?
- What should success look like?
- What should failure messages say?

**Document in task file:**
```markdown
# Add assert_json_contains

## Context
Need assertion to verify JSON contains a specific key-value pair.

## Acceptance Criteria
- [ ] Function validates JSON structure
- [ ] Function checks for key existence
- [ ] Function checks value matches
- [ ] Clear error messages on failure
- [ ] Works with nested JSON
- [ ] Handles malformed JSON gracefully

## Test Inventory
### Unit Tests
- [ ] test_assert_json_contains_should_pass_when_key_value_exists
- [ ] test_assert_json_contains_should_fail_when_key_missing
- [ ] test_assert_json_contains_should_fail_when_value_differs
- [ ] test_assert_json_contains_should_handle_nested_keys
- [ ] test_assert_json_contains_should_fail_on_malformed_json
```

### 2. Study Existing Patterns

**Read assertion patterns:**
```bash
# Study how other assertions work
Read tests/unit/assert_test.sh
Read src/assertions.sh
```

**Identify pattern:**
- Parameter validation
- Assertion logic
- Error message format
- Success/failure return codes
- Testing approach (including failure tests)

### 3. TDD Cycle 1: Basic Success Case

#### RED
```bash
# tests/unit/assert_json_contains_test.sh

function test_assert_json_contains_should_pass_when_key_value_exists() {
  local json='{"name": "bashunit", "version": "0.32.0"}'

  assert_json_contains "name" "bashunit" "$json"
}
```

Run test - **MUST FAIL** (function doesn't exist):
```bash
./bashunit tests/unit/assert_json_contains_test.sh
```

#### GREEN

```bash
# src/assert_json.sh (or add to src/assertions.sh)

function assert_json_contains() {
  local key="$1"
  local expected_value="$2"
  local json="$3"

  # Minimal implementation
  local actual_value
  actual_value=$(echo "$json" | grep -o "\"$key\": *\"[^\"]*\"" | cut -d'"' -f4)

  if [[ "$actual_value" == "$expected_value" ]]; then
    return 0
  fi

  echo "Expected key '$key' to have value '$expected_value', got '$actual_value'" >&2
  return 1
}
```

Run test - **MUST PASS**:
```bash
./bashunit tests/unit/assert_json_contains_test.sh
```

#### REFACTOR

Improve implementation:
- Better JSON parsing
- Error handling
- Documentation

### 4. TDD Cycle 2: Failure Case

#### RED
```bash
function test_assert_json_contains_should_fail_when_key_missing() {
  local json='{"name": "bashunit"}'

  # Use assert_fails to test that the assertion fails
  assert_fails \
    "assert_json_contains 'version' '0.32.0' '$json'"
}
```

#### GREEN

Update implementation to handle missing keys:
```bash
function assert_json_contains() {
  local key="$1"
  local expected_value="$2"
  local json="$3"

  # Check if key exists
  if ! echo "$json" | grep -q "\"$key\""; then
    echo "Key '$key' not found in JSON" >&2
    return 1
  fi

  local actual_value
  actual_value=$(echo "$json" | grep -o "\"$key\": *\"[^\"]*\"" | cut -d'"' -f4)

  if [[ "$actual_value" == "$expected_value" ]]; then
    return 0
  fi

  echo "Expected key '$key' to have value '$expected_value', got '$actual_value'" >&2
  return 1
}
```

#### REFACTOR

Continue improving.

### 5. TDD Cycle 3-N: Additional Cases

Continue RED-GREEN-REFACTOR for:
- Different value types (numbers, booleans)
- Nested JSON objects
- Malformed JSON handling
- Edge cases (empty values, null, etc.)

### 6. Documentation

Add function documentation:

```bash
##
# Asserts that a JSON string contains a specific key-value pair
#
# Arguments:
#   $1 - Key to search for
#   $2 - Expected value
#   $3 - JSON string
#
# Returns:
#   0 if key exists with expected value
#   1 if key missing or value differs
#
# Example:
#   local json='{"name": "bashunit"}'
#   assert_json_contains "name" "bashunit" "$json"
##
function assert_json_contains() {
  # Implementation
}
```

### 7. Integration

**If new file created:**
- Source it in main `bashunit.sh`
- Add to build process if needed

**Update exports:**
```bash
# In src/bashunit.sh or relevant file
export -f assert_json_contains
```

### 8. Comprehensive Testing

**Run all assertion tests:**
```bash
./bashunit tests/unit/assert*.sh
```

**Run full test suite:**
```bash
./bashunit tests/
```

**Quality checks:**
```bash
make sa
make lint
shfmt -w .
```

### 9. Documentation Updates

**Update user-facing docs:**
- Add to `docs/assertions.md` (or equivalent)
- Add examples
- Add to API reference
- Update CHANGELOG

**Example docs:**
```markdown
## assert_json_contains

Asserts that a JSON string contains a specific key-value pair.

### Usage

bash
assert_json_contains "key" "expected_value" "$json_string"


### Parameters

- `key` - The JSON key to look for
- `expected_value` - The expected value for the key
- `json_string` - The JSON to search

### Examples

bash
# Simple object
local user='{"name": "John", "age": 30}'
assert_json_contains "name" "John" "$user"

# Nested object
local data='{"user": {"name": "John"}}'
assert_json_contains "user.name" "John" "$data"

```

### 10. Final Verification

**Complete checklist:**
- [ ] All tests passing (RED-GREEN-REFACTOR for each)
- [ ] Test both success and failure cases
- [ ] Test edge cases
- [ ] Function documented
- [ ] Exported/integrated properly
- [ ] User documentation updated
- [ ] CHANGELOG updated
- [ ] Code review ready
- [ ] Task file completed

## Testing Patterns for Assertions

### Test Success
```bash
function test_should_pass_when_condition_met() {
  assert_new_assertion "input"
}
```

### Test Failure
```bash
function test_should_fail_when_condition_not_met() {
  assert_fails \
    "assert_new_assertion 'bad_input'"
}
```

### Test Error Message
```bash
function test_should_show_helpful_error_message() {
  local output
  output=$(assert_new_assertion "bad_input" 2>&1) || true

  assert_contains "Expected" "$output"
  assert_contains "Got" "$output"
}
```

### Test Edge Cases
```bash
function test_should_handle_empty_input() {
  assert_fails \
    "assert_new_assertion ''"
}

function test_should_handle_special_characters() {
  assert_new_assertion "special$chars"
}
```

## Common Assertion Patterns

### Parameter Validation
```bash
if [[ $# -lt 2 ]]; then
  echo "assert_name requires at least 2 arguments" >&2
  return 1
fi
```

### Clear Error Messages
```bash
echo "Expected <expected>, but got <actual>" >&2
echo "  Expected: $expected" >&2
echo "  Actual: $actual" >&2
```

### Consistent Return Codes
```bash
return 0  # Success
return 1  # Assertion failed
```

## Related Assertions to Study

- `assert_equals` - Basic comparison
- `assert_contains` - String searching
- `assert_matches` - Regex matching
- `assert_file_exists` - File operations
- `assert_array_contains` - Array operations

## Output Format

Provide progress updates:

```
📝 Planning: assert_json_contains function
    - Parameters: key, expected_value, json_string
    - Will validate JSON and check key-value

🔴 RED: test_should_pass_when_key_value_exists
    Test written and failing (function not found)

🟢 GREEN: Minimal implementation added
    Test now passing

🔵 REFACTOR: Improved JSON parsing
    All tests still passing

✅ Completed: assert_json_contains
    - 5 tests passing
    - Documentation added
    - Ready for review
```

## Quality Standards

**All assertions must:**
- Follow Bash 3.0+ compatibility (@.claude/rules/bash-style.md)
- Have comprehensive tests (success, failure, edge cases)
- Have clear, helpful error messages
- Be documented with examples
- Pass shellcheck and formatting
- Work in parallel test execution

## Related Files

- Test patterns: @tests/unit/assert_test.sh
- Assertion implementations: @src/assertions.sh
- Testing rules: @.claude/rules/testing.md
- TDD workflow: @.claude/rules/tdd-workflow.md
