---
name: release
description: Run pre-release validation and execute the release process
user-invocable: true
argument-hint: "[version]"
allowed-tools: Bash, Read, Grep, Glob
---

# Release

Thin reminder around `./release.sh`. The release script owns the whole
end-to-end flow (version bumps, build, checksum, CHANGELOG, commit, signed
tags, push, GitHub release, `latest` branch). Don't reimplement those steps
here — fix `release.sh` if something is missing.

## Current State

- Current version: !`grep -o 'BASHUNIT_VERSION="[^"]*"' bashunit | cut -d'"' -f2`
- Branch: !`git branch --show-current`
- Working tree: !`git status --short`
- Unreleased changes: !`awk '/^## Unreleased$/,/^## \[/' CHANGELOG.md | head -30`

## Steps

### 1. Pre-flight

```bash
./bashunit tests/                 # all green
make sa && make lint              # static analysis + editorconfig
gh run list --limit 3 --branch main
```

Stop and report if anything fails. Don't release on a red main.

### 2. Pick the version

`$ARGUMENTS` overrides; otherwise the script auto-increments the minor.
Bump by the Unreleased section: a `### Added`/feat → minor, only `### Fixed` →
patch. Confirm the version with the user before publishing.

### 3. Preview, then publish

```bash
./release.sh <version> --dry-run   # preview; changes nothing
./release.sh <version> --force     # publish (non-interactive)
```

Notes:
- `--dry-run` release notes look "off" (they show the previous version's
  section) because the CHANGELOG isn't actually rewritten in a dry run. The
  real run converts `## Unreleased` → `## [<version>]` first, so the published
  notes are correct. Not a bug.
- Tagging is gpgsign-safe: `release::create_tags` makes annotated, `-m`
  tags (signed when `tag.gpgsign=true`) and pins `v0` to the release commit
  (`^{}`). No manual tagging needed.
- npm publishes automatically via `.github/workflows/npm-publish.yml` on the
  GitHub `release: published` event.

### 4. Verify the published artifacts

```bash
gh release view <version>                       # assets: bin/bashunit + bin/checksum
gh run list --workflow npm-publish.yml --limit 1
git log --oneline -1 origin/latest             # latest branch advanced (docs deploy)
```

Confirm the npm version and the install.sh checksum match, then report the
release URL.

## Recovery

`./release.sh --rollback` restores files from the most recent backup if a run
fails mid-way.

## Example Usage

```
/release
/release 0.40.0
```
