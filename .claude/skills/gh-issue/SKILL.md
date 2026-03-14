---
name: gh-issue
description: Fetch GitHub issue, create branch, plan and implement with TDD, then open PR
user-invocable: true
argument-hint: "<issue-number>"
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, WebFetch
---

# GitHub Issue Workflow

Fetch a GitHub issue, create branch, implement following TDD, and open a PR.

## Arguments
- `$ARGUMENTS` - Issue number (e.g., `42` or `#42`)

## Instructions

### Phase 1: Setup

1. **Parse the issue number** from `$ARGUMENTS` (strip `#` if present)

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

9. **Use EnterPlanMode** if implementation is non-trivial

### Phase 3: Implement

10. **Follow strict TDD workflow** (see @.claude/rules/tdd-workflow.md):

    For each test:
    - **RED** - Write failing test, verify it fails for the RIGHT reason
    - **GREEN** - Minimal code to pass
    - **REFACTOR** - Improve while keeping tests green

11. **Run full test suite frequently**:
    ```bash
    ./bashunit tests/
    ./bashunit --parallel tests/
    ```

12. **Quality checks** after each refactor:
    ```bash
    make sa && make lint && shfmt -w .
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
