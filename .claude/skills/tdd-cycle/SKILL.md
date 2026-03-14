---
name: tdd-cycle
description: Run complete TDD red-green-refactor cycle for a test
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
---

# TDD Cycle

Execute a complete Red -> Green -> Refactor cycle.

## Workflow

### 1. Verify Task File

Check for `.tasks/YYYY-MM-DD-*.md`. If missing, create one before proceeding.

### 2. RED — Write Failing Test

1. Show test inventory from task file, ask which test to implement
2. Study patterns from existing tests (unit -> `assert_test.sh`, doubles -> `doubles_test.sh`)
3. Write the failing test following Arrange-Act-Assert
4. Run: `./bashunit path/to/test.sh` — **must fail**
5. Verify failure is for the RIGHT reason (not syntax error or wrong setup)
6. Update task file: current red bar + logbook entry

### 3. GREEN — Make It Pass

1. Write **minimal** code in `src/` — only enough for THIS test
2. Run: `./bashunit path/to/test.sh` — **must pass**
3. Update task file: check off test + logbook entry

### 4. REFACTOR — Improve Code

1. Improve readability, naming, extract duplication — no behavior changes
2. Run tests after each change
3. Quality checks: `make sa && make lint && shfmt -w .`
4. Full suite: `./bashunit tests/`
5. Update task file with refactoring notes

### 5. Next Test

Show updated test inventory. Ask if continuing or done.

## Critical Rules

- **Never skip RED** — always verify test fails first
- **Minimal code in GREEN** — resist feature creep
- **All tests green during REFACTOR** — revert if broken
- **Update task file** after each phase
