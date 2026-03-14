---
name: check-coverage
description: Analyze test coverage and identify untested code paths
allowed-tools: Read, Bash, Grep, Glob
---

# Check Coverage

Analyze test coverage and identify gaps.

## Workflow

### 1. Run Coverage (if available)

```bash
BASHUNIT_COVERAGE=true ./bashunit tests/
```

### 2. Map Functions to Tests

For each file in `src/`:

```bash
# List all public functions
grep "^function bashunit::" src/module.sh

# Find tests referencing each function
grep -r "function_name" tests/
```

### 3. Categorize Coverage

- **Well tested** — multiple tests, edge cases covered
- **Partially tested** — basic test exists, missing edge cases
- **Not tested** — no tests found

### 4. Identify Critical Gaps

**Priority 1:** Public API functions (`export -f`) with no tests
**Priority 2:** Error handling paths (`return 1`, `exit 1`) not tested
**Priority 3:** Complex conditionals without branch coverage

### 5. Generate Report

Output a markdown report with:
- Summary (total functions, tested count, estimated %)
- Coverage by module
- Critical gaps with file:line references
- Recommended tests to add (specific test function names)

## Coverage Goals

- 90%+ for public functions
- All user-facing CLI commands tested
- All error paths tested
- Internal helpers: optional (if trivial)
