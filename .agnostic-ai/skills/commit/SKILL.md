---
name: commit
description: Stage and commit changes using conventional commits format
user-invocable: true
argument-hint: "[message hint]"
disable-model-invocation: true
allowed-tools: shell, read, Grep, Glob
---

# Commit with Conventional Commits

Read [the formatting constraints](references/formatting.md) before formatting or checking shell changes. Repository paths are relative to the repository root.

Stage and commit current changes using the conventional commits format.

> **IMPORTANT:** This skill MUST be used for ALL commits, even when the user says "commit" without `commit`. Never commit without following these steps.

## Current State

Run the following commands before proceeding:
- Branch: `git branch --show-current`
- Status: `git status --short`
- Staged diff: `git diff --cached --stat 2>/dev/null`
- Unstaged diff: `git diff --stat 2>/dev/null`
- Recent commits: `git log --oneline -5 2>/dev/null`

## Arguments
- User-supplied argument: Optional hint for the commit message (e.g., `fix the snapshot comparison`)

## Instructions

1. **Review the state above**, understand what changed and why.

2. **Stage files**, add only the relevant changed files by name. Never use `git add -A` or `git add .`. Never stage files that contain secrets (`.env`, credentials, etc.).

3. **Determine the commit type** from the nature of the changes:
    - `feat`, new feature or capability
    - `fix`, bug fix
    - `docs`, documentation only
    - `style`, formatting, whitespace (no logic change)
    - `refactor`, code restructuring (no behavior change)
    - `test`, adding or updating tests
    - `chore`, maintenance, tooling, config
    - `perf`, performance improvement

4. **Determine the scope** from the area of the codebase affected:
    - `assert`, assertions (`src/assert*.sh`)
    - `runner`, test runner
    - `cli`, CLI entry point, flags, options
    - `doubles`, mocks, spies
    - `docs`, documentation site
    - `ci`, CI/CD, GitHub Actions
    - Use the most specific scope that fits. Omit if changes span many areas.

5. **Write the commit message**:
    - Format: `<type>(<scope>): <description>`
    - Description: imperative mood, lowercase, no period, under 70 chars
    - Focus on **why**, not what
    - Add a body (separated by blank line) only if the why isn't obvious from the description
    - Never mention AI, Claude, or automation in the message

6. **Create the commit**:
    ```bash
    git commit -m "$(cat <<'EOF'
    <type>(<scope>): <description>

    <optional body>
    EOF
    )"
    ```

7. **Verify** the commit was created:
    ```bash
    git log --oneline -1
    ```

## Examples

```
feat(assert): add assert_json_contains function
fix(runner): resolve parallel execution race condition
test(doubles): add spy verification edge cases
refactor(cli): extract option parsing into helper
docs: update installation instructions
chore(ci): upgrade shellcheck to v0.10
perf(runner): reduce subshell usage in test discovery
```

## Rules

- **One logical change per commit**, don't mix unrelated changes
- **Never use `--no-verify`**, if hooks fail, fix the issue
- **Never amend** unless the user explicitly asks
- **Always create a NEW commit**, even after a hook failure
- **Author**: use the git config identity (never commit as sandbox/default user)
