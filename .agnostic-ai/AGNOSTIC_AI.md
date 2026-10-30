# bashunit

Bash 3.0+ testing framework. Docs: https://bashunit.com.

## Guidance

Paths are repository-relative. Read `src/AGENTS.md` or `tests/AGENTS.md` before edits there; Codex root sessions do not auto-load child instructions.

Preserve Bash 3.0 parsing and public APIs; follow sibling tests/code. Update docs/CHANGELOG for behavior changes; ADRs for architecture.

## Validation

Main selects checks by changed behavior/risk and reuses unchanged passes. Small fixes: affected tests, ShellCheck, `make lint`; strict mode for options, errors, hooks, or workers. Cross-cutting runtime changes/releases need:

```bash
BASHUNIT_PARALLEL_JOBS=4 make test
BASHUNIT_PARALLEL_JOBS=4 make test/strict
make sa
make lint
```

Strict mode matches CI; `make lint` controls formatting.

## Delivery

Delegate lookups/edits/reviews to `code-locator`/`code-implementer`/`code-reviewer`; review before pushing. Max two delegates with independent worktrees, scope, base revision, and focused checks. Reports: ignored `.agnostic-ai/local/`.

Edit `.agnostic-ai/` and `agnostic-ai.yaml`, never generated files. Install the pinned CLI: `npm ci` (`--force` on Windows); run `npm run agents:sync` and `npm run agents:check`.

Use `commit`/`pr` skills. Keep changes scoped; use PRs unless asked for main. Push only when authorized. No secrets, hook bypasses, rewriting published history, or destructive Git.
