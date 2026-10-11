---
name: add-assertion
description: Add new assertion function with comprehensive tests following TDD
allowed-tools: read, edit, write, shell, Grep, Glob
---

# Add an assertion

Repository paths are relative to the repository root. Establish the assertion name, arguments, success and failure behavior, and messages from the request and sibling assertions; ask only for missing decisions. Record acceptance criteria and test inventory in `.tasks/YYYY-MM-DD-add-assertion-name.md` for nontrivial work.

1. Study the matching implementation under `src/assert/` and tests under `tests/unit/assert/`, including parameter validation, return codes, and message checks. `src/assert/index.sh` lists assertion modules.
2. Use focused RED, minimal GREEN, then REFACTOR for basic success, expected failure, and relevant edge cases (empty values, special characters, malformed input). Use `assert_assertion_passes`, `assert_assertion_fails`, or `assert_assertion_fails_with` from `src/assert/assertions.sh` where appropriate. Match existing output comparisons when needed; there is no `assert_fails`.
3. If adding a module, source it from `src/assert/index.sh`. Expose the public function through the existing module-loading pattern. Preserve Bash 3.0 parse compatibility and the existing public contract.
4. Document the public assertion's arguments, returns, and example in user-facing docs, update CHANGELOG, and complete the task file when used. Add code comments only for a constraint the code cannot express.
5. The main session runs the canonical quality gate once after the entire change set; delegates run only assigned focused checks. Verify success, failure, edge cases, module loading, and documentation before handing off.
