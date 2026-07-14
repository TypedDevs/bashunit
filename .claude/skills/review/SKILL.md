---
name: review
description: Review a GitHub pull request; defaults to the current branch's PR when no number is given
user-invocable: true
argument-hint: "[#N]"
allowed-tools: Bash, Read, Grep, Glob
---

# Review a Pull Request

Review a GitHub PR. When no number is given, review the PR for the current branch.

> For reviewing your uncommitted working diff instead, use `/code-review`.

## Current Branch Context
- Branch: !`git branch --show-current`
- PR for this branch: !`gh pr view --json number,title,state,url --jq '"#\(.number) \(.title) [\(.state)] \(.url)"' 2>/dev/null || echo "none"`

## Arguments
- `$ARGUMENTS` - PR number to review (optional, e.g., `#42` or `42`).

## Instructions

1. **Resolve which PR to review:**
  - If `$ARGUMENTS` contains a number, review that PR.
  - Otherwise, use the current branch's PR shown in the context above.
  - If neither yields a PR (no argument and the branch has no open PR), run `gh pr list` and ask the user which one to review. Do NOT guess.

2. **Load the PR:**
  ```bash
  gh pr view <number> --json number,title,body,state,headRefName,baseRefName,url
  gh pr diff <number>
  ```

3. **Review the diff** against this project's standards (see `.claude/CLAUDE.md` and `.claude/rules/`):
  - Bash 3.0+ compatibility (no `declare -A`, `[[ ]]`, `${var,,}`, negative indexing, `&>>`)
  - Tests exist and follow TDD; both success and failure paths covered
  - Naming, namespacing (`bashunit::*` / `_private`), and dynamic-scope safety
  - ShellCheck cleanliness and `shfmt` formatting
  - CHANGELOG.md updated for user-facing changes

4. **Report findings** grouped by severity (blocker / suggestion / nit), each as `path:line — problem. fix.`. No praise, no scope creep. State plainly if the PR looks good.
