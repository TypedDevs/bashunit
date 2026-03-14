---
paths:
  - "**/*.sh"
  - ".tasks/**/*.md"
---

# TDD Workflow

**Test-Driven Development is mandatory** for all bashunit development.

## The Cycle

```
RED    -> Write a failing test (must fail for the RIGHT reason)
GREEN  -> Write minimal code to make it pass (nothing extra)
REFACTOR -> Improve code while keeping all tests green
REPEAT -> Until acceptance criteria are met
```

## Task File (Recommended for non-trivial changes)

For features, refactors, or multi-test work, create `.tasks/YYYY-MM-DD-slug.md`.
Skip for small bug fixes or single-test changes.

```markdown
# [Feature/Fix Name]

**Date:** YYYY-MM-DD  **Status:** In Progress

## Acceptance Criteria
- [ ] Criterion 1

## Test Inventory
- [ ] `test_should_handle_valid_input`
- [ ] `test_should_fail_with_invalid_input`

## Current Red Bar
Test: (none yet)

## Logbook
### YYYY-MM-DD HH:MM
- Created task, analyzed existing code
```

## RED Phase

1. Pick the **smallest next test** from inventory
2. Study patterns from existing tests (unit -> `assert_test.sh`, doubles -> `doubles_test.sh`)
3. Write test following Arrange-Act-Assert
4. Run: `./bashunit path/to/test.sh` — **must fail**
5. Verify failure reason: function missing or wrong output (**not** syntax error)

## GREEN Phase

1. Write **minimal** code to pass — no extra features, no premature optimization
2. Run: `./bashunit path/to/test.sh` — **must pass**

## REFACTOR Phase

1. Improve readability, naming, extract duplication — **no behavior changes**
2. Run tests after each change
3. Run quality checks: `make sa && make lint && shfmt -w .`

## Quality Gate (Before Commit)

```bash
./bashunit tests/               # All tests
./bashunit --parallel tests/    # Parallel (isolation check)
make sa && make lint            # Static analysis + linting
shfmt -w .                      # Formatting
```

## Definition of Done

- All tests green for the **right reason**
- All acceptance criteria met
- Quality gate passes
- Bash 3.0+ compatible
- CHANGELOG updated (if user-facing)
- ADR created (if architectural decision)
