# GitHub Issue Workflow

Fetch a GitHub issue, create task file and branch, implement it following TDD, and open a PR.

## Arguments
- `$ARGUMENTS` - Issue number (e.g., `42` or `#42`)

## Instructions

### Phase 1: Setup

1. **Parse the issue number** from `$ARGUMENTS` (strip `#` if present)

2. **Fetch issue details** using GitHub CLI:
    ```bash
    gh issue view <number> --json title,body,labels,assignees,milestone,state
    ```

3. **Assign yourself if unassigned**:
    ```bash
    gh issue edit <number> --add-assignee @me
    ```

4. **Add appropriate labels** based on issue scope:
    ```bash
    gh issue edit <number> --add-label "<label>"
    ```

    **Available labels (common):**
    - `bug` - Something isn't working
    - `enhancement` - New feature or request
    - `documentation` - Improvements or additions to documentation
    - `good first issue` - Good for newcomers
    - `help wanted` - Extra attention is needed

    **Note:** Only add labels if the issue doesn't already have appropriate ones.

5. **Create a branch** from `main` based on the issue type:

    Determine the branch prefix from labels:
    - `bug` → `fix/`
    - `enhancement` → `feat/`
    - `documentation` → `docs/`
    - No label or other → `feat/` (default)

    Branch name format: `<prefix><issue-number>-<slug>`
    - Slug: lowercase issue title, spaces replaced with `-`, stripped of special characters, max 50 chars

    ```bash
    git checkout main && git pull
    git checkout -b <branch-name>
    ```

    **Example:** Issue #42 "Add JSON assertion" with `enhancement` label → `feat/42-add-json-assertion`

6. **Optional: Create task file** (recommended for complex work):

    For complex issues, you may want to create a task file to track progress:

    ```bash
    # Optional - only for complex issues
    touch .tasks/YYYY-MM-DD-<issue-number>-<slug>.md
    ```

    See existing examples in `.tasks/` for template format.

### Phase 2: Plan

7. **Read project context**:
    - @.claude/CLAUDE.md - Primary project instructions
    - @.claude/rules/bash-style.md - Bash 3.2+ compatibility
    - @.claude/rules/testing.md - Testing patterns
    - @AGENTS.md - Additional TDD guidelines

8. **Analyze the issue**:
    - Understand the requirements from title and body
    - Note any labels (bug, feature, enhancement, etc.)
    - Check if it references other issues or PRs
    - Identify affected areas (assertions, runner, CLI, docs)

9. **Explore the codebase** to understand context:
    ```bash
    # Find related code
    grep -r "similar_function" src/

    # Find related tests
    find tests/ -name "*related*_test.sh"

    # Check existing patterns
    # Study: tests/unit/assert_test.sh (for assertions)
    # Study: tests/functional/doubles_test.sh (for mocks/spies)
    # Study: tests/acceptance/bashunit_test.sh (for CLI)
    ```

10. **Create implementation plan**:

    Determine:
    - **Acceptance Criteria** - What defines success?
    - **Test Strategy** - Which tests to write first?
    - **Files to Change** - Which files will be modified/created?
    - **Implementation Order** - What's the smallest first step?

    **Example plan:**
    ```markdown
    ## Implementation Plan

    ### Tests Needed (TDD approach)
    1. test_assert_json_contains_should_pass_when_key_value_exists
    2. test_assert_json_contains_should_fail_when_key_missing
    3. test_assert_json_contains_should_fail_when_value_differs
    4. test_assert_json_contains_should_handle_nested_keys
    5. test_assert_json_contains_should_fail_on_malformed_json

    ### Files to Modify/Create
    - Create: tests/unit/assert_json_test.sh
    - Create: src/assert_json.sh
    - Modify: src/bashunit.sh (export function)
    - Update: CHANGELOG.md, docs/

    ### Strategy
    1. Study existing patterns in tests/unit/assert_test.sh
    2. Start with simplest test (#1)
    3. Implement following RED → GREEN → REFACTOR
    4. Ensure Bash 3.2+ compatible throughout
    ```

    **Optional:** Create `.tasks/YYYY-MM-DD-<issue>-<slug>.md` for complex work to track detailed progress.

11. **Use EnterPlanMode** if implementation is non-trivial:
    - For complex features or architectural decisions
    - To explore multiple approaches
    - When multiple files will be affected

### Phase 3: Implement

