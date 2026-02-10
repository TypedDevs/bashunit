---
name: pre-release
description: Run comprehensive pre-release validation checklist
allowed-tools: Read, Bash, Grep, Glob
---

# Pre-Release Skill

Execute comprehensive pre-release validation checklist before releasing a new bashunit version.

## When to Use

Invoke with `/pre-release` when:
- Preparing to release a new version
- Need to verify everything is ready
- Want comprehensive quality check

## Pre-Release Checklist

### 1. Version Information

**Verify version consistency:**

```bash
# Check package.json version
grep '"version"' package.json

# Check if version updated in:
# - package.json
# - CHANGELOG.md
# - src/bashunit.sh (if has version constant)
# - docs (if version referenced)
```

**Report:**
- Current version found
- Files checked
- Any inconsistencies

### 2. Run Complete Test Suite

**All test types:**

```bash
# Unit tests
./bashunit tests/unit/

# Functional tests
./bashunit tests/functional/

# Acceptance tests
./bashunit tests/acceptance/

# All tests together
./bashunit tests/

# Parallel execution (verify no race conditions)
./bashunit --parallel tests/
```

**Verify:**
- ✅ All tests pass
- ✅ No skipped tests (unless documented)
- ✅ No flaky tests (run 3-5 times)
- ✅ Parallel execution works

### 3. Static Analysis

**ShellCheck:**

```bash
# Run shellcheck on all shell files
make sa
# OR
shellcheck -x $(find . -name "*.sh" -not -path "./local/*")
```

**Verify:**
- ✅ No shellcheck warnings
- ✅ No shellcheck errors

### 4. Code Formatting

**Check formatting:**

```bash
# EditorConfig compliance
make lint
# OR
editorconfig-checker

# Shell formatting (check, don't modify yet)
shfmt -l .
```

**Verify:**
- ✅ All files pass editorconfig
- ✅ No formatting issues

### 5. Documentation

**Check documentation is current:**

```bash
# Verify README examples work
# Verify CHANGELOG updated
# Verify API docs match code
```

**Read and verify:**
- `README.md` - Examples are current
- `CHANGELOG.md` - Latest version documented with all changes
- `docs/` - All features documented
- `.github/CONTRIBUTING.md` - Still accurate

**Check for:**
- ❌ Outdated examples
- ❌ Missing new features
- ❌ Broken links
- ❌ TODOs or FIXMEs

### 6. Compatibility

**Verify Bash 3.2+ compatibility:**

```bash
# Check for Bash 4+ features
grep -r "\[\[" src/  # Should use [ instead
grep -r "declare -A" src/  # Associative arrays (Bash 4+)
grep -r "\${.*,,}" src/  # Case conversion (Bash 4+)
```

**Report any violations:**
- ❌ Features requiring Bash 4+
- ⚠️ Potential compatibility issues

### 7. Cross-Platform Testing

**If available, test on multiple platforms:**

```bash
# macOS (Bash 3.2)
./bashunit tests/

# Linux (if Docker available)
make test/alpine

# Check for platform-specific issues
```

**Verify:**
- ✅ Works on macOS (Bash 3.2)
- ✅ Works on Linux
- ✅ No hardcoded paths
- ✅ No platform assumptions

### 8. Performance

**Check for performance regressions:**

```bash
# If benchmark exists
./tests/benchmark/bashunit_bench.sh

# Time test suite execution
time ./bashunit tests/
```

**Compare to previous version:**
- ⚠️ Slower than before? Investigate
- ✅ Same or faster

### 9. Security

**Check for security issues:**

```bash
# Look for potential security issues
grep -r "eval " src/  # Evaluate use of eval
grep -r "\$\(" src/ | grep -v "^\s*#"  # Command substitutions

# Check for secrets in code
grep -r "password\|token\|secret\|key" src/ --ignore-case
```

**Verify:**
- ✅ No hardcoded secrets
- ✅ No unsafe eval usage
- ✅ Input validation present

### 10. Breaking Changes

**Review changes for breaking changes:**

```bash
# Check git log since last release
git log v0.31.0..HEAD --oneline

# Look for breaking changes in CHANGELOG
grep -i "breaking" CHANGELOG.md
```

**Verify:**
- Public API unchanged (or documented)
- CLI arguments unchanged (or documented)
- Breaking changes clearly marked
- Migration guide provided (if needed)

### 11. Dependencies

**Check dependencies are documented:**

```bash
# External dependencies
grep -r "command -v\|which " src/

# Required tools
cat README.md | grep -A 10 "Requirements"
```

