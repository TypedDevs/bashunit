# Claude Code Quick Reference for bashunit

## 🎯 Custom Skills

| Skill | When to Use | What It Does |
|-------|------------|--------------|
| `/tdd-cycle` | Starting TDD work | Guides RED → GREEN → REFACTOR cycle |
| `/fix-test` | Tests failing | Debug and fix systematically |
| `/add-assertion` | Adding assertions | TDD workflow for new assertions |
| `/check-coverage` | Planning tests | Analyze coverage gaps |
| `/pre-release` | Before release | Comprehensive validation |

## 📚 Key Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Main project instructions |
| `rules/bash-style.md` | Bash 3.0+ compatibility rules |
| `rules/testing.md` | Testing patterns & guidelines |
| `rules/tdd-workflow.md` | TDD methodology details |
| `AGENTS.md` | Comprehensive workflow guide |

## 🔧 Common Commands

```bash
# Testing
./bashunit tests/                    # Run all tests
./bashunit --parallel tests/         # Test parallel safety
./bashunit tests/unit/file_test.sh  # Run specific test

# Quality Checks
make sa                              # ShellCheck static analysis
make lint                            # EditorConfig linting
shfmt -w .                          # Format all shell files

# Combined
make sa && make lint && ./bashunit tests/

# Documentation
npm run docs:dev                     # Start docs dev server
```

## 📝 Task File Template

```markdown
# [Feature/Fix Name]

**Date:** YYYY-MM-DD
**Status:** In Progress

## Context
Brief explanation of what and why

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Test Inventory

### Unit Tests
- [ ] test_should_handle_valid_input
- [ ] test_should_fail_with_invalid_input

### Functional Tests
- [ ] test_should_integrate_correctly

### Acceptance Tests
- [ ] test_should_satisfy_workflow

## Current Red Bar
Test: [test name]
Reason: [why it's failing]

## Logbook

### YYYY-MM-DD HH:MM
- [Timestamped entry]
```

## 🚦 TDD Cycle

```
1. RED    → Write failing test (fail for RIGHT reason)
2. GREEN  → Minimal code to pass
3. REFACTOR → Improve while keeping tests green
4. REPEAT → Until acceptance criteria met
```

## ✅ Definition of Done

Before marking work complete:
- [ ] All tests green for right reason
- [ ] `make sa` passes (shellcheck)
- [ ] `make lint` passes (editorconfig)
- [ ] Task file complete (AC met, logbook done)
- [ ] Docs/CHANGELOG updated if needed
- [ ] ADR created/updated if needed

## 🚫 Critical Rules

**Never:**
- Skip task file requirement
- Use Bash 4+ features (macOS = Bash 3.0)
- Break public API without docs
- Commit without tests passing
- Skip quality checks

**Always:**
- Follow TDD (RED → GREEN → REFACTOR)
- Use patterns from `tests/**` and `src/**`
- Update task file logbook
- Run tests after every change
- Bash 3.0+ compatible code

## 🔍 Bash 3.0+ Compatibility

| ❌ Don't Use (Bash 4+) | ✅ Use Instead (Bash 3.0+) |
|------------------------|----------------------------|
| `declare -A map` | Indexed arrays or workarounds |
| `[[ "$var" == "x" ]]` | `[ "$var" = "x" ]` |
| `${var,,}` | `echo "$var" \| tr '[:upper:]' '[:lower:]'` |
| `${array[-1]}` | `${array[${#array[@]}-1]}` |
| `&>>` | `>> file 2>&1` |

## 🧪 Test Patterns

### Basic Test
```bash
function test_should_return_expected_value() {
    # Arrange
    local input="test"

    # Act
    local result
    result=$(my_function "$input")

    # Assert
    assert_equals "expected" "$result"
}
```

### Test Failure
```bash
function test_should_fail_when_invalid() {
    assert_fails \
        "my_function 'invalid_input'"
}
```

### Mock/Spy
```bash
function test_should_call_helper() {
    spy helper_function

    main_function

    assert_have_been_called helper_function
}
```

### Data Provider
```bash
function data_provider_inputs() {
    echo "input1 output1"
    echo "input2 output2"
}

# @data_provider data_provider_inputs
function test_processes_data() {
    local input="$1"
    local expected="$2"

    local result
    result=$(process "$input")

    assert_equals "$expected" "$result"
}
```

## 📊 Coverage Goals

- **Unit tests:** 90%+ of public functions
- **Functional tests:** Major integration paths
- **Acceptance tests:** All CLI commands
- **Error handling:** All error paths

## 🔒 Git Safety

**Before destructive operations, confirm with user:**
- Force push
- Reset --hard
- Delete branches
- Amend published commits
- Skip hooks (--no-verify)

## 🤖 Automation (Agent SDK)

```python
# .claude/agents/examples/tdd-bot.py
python .claude/agents/examples/tdd-bot.py

# .claude/agents/examples/pr-validator.py
python .claude/agents/examples/pr-validator.py <pr-number>
```

**Requirements:**
```bash
pip install claude-agent-sdk
export ANTHROPIC_API_KEY="your-key"
```

## 📦 Commit Message Format

```
<type>(<scope>): <description>

```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

**Examples:**
```
feat(assert): add assert_json_contains function
fix(runner): resolve parallel execution race condition
docs(readme): update installation instructions
```

## 🆘 Quick Fixes

**Tests failing:**
```bash
/fix-test
```

**Coverage gaps:**
```bash
/check-coverage
```

**Before release:**
```bash
/pre-release
```

**TDD cycle:**
```bash
/tdd-cycle
```

## 📖 Reference Documentation

- **Getting started:** `.claude/GETTING_STARTED.md`
- **Full docs:** `.claude/README.md`
- **Project instructions:** `.claude/CLAUDE.md`
- **Agent automation:** `.claude/agents/README.md`
- **TDD workflow:** `AGENTS.md`
- **Contributing:** `.github/CONTRIBUTING.md`

## 🔗 External Links

- [Claude Code Docs](https://code.claude.com/docs)
- [bashunit Docs](https://bashunit.typeddevs.com)
- [Agent SDK](https://platform.claude.com/docs/agent-sdk)
- [Bash Style Guide](https://google.github.io/styleguide/shellguide.html)

---

**Print this for your desk!** Keep it handy while developing bashunit.
