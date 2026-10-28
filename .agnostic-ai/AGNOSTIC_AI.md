# bashunit

bashunit is a Bash 3.0+ testing framework with assertions, spies, mocks, data providers, and snapshots. Documentation: https://bashunit.com.

## Required guidance

Paths are relative to the repository root, also from generated skill and agent directories. Codex loads a directory's `AGENTS.md` only when started inside it; before editing under `src/` or `tests/`, read that directory's `AGENTS.md`.

Bash 3.0 is the compatibility floor, including parse-time behavior. Follow existing patterns; study the matching tests before adding behavior. Do not invent commands or features. Preserve public APIs unless the task includes docs and CHANGELOG updates; record architectural decisions in an ADR.

## Quality gate

The main session runs this gate once after the complete change set, before committing. Reuse passing checks while content is unchanged:

```bash
make test
make test/strict
make sa
make lint
```

`make test/strict` runs what CI's strict job runs. `make lint` is the formatting authority.

## Delegation

Handle small edits directly. Delegate lookups to `code-locator`, bounded edits to `code-implementer`, and review to `code-reviewer` before pushing, each with a scope, a base revision, and a validation budget. Keep at most two delegates active, on separate files; they run only assigned targeted checks. Save long reports under ignored `.agnostic-ai/local/`.

## Specs and delivery

Edit `.agnostic-ai/` or `agnostic-ai.yaml`, never generated files. Install the pinned CLI with `npm ci` (`npm ci --force` on a Windows source checkout), then run `npm run agents:sync` and `npm run agents:check`.

Keep unrelated changes out. Use a PR unless the user asks for a direct commit to main. Update CHANGELOG for user-visible changes. Use the `commit` and `pr` skills. Never commit secrets, skip Git hooks, amend published commits, or run destructive Git commands. Pushing needs user authorization; force-pushing main needs an explicit request.