12. **After plan is ready**, follow strict TDD workflow:

    **For each test in the inventory:**

    a. **RED - Write failing test**
    ```bash
    # Write the test
    # Run it: ./bashunit tests/unit/your_test.sh
    # Verify it fails for the RIGHT reason
    # Update task file with current red bar
    ```

    b. **GREEN - Minimal implementation**
    ```bash
    # Write minimal code to pass
    # Run test again: ./bashunit tests/unit/your_test.sh
    # Verify it passes
    ```

    c. **REFACTOR - Improve code**
    ```bash
    # Improve while keeping tests green
    # Run tests after each change
    # Run quality checks
    ```

    **Critical rules:**
    - ✅ Write tests BEFORE implementation
    - ✅ Minimal code in GREEN phase
    - ✅ Keep tests passing during REFACTOR
    - ✅ Follow Bash 3.2+ compatibility (@.claude/rules/bash-style.md)

13. **Run full test suite** frequently:
    ```bash
    # Run all tests
    ./bashunit tests/

    # Test parallel execution (verify no race conditions)
    ./bashunit --parallel tests/
    ```

    **Never proceed with failing tests.** Fix immediately.

14. **Quality checks** (run after each refactor):
    ```bash
    # ShellCheck static analysis
    make sa

    # EditorConfig linting
    make lint

    # Format all shell files
    shfmt -w .
    ```

    All must pass before committing.

15. **Update documentation** if user-facing changes:
    - `README.md` - Update examples if API changed
    - `docs/` - Add/update documentation pages
    - **Always update:** `CHANGELOG.md` - Add entry under today's date

    **CHANGELOG format:**
    ```markdown
    ## [Unreleased]

    ### Added (for new features)
    - Description of what was added #<issue-number>

    ### Changed (for changes in existing functionality)
    - Description of what changed #<issue-number>

    ### Fixed (for bug fixes)
    - Description of what was fixed #<issue-number>
    ```

### Phase 4: Ship

16. **Final verification checklist**:
    ```bash
    # All tests pass
    ./bashunit tests/

    # Parallel tests work
    ./bashunit --parallel tests/

    # Quality checks
    make sa && make lint

    # Format verified
    shfmt -l . | wc -l  # Should be 0
    ```

17. **Commit changes** using conventional commits:
    ```bash
    git add <specific-files>
    git commit -m "$(cat <<'EOF'
    <type>(<scope>): <description>

    <optional body>

    Closes #<issue-number>
    EOF
    )"
    ```

    **Commit guidelines:**
    - **Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
    - **Scope:** `assert`, `runner`, `cli`, `docs`, etc.
    - Use `Closes #X` to auto-close the issue on merge
    - **Never mention AI/Claude** in commit messages
    - Prefer atomic commits (one logical change)

    **Examples:**
    ```
    feat(assert): add assert_json_contains function

    Adds new assertion to validate JSON key-value pairs.
    Supports nested keys and provides clear error messages.

    Closes #42
    ```

    ```
    fix(runner): resolve parallel execution race condition

    Fixed race condition when multiple tests write to temp files
    with same name pattern.

    Closes #123
    ```

18. **Push branch**:
    ```bash
    git push -u origin <branch-name>
    ```

19. **Create PR** using GitHub CLI:
    ```bash
    gh pr create --title "<type>(<scope>): <description>" \
      --body "$(cat <<'EOF'
    ## Summary

    <Brief description of changes>

    ## Changes

    - Change 1
    - Change 2
    - Change 3

    ## Testing

    - [ ] Unit tests added/updated
    - [ ] Functional tests added/updated (if applicable)
    - [ ] Acceptance tests added/updated (if applicable)
    - [ ] All tests passing: `./bashunit tests/`
    - [ ] Parallel tests passing: `./bashunit --parallel tests/`
    - [ ] ShellCheck clean: `make sa`
    - [ ] Linting clean: `make lint`

    ## Documentation

    - [ ] CHANGELOG.md updated
    - [ ] README.md updated (if API changed)
    - [ ] Function documentation added
    - [ ] Examples added/updated

    ## Checklist

    - [ ] Follows TDD workflow (tests written first)
    - [ ] Bash 3.2+ compatible
    - [ ] Task file complete: `.tasks/YYYY-MM-DD-<issue>-<slug>.md`
    - [ ] Two-way sync checked (AGENTS.md ↔ .github/copilot-instructions.md)
    - [ ] Breaking changes documented (if any)

    Closes #<issue-number>

    🤖 Generated with [Claude Code](https://claude.com/claude-code)
    EOF
    )" \
      --base main
    ```

    Or use the existing `/pr` command if available.

