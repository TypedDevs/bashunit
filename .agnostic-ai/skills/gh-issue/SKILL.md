---
name: gh-issue
description: Fetch GitHub issue, create branch, plan and implement with TDD, then open PR
user-invocable: true
argument-hint: "<issue-number>"
allowed-tools: shell, read, edit, write, Grep, Glob, Agent, WebFetch
---

# GitHub Issue Workflow

Fetch a GitHub issue, create branch, implement following TDD, and open a PR.

## Arguments
::target claude
- `$ARGUMENTS` - Issue number (e.g., `42` or `#42`)
::end

::target codex
- the argument in the user request - Issue number (e.g., `42` or `#42`)
::end

## Instructions

### Phase 1: Setup

::target claude
1. **Parse the issue number** from `$ARGUMENTS` (strip `#` if present)
::end

::target codex
1. **Parse the issue number** from the argument in the user request (strip `#` if present)
::end

2. **Fetch issue details**:
    ```bash
    gh issue view <number> --json title,body,labels,assignees,milestone,state
    ```

3. **Assign yourself if unassigned**:
    ```bash
    gh issue edit <number> --add-assignee @me
    ```

4. **Add appropriate labels** if the issue doesn't have them:
    - `bug` - Something isn't working
    - `enhancement` - New feature or request
    - `documentation` - Improvements or additions to documentation

5. **Create a branch** from `main`:

    Determine prefix from labels:
    - `bug` → `fix/`
    - `enhancement` → `feat/`
    - `documentation` → `docs/`
    - Default → `feat/`

    Branch name: `<prefix><issue-number>-<slug>` (slug: lowercase title, spaces → `-`, max 50 chars)

    ```bash
    git checkout main && git pull
    git checkout -b <branch-name>
    ```

### Phase 2: Plan

6. **Analyze the issue**: requirements, labels, referenced issues, affected areas

7. **Explore the codebase** for context:
    - Find related code in `src/`
    - Find related tests in `tests/`
    - Study existing patterns

8. **Create implementation plan**:
    - Acceptance Criteria
    - Test Strategy (which tests to write first)
    - Files to Change
    - Implementation Order (smallest first step)

::target claude
9. **Use EnterPlanMode** if implementation is non-trivial
::end

::target codex
9. **Keep a short implementation plan** in the main session if implementation is non-trivial
::end

### Phase 3: Implement

10. **Follow strict TDD workflow** (see `.agnostic-ai/rules/tdd-workflow.md`):

    For each test:
    - **RED** - Write failing test, verify it fails for the RIGHT reason
    - **GREEN** - Minimal code to pass
    - **REFACTOR** - Improve while keeping tests green

11. **Run the full test suite once after the change set is complete**:
    ```bash
    ./bashunit tests/
    ./bashunit --parallel tests/
    ```

12. **Quality checks** before committing:
    ```bash
    make sa && make lint
    ```

### Phase 4: Ship

13. **Final verification**:
    ```bash
    ./bashunit tests/ && ./bashunit --parallel tests/ && make sa && make lint
    ```

14. **Commit** using conventional commits with `Closes #<issue-number>`

15. **Create PR** using the `/pr` skill:
    ```
    /pr #<issue-number>
    ```

## Output Format

After fetching, present:

```
## Issue #<number>: <title>

**Labels:** <labels>
**State:** <state>
**Branch:** <branch-name>

### Description
<body content>

### Next Steps
1. Explore codebase for context
2. Create implementation plan
3. Begin TDD cycle
```
