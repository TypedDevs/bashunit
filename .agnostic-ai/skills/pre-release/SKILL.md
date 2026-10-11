---
name: pre-release
description: Run comprehensive pre-release validation checklist
allowed-tools: read, shell, Grep, Glob
---

# Pre-release validation

Assess readiness without publishing. Repository paths are relative to the repository root. Use {{$SKILL:release}} for publishing; `release.sh` owns version changes, tags and uploads.

1. Start on clean, current `main`. Read `CHANGELOG.md` and `git log <latest-release>..HEAD`; check coverage of public changes and migration guidance for breaking changes.
2. Check current versions in `bashunit`, `package.json`, `docs/package.json`, and both lockfiles (top-level and `packages[""].version`). The latest dated changelog section must agree; `Unreleased` describes the next version.
3. Run the quality gate in `.agnostic-ai/AGNOSTIC_AI.md` once. Reuse passing results for unchanged content. Use targeted checks to investigate failures; repeat suites only for new changes or a specific flakiness concern.
4. Verify CI for the exact current main commit, not a previous run: tests, Bash 3.0 compatibility, build, docs, static analysis and formatting must pass. Check the full OS matrix for changes to paths, permissions or runtime behavior. Use `gh run list --branch main` and inspect each relevant run.
5. Inspect the changed paths for unsafe input handling, secrets and undocumented public behavior. Use `.agnostic-ai/rules/bash-style.md` and `tests/unit/project/bash_compatibility_test.sh` for compatibility; `[[ ]]` is a style choice, not a Bash 3.0 failure.
6. Check affected README examples and documentation links. If Docker is available and Linux behavior needs local verification, use `make docker/alpine` and `make docker/ubuntu`; otherwise report the platform coverage supplied by CI.
7. Smoke-test `./bashunit --help`, `./bashunit --version`, and a single assertion in a unique temporary test file. Clean up that file.
8. Preview the chosen version with `./release.sh <version> --dry-run`. For changes to the release process, also inspect `--sandbox` output and its release commit without publishing.

Report passed checks, failures and specific unverified items. Pending CI is pending, not passed. Stop publishing on failed checks. Do not create tags manually or run the release script in publishing mode from this skill.
