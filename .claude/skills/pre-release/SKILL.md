---
name: pre-release
description: Run comprehensive pre-release validation checklist
allowed-tools: Read, Bash, Grep, Glob
---

# Pre-Release Validation

Run all checks before releasing a new bashunit version.

## Checklist

### 1. Version Consistency

Verify version matches across: `package.json`, `CHANGELOG.md`, `src/bashunit.sh`

### 2. Full Test Suite

```bash
./bashunit tests/unit/
./bashunit tests/functional/
./bashunit tests/acceptance/
./bashunit tests/
./bashunit --parallel tests/
```

All must pass. Run 3-5 times to catch flaky tests.

### 3. Static Analysis & Formatting

```bash
make sa           # ShellCheck — zero warnings
make lint         # EditorConfig — clean
shfmt -l .        # Check formatting (don't modify)
```

### 4. Documentation

- `CHANGELOG.md` — version section complete with all changes
- `README.md` — examples current, no broken links
- No remaining TODOs/FIXMEs in docs

### 5. Bash 3.0+ Compatibility

```bash
grep -rn '\[\[' src/            # Should not use [[
grep -rn 'declare -A' src/      # No associative arrays
grep -rn '\${.*,,}' src/        # No case conversion
```

### 6. Cross-Platform (if Docker available)

```bash
make docker/alpine
make docker/ubuntu
```

### 7. Security Scan

No hardcoded secrets, no unsafe eval, input validation present.

### 8. Breaking Changes

Review `git log` since last release. Breaking changes must be documented with migration guide.

### 9. Git & CI Status

- Working directory clean
- All CI checks passing: `gh run list --limit 5`

### 10. Smoke Test

```bash
./bashunit --help
./bashunit --version
echo 'function test_smoke() { assert_equals "1" "1"; }' > /tmp/smoke_test.sh
./bashunit /tmp/smoke_test.sh
rm /tmp/smoke_test.sh
```

## Output

Report each check as pass/fail/warning. Only proceed to release when ALL checks pass.

## After Validation

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```