**Verify:**
- ✅ All dependencies documented
- ✅ Version requirements clear
- ✅ Optional dependencies marked

### 12. Installation

**Test installation methods:**

```bash
# If install script exists
./install.sh --help

# Manual installation
# (Follow README instructions)
```

**Verify:**
- ✅ Installation script works
- ✅ README instructions accurate
- ✅ Uninstall works (if provided)

### 13. Examples

**Verify examples work:**

```bash
# Run example tests
if [ -d example/ ]; then
  ./bashunit example/
fi
```

**Check example directory:**
- ✅ Examples run successfully
- ✅ Examples demonstrate key features
- ✅ Examples up to date

### 14. Release Notes

**Verify CHANGELOG.md is ready:**

```markdown
## [x.y.z] - YYYY-MM-DD

### Added
- New features listed

### Changed
- Changes listed

### Fixed
- Bug fixes listed

### Breaking Changes
- Breaking changes listed (if any)
```

**Check:**
- ✅ Version number correct
- ✅ Date present (or set to TBD)
- ✅ All changes documented
- ✅ Contributors credited (if applicable)

### 15. Git Status

**Check repository state:**

```bash
# Verify clean working tree
git status

# Verify on correct branch
git branch

# Verify commits pushed
git log origin/main..HEAD
```

**Verify:**
- ✅ Working directory clean
- ✅ All commits pushed
- ✅ No uncommitted changes
- ✅ On main/release branch

### 16. CI/CD

**Check CI status:**

```bash
# If using GitHub Actions
gh run list --limit 5

# Check latest workflow runs
# All should be passing
```

**Verify:**
- ✅ All CI checks passing
- ✅ No failing workflows
- ✅ Tests passing on all platforms

### 17. Final Manual Tests

**Smoke test key functionality:**

```bash
# Test basic usage
./bashunit --help
./bashunit --version

# Run simple test
echo 'function test_smoke() { assert_equals "1" "1"; }' > /tmp/smoke_test.sh
./bashunit /tmp/smoke_test.sh
rm /tmp/smoke_test.sh
```

**Verify:**
- ✅ Help works
- ✅ Version displays correctly
- ✅ Basic test runs

## Output Format

Provide comprehensive checklist report:

```
🚀 Pre-Release Validation Report

Version: 0.32.0
Date: 2026-02-09

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Tests (All Passing)
    • Unit tests: 45 passed
    • Functional tests: 23 passed
    • Acceptance tests: 31 passed
    • Parallel execution: OK

✅ Static Analysis
    • ShellCheck: No issues
    • EditorConfig: Clean

✅ Documentation
    • README: Current
    • CHANGELOG: Updated for v0.32.0
    • Examples: All working

✅ Compatibility
    • Bash 3.2+: Compatible
    • No Bash 4+ features found

✅ Security
    • No hardcoded secrets
    • Input validation present

✅ Git Status
    • Working directory: Clean
    • Branch: main
    • All commits pushed

⚠️ Warnings:
    • Test suite 5% slower than previous version
    • One TODO found in docs/advanced.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Pre-Release Checklist: 16/17 ✅

❌ Remaining:
1. Review performance regression
    └─ Run benchmarks and compare

✅ Release Ready: NO
    └─ Address performance issue before releasing

Next Steps:
1. Investigate test suite performance
2. Re-run pre-release check
3. Create git tag: v0.32.0
4. Push release
```

## Failure Handling

**If ANY check fails:**
1. **Stop the release process**
2. **Document the failure**
3. **Fix the issue**
4. **Re-run pre-release check**
5. **Do NOT proceed** until all checks pass

## Success Criteria

**All these must be TRUE:**
- ✅ All tests passing (unit, functional, acceptance)
- ✅ ShellCheck clean
- ✅ Formatting clean
- ✅ Documentation updated
- ✅ CHANGELOG complete
- ✅ Version numbers consistent
- ✅ Git state clean
- ✅ CI passing
- ✅ No known security issues
- ✅ Bash 3.2+ compatible

## After Pre-Release Validation

**When all checks pass, suggest next steps:**

```bash
# Create release tag
git tag -a v0.32.0 -m "Release v0.32.0"

# Push tag
git push origin v0.32.0

# Run release script if available
./release.sh
```

## Related Files

- Release process: @release.sh (if exists)
- CI workflows: @.github/workflows/
- Contributing guide: @.github/CONTRIBUTING.md
- Full instructions: @AGENTS.md
