---
name: release
description: Run pre-release validation and execute the release process
user-invocable: true
argument-hint: "[version]"
allowed-tools: Bash, Read, Grep, Glob
---

# Release

Run pre-release checks and create a new bashunit release.

## Arguments

- `$ARGUMENTS` - Version number (optional, e.g., `0.34.0`). If omitted, auto-increments the minor version.

## Current State

- Current version: !`grep -o 'BASHUNIT_VERSION="[^"]*"' bashunit | cut -d'"' -f2`
- Branch: !`git branch --show-current`
- Working tree: !`git status --short`
- Unreleased changes: !`awk '/^## Unreleased$/,/^## \[/' CHANGELOG.md | head -30`

## Instructions

### 1. Pre-flight validation

Run these checks and report pass/fail for each:

```bash
# Tests
./bashunit tests/

# Static analysis
make sa

# Linting
make lint

# Bash 3.0+ compatibility (must return no results)
grep -rn '\[\[' src/ || true
grep -rn 'declare -A' src/ || true

# CI status
gh run list --limit 3 --branch main
```

If ANY check fails, stop and report the issue. Do NOT proceed to release.

### 2. Confirm with user

Show a summary:
- Version: current → new (from `$ARGUMENTS` or auto-incremented)
- Key changes from CHANGELOG Unreleased section (abbreviated)
- All checks passed

Ask the user to confirm before proceeding.

### 3. Execute release

```bash
./release.sh $ARGUMENTS
```

If `$ARGUMENTS` is empty, run `./release.sh` (auto-increments minor version).

The script handles everything interactively: version bumps, build, commit, tag, GitHub release, and docs deployment.

### 4. Post-release

After the script completes, verify:
```bash
git log --oneline -1
git tag --list | tail -1
```

Report the release URL to the user.

## Example Usage

```
/release
/release 0.34.0
/release 1.0.0
```
