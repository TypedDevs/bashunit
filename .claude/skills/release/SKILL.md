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

**Important:** The script uses interactive prompts (`read`) that may be skipped when run from Claude. If the script skips the commit, tag, push, or GitHub release steps, complete them manually:

```bash
# Commit the release changes
git add CHANGELOG.md bashunit install.sh package.json
git commit -m "chore(release): <version>"

# Tag
git tag -a <version> -m "<version>"

# Push
git push origin main --tags

# Create GitHub release with BOTH binary and checksum as assets
gh release create <version> bin/bashunit bin/checksum \
  --title "<version>" \
  --notes-file /tmp/bashunit-release-notes-<version>.md

# Update latest branch for docs deployment
git checkout latest && git rebase <version> \
  && git push origin latest --force && git checkout main
```

### 4. Post-release

After the script completes, verify:
```bash
git log --oneline -1
git tag --list --sort=-v:refname | head -1
```

Report the release URL to the user.

## Example Usage

```
/release
/release 0.34.0
/release 1.0.0
```
