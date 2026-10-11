# bashunit

bashunit is a Bash 3.0+ testing framework with assertions, spies, mocks, data providers, and snapshots. Documentation: https://bashunit.com.

## Required guidance

All paths are relative to the repository root, including from generated skill and agent directories. Read the applicable source rules before editing. Directory scopes generate native instructions for that directory. Sessions started at the root must also read the relevant sources below; some clients do not load nested instructions during later edits.

| Task | Read |
|------|------|
| Changes to `src/` or `bashunit` | `.agnostic-ai/rules/architecture-map.md` |
| Shell changes under `src/` or `tests/`, including entrypoint changes | `.agnostic-ai/rules/bash-style.md` |
| Changes to `src/`, `bashunit`, or fork census acceptance tests | `.agnostic-ai/rules/perf-fork-budget.md` |
| Runtime development or task plans | `.agnostic-ai/rules/tdd-workflow.md` |
| Test changes | `.agnostic-ai/rules/testing.md` |

Bash 3.0 is the compatibility floor, including parse-time behavior. Use existing patterns. Study the relevant tests before adding assertions, doubles, providers, hooks, or CLI behavior. Do not invent commands or features.

Use TDD for runtime changes: RED for the right reason, minimal GREEN, then REFACTOR with tests green. Complete the acceptance criteria. Use a task file for nontrivial work; the `tdd-cycle` skill carries the full workflow. Preserve public APIs unless the requested change includes documentation and CHANGELOG updates. Record architectural decisions in an ADR.

## Quality gate

Run once after the complete change set, before committing:

```bash
./bashunit tests/
./bashunit --parallel tests/
make sa
make lint
```

`make lint` is the formatting authority. Match surrounding 2-space indentation by hand. Never run `shfmt -w`; it conflicts with EditorConfig. The `commit` skill bundles the detailed formatting constraints and optional drift comparison.

## Delegation

Handle small edits directly. Keep one acceptance scenario and a short plan in the main session. Delegate independent lookups to `code-locator`, bounded edits to `code-implementer`, and verified defect review to `code-reviewer` before pushing. Assign a question or file scope, a base revision, and a validation budget. Reuse findings. Keep at most two delegates active.

Workers share the checkout: assign separate files, preserve others' edits, and run only assigned targeted checks. The coordinator runs the full gate. Return concise file and line evidence; save longer reports under ignored `.agnostic-ai/local/`.

## Specs and delivery

Edit `.agnostic-ai/` or `agnostic-ai.yaml`, never generated instructions, agents, skills, hooks, or settings. Install the pinned contributor dependencies with `npm ci` (use `npm ci --force` for a Windows source checkout because the published npm package restricts its OS). Run `npm run agents:sync` and `npm run agents:check`, which use the project-local CLI.

Keep unrelated changes out of the PR. Update CHANGELOG for user-visible changes. Use the `pr` skill for pull requests. Use Conventional Commits: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, or `chore`, with an optional domain scope such as `assert`, `runner`, `cli`, or `docs`.

Never commit secrets, skip Git hooks, amend published commits, or use destructive Git commands. Pushing requires user authorization; force-pushing main requires an explicit request. All local gates must pass before committing.
