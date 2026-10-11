---
name: tdd-cycle
description: Run complete TDD red-green-refactor cycle for a test
allowed-tools: read, edit, write, shell, Grep, Glob
---

# TDD Cycle

Execute a complete Red -> Green -> Refactor cycle. Read [the complete workflow](references/workflow.md) for task-file conventions and the quality gate. Repository paths are relative to the repository root.

## Workflow

### 1. Verify Task File

Use `.tasks/YYYY-MM-DD-slug.md` for features, refactors, or multi-test work. Skip it for small fixes or single-test changes. Choose the next test from the acceptance scenario when no task file is needed.

### 2. RED, Write Failing Test

1. Pick the smallest next test from the task file or acceptance scenario
2. Study patterns from existing tests (unit -> `assert_test.sh`, doubles -> `doubles_test.sh`)
3. Write the failing test following Arrange-Act-Assert
4. Run: `./bashunit path/to/test.sh`, **must fail**
5. Verify failure is for the RIGHT reason (not syntax error or wrong setup)
6. Update the task file, when present: current red bar + logbook entry

### 3. GREEN, Make It Pass

1. Write **minimal** code in `src/`, only enough for THIS test
2. Run: `./bashunit path/to/test.sh`, **must pass**
3. Update the task file, when present: check off test + logbook entry

### 4. REFACTOR, Improve Code

1. Improve readability, naming, extract duplication, no behavior changes
2. Run tests after each change
3. Run `make sa && make lint` and both full test modes once after the change set is complete
4. Update the task file, when present, with refactoring notes

### 5. Next Test

Continue until the acceptance scenario is complete. Update the test inventory when using a task file.

## Critical Rules

- **Never skip RED**, always verify test fails first
- **Minimal code in GREEN**, resist feature creep
- **All tests green during REFACTOR**, revert if broken
- **Update task file**, when present, after each phase
