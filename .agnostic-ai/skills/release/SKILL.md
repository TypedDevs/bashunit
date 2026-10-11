---
name: release
description: Run pre-release validation and execute the release process
user-invocable: true
argument-hint: "[version]"
allowed-tools: shell, read, Grep, Glob
---

# Release

Use `./release.sh` from the repository root. It owns manifest and lockfile versions, build, checksum, changelog, commit, signed tags, GitHub release and `latest`. Fix the script when a step is missing; do not duplicate its flow.

1. Run {{$SKILL:pre-release}} and reuse completed checks for unchanged content. Start on clean, current `main` and require CI success for that commit.
2. Use the user-selected version. Otherwise recommend a version from the changes and repository history; the script defaults to a minor bump. Performance and maintenance work can justify a minor release before 1.0. Confirm only if the version or publishing authorization is missing; an earlier selection and authorization remain valid.
3. Preview `./release.sh <version> --dry-run`. Finish validation and show the concrete preview before requesting any missing publishing approval.
4. Once authorized and green, run `./release.sh <version> --force`.
5. Verify `gh release view <version>` contains the binary and checksum; check the matching `npm-publish.yml` run, published npm version, installer checksum, and `origin/latest` release commit. Report the release URL and any unfinished verification.

The dry run prints the previous dated changelog section because it does not rewrite files. The real run converts `Unreleased` first. Tags are annotated and respect `tag.gpgsign`; `v0` points to the release commit. npm publishes through `.github/workflows/npm-publish.yml` on the GitHub release event.

If execution fails, inspect the completed steps before retrying. `./release.sh --rollback` restores files from its saved backup; it does not undo already-pushed tags, commits or published artifacts.
