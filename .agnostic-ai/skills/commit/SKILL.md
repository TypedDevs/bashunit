---
name: commit
description: Stage and commit changes using conventional commits format
disable-model-invocation: true
allowed-tools: shell, read, Grep, Glob
x-claude:
  argument-hint: "[message hint]"
---

# Commit

Use this skill for project commits. Read [formatting constraints](references/formatting.md) when checking shell changes; repository paths are relative to the repository root. Accept an optional message hint.

1. Inspect `git status --short`, the current branch, relevant staged and unstaged diffs, and recent history. Reuse state already obtained during this task unless it may have changed. Understand the complete change and confirm the coordinator's canonical quality gate passed after the final edits; do not repeat a passing gate without new changes or unresolved evidence.
2. Stage only the relevant files by explicit name. Never use `git add .` or `git add -A`, and keep credentials out of Git. Review `git diff --cached` before committing; one commit covers one logical change.
3. Use `<type>(<optional-scope>): <description>` with the project's types: `feat`, `fix`, `perf`, `docs`, `style`, `refactor`, `test`, or `chore`. Choose a domain scope such as `assert`, `runner`, `cli`, `doubles`, `docs`, or `ci` when useful. Follow sibling history, use a lowercase imperative subject under 70 characters without a final period, and add a body only when the reason needs explanation.
4. Use the configured Git identity and `git commit` with the exact message. Write public text in the user's voice without attribution; tooling names are appropriate when tooling is the subject. Never skip hooks or amend published history. If a hook fails, fix the cause and retry a new commit rather than rewriting an existing one.
5. Verify the created commit with `git log --oneline -1` and inspect the remaining working state. A commit does not grant push authorization; use the `pr` skill for an authorized PR delivery.
