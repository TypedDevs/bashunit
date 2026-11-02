---
name: pre-release
description: Use before a release to check readiness without publishing (pre-release, release readiness).
allowed-tools: [read, shell, Grep, Glob]
---

# Pre-release validation

Check readiness without publishing. Use {{$SKILL:release}} to publish; `release.sh` owns version changes, tags and uploads.

1. Start on clean, current `main`. Read `CHANGELOG.md` and `git log <latest-release>..HEAD`; check that public changes are covered and breaking changes have migration guidance.
2. Check versions in `bashunit`, `package.json`, `docs/package.json`, and both lockfiles (top-level and `packages[""].version`). The latest dated changelog section must agree; `Unreleased` describes the next version.
3. Run the quality gate in `.agnostic-ai/AGNOSTIC_AI.md` once. Reuse passing results for unchanged content; use targeted checks to investigate failures; repeat suites only for new changes or suspected flakiness.
4. Verify CI for the exact current main commit, not a previous run: tests, Bash 3.0 compatibility, build, docs, static analysis and formatting must pass. Check the full OS matrix for changes to paths, permissions or runtime behavior. Use `gh run list --branch main` and inspect each relevant run.
5. Check changed paths for unsafe input handling, secrets and undocumented public behavior. Use `.agnostic-ai/rules/bash-style.md` and `tests/unit/project/bash_compatibility_test.sh` for compatibility; `[[ ]]` is a style choice, not a Bash 3.0 failure.
6. Check affected README examples and documentation links. If Docker is available and Linux behavior needs local verification, use `make docker/alpine` and `make docker/ubuntu`; otherwise report the platform coverage supplied by CI.
7. Smoke-test `./bashunit --help`, `./bashunit --version`, and a single assertion in a unique temporary test file. Clean up that file.
8. Preview the chosen version with `./release.sh <version> --dry-run`. For changes to the release process, also inspect `--sandbox` output and its release commit without publishing.

Report passed checks, failures and unverified items; pending CI is not passed. Do not publish on failed checks, create tags by hand, or run the release script in publishing mode from this skill.
