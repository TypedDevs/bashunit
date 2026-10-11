---
name: fix-test
description: Debug and fix failing tests systematically
allowed-tools: read, edit, shell, Grep, Glob
---

# Fix a failing test

Repository paths are relative to the repository root. Start with reported output and the failing file; use `./bashunit --filter "test_name" <test-file>` to reproduce narrowly. Discover with the full suite only when no narrower failure is known.

1. Trace the failure to its source and classify it: incorrect expectation/setup, implementation defect, environment/fixture issue, parallel race, or flaky external dependency. Check fixtures under `tests/fixtures/` and mocks with `assert_have_been_called <name>` where relevant. Temporary diagnostics go to stderr and must be removed.
2. Preserve a failing regression for the actual defect. Correct an expectation only when the intended behavior proves it wrong; otherwise make the smallest implementation fix with TDD. Repair fixtures or setup for environment defects, use the existing `$temp_dir` isolation and wait for asynchronous work for races, and mock external dependencies for flaky tests.
3. Run the focused test until it passes for the right reason. Reproduce relevant parallel behavior when investigating isolation. If the failure may predate the change, verify the same focused test on unchanged main in an isolated checkout.
4. Add a relevant edge case if it protects the root cause. After the complete change set, the coordinator runs the canonical quality gate once; delegates run only assigned targeted checks.

Report the cause, fix, focused evidence, and any specific remaining environment limit.
