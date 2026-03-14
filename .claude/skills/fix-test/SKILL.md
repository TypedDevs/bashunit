---
name: fix-test
description: Debug and fix failing tests systematically
allowed-tools: Read, Edit, Bash, Grep, Glob
---

# Fix Test

Systematically debug and fix failing test(s).

## Workflow

### 1. Identify Failures

```bash
./bashunit tests/ 2>&1
```

Parse: which files, which functions, error messages.

### 2. Categorize Each Failure

- **Test bug** — test itself is wrong (wrong expected value, bad setup)
- **Implementation bug** — code doesn't match expected behavior
- **Environment issue** — missing dependency, wrong fixture path
- **Race condition** — passes sequential, fails parallel
- **Flaky test** — network/time/random dependency

### 3. Fix

- **Test bug:** correct assertion or setup
- **Implementation bug:** minimal fix in `src/`, follow TDD
- **Environment:** fix `set_up` / fixtures
- **Race condition:** use `$temp_dir` for isolation, `wait` for async
- **Flaky:** mock external dependencies

### 4. Verify

```bash
./bashunit path/to/fixed_test.sh        # Specific test
./bashunit tests/                        # Full suite
./bashunit --parallel tests/             # Isolation check
```

### 5. Prevent Regression

Document root cause. Consider adding edge case tests to prevent recurrence.

## Debugging Tips

- Use `--filter "test_name"` to run single test
- Add `echo "DEBUG: $var" >&2` temporarily
- Check fixtures exist: `ls tests/fixtures/`
- Verify mocks: `assert_have_been_called mock_name`
