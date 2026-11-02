---
name: bashunit-gh-issue
description: Use to take one GitHub issue by number to a PR (fix, implement, pick up issue).
argument-hint: "<issue-number>"
allowed-tools: [shell, read, edit, write, Grep, Glob, Agent, WebFetch]
---

# Work a GitHub issue

Accept an issue number with or without `#`.

1. Fetch `gh issue view <number> --json title,body,labels,assignees,milestone,state` and read every comment with `gh issue view <number> --comments`. Check referenced requirements and current code before repeating prior findings. State one acceptance scenario and the non-goals; never invent decisions or mark external prerequisites done.
2. If unassigned, assign yourself: `gh issue edit <number> --add-assignee @me`. Apply an existing relevant label when missing: `bug`, `enhancement`, or `documentation`. Leave another assignee's work alone.
3. Inspect the checkout first. Fetch and start from current `origin/main` without discarding local changes. Use `fix/`, `feat/`, or `docs/` according to the issue labels, defaulting to `feat/`; name the branch `<prefix><number>-<lowercase-title-slug>` with a slug up to 50 characters. Reuse an existing issue branch.
4. Read related code and tests. Keep a short plan: acceptance criteria, test strategy, owned files, smallest first step. Use a task file for nontrivial work; read `.agnostic-ai/rules/tdd-workflow.md`.
5. For each runtime change, prove a focused failing test, implement minimal GREEN, then refactor with focused tests green. Delegate only independent scopes; workers run targeted checks. Update CHANGELOG for user-facing changes and docs for changed behavior.
6. Once the whole change set is complete, the main session runs the quality gate in `.agnostic-ai/AGNOSTIC_AI.md` once. Use the `commit` skill with `Closes #<number>` in the commit body, then the `pr` skill with the issue number. Push only within user authorization.

Report the issue, acceptance scenario, branch, delivered behavior, validation, and unresolved prerequisites. Do not paste the issue or a generic plan.
