---
name: gh-issue
description: Fetch GitHub issue, create branch, plan and implement with TDD, then open PR
user-invocable: true
argument-hint: "<issue-number>"
allowed-tools: shell, read, edit, write, Grep, Glob, Agent, WebFetch
---

# Work a GitHub issue

Repository paths are relative to the repository root. Accept an issue number with or without `#`.

1. Fetch `gh issue view <number> --json title,body,labels,assignees,milestone,state` and read every comment with `gh issue view <number> --comments`. Inspect referenced requirements and current code before repeating prior findings. State one acceptance scenario and non-goals; do not invent decisions or mark external prerequisites complete.
2. Assign yourself if unassigned with `gh issue edit <number> --add-assignee @me`. Apply an existing relevant label when missing: `bug`, `enhancement`, or `documentation`. Preserve another assignee's work.
3. Inspect the checkout before switching branches. Fetch main and start from current `origin/main` without discarding local changes. Use `fix/`, `feat/`, or `docs/` according to the issue labels, defaulting to `feat/`; name the branch `<prefix><number>-<lowercase-title-slug>` with a slug up to 50 characters. Reuse an existing issue branch when continuing its work.
4. Study related code and tests. Keep a short plan covering acceptance criteria, test strategy, owned files, and the smallest first step. Use a task file for nontrivial work and read `.agnostic-ai/rules/tdd-workflow.md`.
5. For each runtime change, prove a focused failing test, implement minimal GREEN, then refactor with focused tests green. Delegate only independent scopes; workers run assigned targeted checks. Update CHANGELOG for user-facing changes and docs for changed behavior.
6. Once the whole change set is complete, the main session runs the canonical quality gate in `.agnostic-ai/AGNOSTIC_AI.md` once. Use the `commit` skill with `Closes #<number>` in the commit body, then the `pr` skill with the issue number. Push only within user authorization.

Report the issue, acceptance scenario, branch, delivered behavior, validation, and any unresolved prerequisite. Do not paste the full issue or a generic plan back to the user.
