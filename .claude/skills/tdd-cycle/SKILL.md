---
name: tdd-cycle
description: Run complete TDD red-green-refactor cycle for a test
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
---

# TDD Cycle Skill

Execute a complete Test-Driven Development cycle: Red → Green → Refactor.

## When to Use

Invoke with `/tdd-cycle` when:
- Starting work on a new test from the inventory
- Need to follow the complete TDD workflow
- Want guided step-by-step TDD process

## Workflow

### 1. Verify Task File Exists

**Check for** `.tasks/YYYY-MM-DD-*.md` file:
- If missing: **ERROR** - Task file is mandatory
- If exists: Read it to understand context

### 2. RED Phase - Write Failing Test

1. **Ask user** which test to implement (show test inventory from task file)
2. **Study patterns** from existing tests:
    - Unit test → Read `tests/unit/assert_test.sh`
    - Mock/spy → Read `tests/functional/doubles_test.sh`
    - CLI test → Read `tests/acceptance/bashunit_test.sh`
3. **Write the failing test** following discovered patterns
4. **Run the test:**
    ```bash
    ./bashunit path/to/test_file.sh
    ```
5. **Verify it fails for the RIGHT reason:**
    - Function not found (if new)
    - Wrong output (if modifying)
    - NOT syntax error or wrong setup
6. **Update task file** with:
    - Current red bar (which test, why it fails)
    - Logbook entry with timestamp

### 3. GREEN Phase - Make It Pass

1. **Identify where to add code** (in `src/` directory)
2. **Write minimal implementation** to make test pass
    - Only enough for THIS test
    - No extra features
    - No premature optimization
3. **Run the test again:**
    ```bash
    ./bashunit path/to/test_file.sh
    ```
4. **Verify it passes**
5. **Update task file:**
    - Clear red bar (none now)
    - Check off test in inventory
    - Add logbook entry

### 4. REFACTOR Phase - Improve Code

1. **Improve code quality** while keeping tests green:
    - Better naming
    - Extract functions
    - Add documentation
    - Remove duplication
2. **Run tests after each change:**
    ```bash
    ./bashunit path/to/test_file.sh
    ```
3. **Run quality checks:**
    ```bash
    make sa && make lint
    shfmt -w .
    ```
4. **Run full test suite:**
    ```bash
    ./bashunit tests/
    ```
5. **Update task file** with refactoring notes

### 5. Ready for Next

1. **Show test inventory** with current progress
2. **Ask if continuing** to next test or done for now

## Critical Rules

- **Never skip RED phase** - Always verify test fails first
- **Never skip task file** - Must exist before starting
- **Minimal code only in GREEN** - Resist feature creep
- **All tests green during REFACTOR** - Revert if broken
- **Update task file** after each phase

## Output Format

After each phase, clearly indicate:
```
✅ RED: Test written and failing for correct reason
✅ GREEN: Test now passing with minimal code
✅ REFACTOR: Code improved, all tests still green
```

## Example Invocation

User: `/tdd-cycle`

Response:
1. Verify task file exists
2. Show test inventory
3. Ask which test to implement
4. Execute RED → GREEN → REFACTOR
5. Update task file throughout
6. Show final status

## Error Handling

- **No task file?** → Error: "Task file required. Create `.tasks/YYYY-MM-DD-slug.md` first"
- **Test doesn't fail?** → Error: "Test must fail in RED phase. Verify test is correct"
- **Test fails after refactor?** → Revert changes, notify user
- **Quality checks fail?** → Fix issues before marking phase complete

## Related Files

- Workflow details: @.claude/rules/tdd-workflow.md
- Testing patterns: @.claude/rules/testing.md
- Full instructions: @AGENTS.md
