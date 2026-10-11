---
name: tdd-cycle
description: Run complete TDD red-green-refactor cycle for a test
allowed-tools: read, edit, write, shell, Grep, Glob
---

# TDD cycle

Read [the complete workflow](references/workflow.md) for task-file conventions. Repository paths are relative to the repository root. The canonical quality gate and coordinator responsibilities in `.agnostic-ai/AGNOSTIC_AI.md` apply.

Use `.tasks/YYYY-MM-DD-slug.md` for features, refactors, or multi-test work; skip it for small fixes or a single test. Choose the next smallest test from the acceptance scenario or task inventory and study matching existing tests.

1. **RED:** Write Arrange-Act-Assert, run `./bashunit <test-path>`, and verify failure proves the requested behavior is missing, rather than a syntax or setup error. Record the red bar and logbook entry when using a task file.
2. **GREEN:** Implement only what this test requires. Run the focused test and require a pass. Check off the inventory entry and record the result.
3. **REFACTOR:** Improve naming, structure, or duplication without changing behavior. Keep affected focused tests green; preserve other workers' changes. Record meaningful refactoring notes.
4. Repeat until the acceptance scenario is complete. The main session runs the full quality gate once after the whole change set, before committing. Delegates run only assigned targeted checks.

Never skip the demonstrated RED or add speculative behavior during GREEN. Keep the task inventory and logbook current when a task file is used.