20. **Post-PR tasks**:
    - Review the PR yourself first
    - Ensure CI passes
    - Respond to any review comments
    - Merge when approved (or wait for maintainers)

## Example Usage

```
/gh-issue 42
/gh-issue #123
```

## Output Format

After fetching, present the issue like this:

```
## Issue #<number>: <title>

**Labels:** <labels>
**State:** <state>
**Branch:** <branch-name>

### Description
<body content>

### Next Steps
1. Review issue requirements
2. Explore codebase for context
3. Create implementation plan in task file
4. Begin TDD cycle

Would you like me to:
- [ ] Explore the codebase for similar functionality?
- [ ] Create detailed implementation plan?
- [ ] Start with first test?
```

## Checklist

- [ ] Issue fetched and understood
- [ ] Self-assigned if unassigned
- [ ] Appropriate labels added
- [ ] Branch created from main (`<type>/<number>-<slug>`)
- [ ] Codebase explored for context
- [ ] Implementation plan created
- [ ] Test strategy defined
- [ ] TDD cycle followed (RED → GREEN → REFACTOR)
- [ ] All tests passing (`./bashunit tests/`)
- [ ] Parallel tests passing (`./bashunit --parallel tests/`)
- [ ] Quality checks passing (`make sa && make lint`)
- [ ] Code formatted (`shfmt -w .`)
- [ ] Bash 3.2+ compatible
- [ ] CHANGELOG.md updated
- [ ] Documentation updated (if needed)
- [ ] Commit created with conventional format
- [ ] Branch pushed
- [ ] PR created with proper description
- [ ] Issue closes on merge (`Closes #X` in PR/commit)

## Important Notes

### Bash 3.2+ Compatibility

**Critical:** bashunit must work on macOS default Bash 3.2. Check @.claude/rules/bash-style.md

**Forbidden features:**
- ❌ `declare -A` (associative arrays)
- ❌ `[[ ]]` (use `[ ]` instead)
- ❌ `${var,,}` (case conversion)
- ❌ `${array[-1]}` (negative indexing)
- ❌ `&>>` redirect

### TDD Workflow

**Mandatory:** Follow @.claude/rules/tdd-workflow.md and @AGENTS.md

1. **RED** - Test fails for right reason
2. **GREEN** - Minimal implementation
3. **REFACTOR** - Improve while tests stay green

**Never skip RED phase.** Always verify test fails first.

### Task Files (Optional)

**Recommended** for complex work. See `.tasks/` for examples.

- Useful for tracking multi-test implementations
- Helps document test inventory and progress
- Not required for simple fixes

### Quality Standards

All code must:
- ✅ Pass `make sa` (ShellCheck)
- ✅ Pass `make lint` (EditorConfig)
- ✅ Be formatted (`shfmt -w .`)
- ✅ Have tests (90%+ coverage)
- ✅ Follow existing patterns
- ✅ Work in Bash 3.2+

### Configuration Sync

When changing workflow/instructions, keep these aligned:
- `.claude/CLAUDE.md` (primary)
- `AGENTS.md` (GitHub Copilot)
- `.github/copilot-instructions.md` (detailed)

## Troubleshooting

**Issue not found:**
```bash
# Verify issue exists
gh issue view <number>

# Check you're in the right repo
gh repo view
```

**Branch already exists:**
```bash
# Delete local branch
git branch -D <branch-name>

# Delete remote branch
git push origin --delete <branch-name>
```

**Tests failing:**
```bash
# Use fix-test skill
/fix-test

# Or debug manually
./bashunit tests/unit/specific_test.sh
```

**Quality checks failing:**
```bash
# Fix shellcheck issues
make sa

# Fix lint issues
make lint

# Format all files
shfmt -w .
```

## Skills to Use

During implementation, leverage these skills:

- `/tdd-cycle` - Complete TDD workflow
- `/fix-test` - Debug failing tests
- `/check-coverage` - Verify test coverage
- `/pre-release` - Final validation (before creating PR)

## Related Files

- TDD workflow: @.claude/rules/tdd-workflow.md
- Testing patterns: @.claude/rules/testing.md
- Bash style: @.claude/rules/bash-style.md
- Full instructions: @AGENTS.md
- Contributing: @.github/CONTRIBUTING.md
