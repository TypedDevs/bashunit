# TDD task file

Use the `tdd-cycle` skill for runtime RED/GREEN/REFACTOR steps. This reference supplies the planning record; repository paths are relative to the root. Do not create runtime tests for prose-only edits.

For features, refactors or multi-test work, create `.tasks/YYYY-MM-DD-slug.md`; skip it for a small fix or a single test. Keep the record current as work progresses.

```markdown
# Feature or fix

Date: YYYY-MM-DD
Status: In Progress

## Acceptance scenario

Given the concrete trigger, the user observes the expected result.

## Non-goals

Work outside this outcome.

## Acceptance criteria

- [ ] Criterion

## Test inventory

- [ ] `test_should_handle_valid_input`
- [ ] `test_should_fail_with_invalid_input`

## Current red bar

Test: none yet
Failure: none yet

## Logbook

### YYYY-MM-DD HH:MM

- Scope, evidence, decision, or test result.
```

Choose the smallest next test, prove its failure is behavioral, implement minimal GREEN, and refactor with affected tests passing. Use existing patterns under `tests/unit/assert/` or the matching module tests; no speculative behavior. Delegates run only assigned targeted checks.

Done means the acceptance scenario works, its criteria are complete, runtime parsing works on Bash 3.0, and public changes have docs and a CHANGELOG entry. Record architectural decisions in an ADR. The main session runs the quality gate in `.agnostic-ai/AGNOSTIC_AI.md` once after the complete change set and before committing.
