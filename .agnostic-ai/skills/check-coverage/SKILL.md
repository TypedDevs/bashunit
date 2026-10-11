---
name: check-coverage
description: Analyze test coverage and identify untested code paths
allowed-tools: read, shell, Grep, Glob
---

# Check coverage

Repository paths are relative to the repository root. Measure the requested scope with `./bashunit --coverage <test-path>`. For broad coverage, follow `.github/workflows/coverage.yml`: exclude `tests/unit/coverage/` meta-tests and fixtures, then measure the selected unit tests with `--coverage-paths src`. Running coverage meta-tests under coverage double-instruments the engine and corrupts their assertions. Keep analysis separate from any later implementation gate.

1. Map functions under `src/` to direct tests and observed coverage. Search definitions with `rg '^function ' src/` and usages of each relevant name under `tests/`. Public assertions may lack the `bashunit::` prefix; inspect the public assertion and API surfaces and their loaded module entrypoints. A text match alone does not prove a test executes a function.
2. Classify each relevant function as well tested, partially tested, or untested using success, edge, and failure-path evidence. State instrumentation limits, including shell-version differences, before treating an uncovered line as a missing test.
3. Prioritize public APIs without tests, error paths, then complex conditionals. Aim for 90%+ public API coverage and tests for user-facing commands and error paths; trivial internal helpers are lower priority.
4. Report measured totals and coverage by module, gaps with file and line evidence, and specific proposed test cases. Separate measured percentages from estimates. Do not change production code or tests unless the request includes implementation.
