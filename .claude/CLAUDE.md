# bashunit - Bash Testing Framework

## Project Overview

**bashunit** is a comprehensive, lightweight Bash testing framework (requires Bash 3.0+) focused on developer experience. It provides assertions, test doubles (spies/mocks), data providers, snapshots, and more.

**Documentation:** https://bashunit.typeddevs.com

## Claude Code Configuration

This directory (`.claude/`) contains comprehensive Claude Code configuration:
- **Custom skills**: `/tdd-cycle`, `/fix-test`, `/add-assertion`, `/check-coverage`, `/pre-release`
- **Custom commands**: `/gh-issue` (complete GitHub issue → PR workflow)
- **Modular rules**: Bash 3.0+ compatibility, testing patterns, TDD workflow
- **Automation**: Agent SDK examples for CI/CD

See `README.md` in this directory for complete documentation.

## Core Principles

### TDD by Default
**RED → GREEN → REFACTOR**

1. **RED** - Write failing test (fail for the RIGHT reason)
2. **GREEN** - Minimal code to make it pass
3. **REFACTOR** - Improve while keeping tests green

Every change starts from a failing test. No exceptions.

### Bash 3.0+ Compatible

Works on macOS default bash. **Prohibited features:**
- ❌ `declare -A` (associative arrays - Bash 4.0+)
- ❌ `[[ ]]` (use `[ ]` instead)
- ❌ `${var,,}` (case conversion - Bash 4.0+)
- ❌ `${array[-1]}` (negative indexing - Bash 4.3+)
- ❌ `&>>` redirect (Bash 4.0+)

See `@.claude/rules/bash-style.md` for complete compatibility guide.

### Quality Standards

Every change must pass:
```bash
make sa          # ShellCheck static analysis
make lint        # EditorConfig linting
./bashunit tests/  # All tests passing
shfmt -w .       # Code formatting
```

## Architecture

```
bashunit/
├── src/                    # Core framework code (Bash 3.0+ compatible)
│   ├── bashunit.sh        # Main entry point
│   ├── assertions.sh      # Assertion functions
│   ├── assert_*.sh        # Specialized assertions
│   └── *.sh               # Utilities (io, math, etc.)
├── tests/
│   ├── unit/              # Unit tests for src/ (isolated, with mocks)
│   ├── functional/        # Integration tests
│   └── acceptance/        # End-to-end CLI tests
├── .claude/               # Claude Code configuration
│   ├── CLAUDE.md         # This file (primary instructions)
│   ├── skills/           # Custom workflows
│   ├── commands/         # End-to-end commands
│   └── rules/            # Modular guidelines
├── .tasks/               # Optional task tracking files
├── adrs/                 # Architecture Decision Records
└── bashunit             # CLI entry point
```

## Common Commands

```bash
# Testing
./bashunit tests/              # Run all tests
./bashunit --parallel tests/   # Parallel execution
./bashunit tests/unit/         # Run unit tests only
make test                      # Run full test suite

# Quality checks
make sa                        # ShellCheck static analysis
make lint                      # EditorConfig checker
shfmt -w .                     # Format all shell files

# Documentation
npm run docs:dev               # Start docs dev server
npm run docs:build             # Build documentation

# Releases
./release.sh                   # Release new version
```

## Test Patterns

Study existing tests before writing new ones:

- **Assertions**: `tests/unit/assert_test.sh` - Assertion patterns and failure testing
- **Test Doubles**: `tests/functional/doubles_test.sh` - `mock`/`spy` + `assert_have_been_called*`
- **Data Providers**: `tests/functional/provider_test.sh` - `@data_provider` syntax
- **Lifecycle Hooks**: `tests/unit/setup_teardown_test.sh` - `set_up_before_script`, etc.
- **CLI Testing**: `tests/acceptance/bashunit_test.sh` - Snapshot testing

## Available Skills

Invoke with `/skill-name`:

### `/tdd-cycle` - Complete TDD Workflow
Guides through RED → GREEN → REFACTOR cycle with quality checks.
```
/tdd-cycle
```

### `/fix-test` - Debug Failing Tests
Systematically debugs and fixes test failures.
```
/fix-test
```

### `/add-assertion` - Add New Assertion
Adds new assertion following TDD with comprehensive tests.
```
/add-assertion
```

### `/check-coverage` - Analyze Coverage
Analyzes test coverage and identifies gaps.
```
/check-coverage
```

### `/pre-release` - Release Validation
Comprehensive validation before releasing.
```
/pre-release
```

## Expert Agents

Specialized agents you can consult using the Task tool:

### Bash 3.0+ Expert
**When to use:** Reviewing code for Bash 3.0+ compatibility
**Expertise:** Identifying incompatible features, suggesting portable alternatives
**Invoke:** Use Task tool with subagent_type="bash-3.0-expert"

### Code Reviewer
**When to use:** Before committing, for comprehensive code review
**Expertise:** Project standards, quality, security, documentation
**Invoke:** Use Task tool with subagent_type="code-reviewer"

### TDD Coach
**When to use:** Learning TDD, guidance through RED-GREEN-REFACTOR
**Expertise:** TDD methodology, test design, avoiding common mistakes
**Invoke:** Use Task tool with subagent_type="tdd-coach"

### Test Architect
**When to use:** Planning test strategy, organizing tests
**Expertise:** Test categorization, coverage planning, testing patterns
**Invoke:** Use Task tool with subagent_type="test-architect"

### Performance Optimizer
**When to use:** Optimizing slow code, improving test suite performance
**Expertise:** Bash performance patterns, benchmarking, profiling
**Invoke:** Use Task tool with subagent_type="performance-optimizer"

## Available Commands

### `/gh-issue` - GitHub Issue Workflow
Complete end-to-end workflow from issue to PR:
1. Fetches issue from GitHub
2. Creates branch with proper naming
3. Plans implementation
4. Implements following TDD
5. Runs quality checks
6. Creates commit and PR

```
/gh-issue 42
```

## Code Standards

### Bash Style
@.claude/rules/bash-style.md
- Bash 3.0+ compatibility (critical!)
- ShellCheck compliance
- Function documentation
- Naming conventions

### Testing
@.claude/rules/testing.md
- Test organization (unit/functional/acceptance)
- Assertion patterns
- Test doubles (mocks/spies)
- Data providers
- Anti-patterns to avoid

### TDD Workflow
@.claude/rules/tdd-workflow.md
- RED → GREEN → REFACTOR cycle
- Quality gates
- Definition of Done

## Path-Scoped Guidelines

### `src/**/*.sh`
- Small, portable functions
- Bash 3.0+ compatibility (no associative arrays, no `[[`, no `${var,,}`)
- Proper namespacing (`bashunit::*`)
- No external dependencies in core
- Function documentation required

### `tests/**/*_test.sh`
- Behavior-focused tests
- Use official assertions/doubles only
- Avoid network calls
- Use `temp_file`/`temp_dir` for isolation
- Test both success and failure paths

### `.tasks/YYYY-MM-DD-slug.md` (Optional)
- Use for complex work to track progress
- Include test inventory
- Timestamped logbook entries
- Not required for simple fixes

### `adrs/*.md`
- Read existing ADRs before major changes
- Use template for new decisions
- Match existing format

## Guardrails

### Never:
- Invent commands/features not in the codebase
- Break Bash 3.0+ compatibility
- Skip tests or quality checks
- Change public API without docs/CHANGELOG
- Use speculative/unproven patterns
- Commit without tests passing
- Batch unrelated changes in one PR

### Always:
- Write tests before implementation
- Use existing patterns from `tests/**` and `src/**`
- Minimal code in GREEN phase
- Keep tests passing during REFACTOR
- Run quality checks before committing
- Update CHANGELOG.md for user-visible changes
- Maintain Bash 3.0+ compatibility

## Definition of Done

Before marking work complete:
- ✅ All tests green for the **right reason**
- ✅ `make sa` passes (ShellCheck)
- ✅ `make lint` passes (EditorConfig)
- ✅ Code formatted (`shfmt -w .`)
- ✅ Bash 3.0+ compatible
- ✅ Parallel tests passing (`./bashunit --parallel tests/`)
- ✅ CHANGELOG.md updated (if user-facing changes)
- ✅ Documentation updated (if needed)
- ✅ ADR created/updated (if architectural decision)

## Task Files (Optional)

For complex work, consider creating `.tasks/YYYY-MM-DD-slug.md` to track:
- Test inventory (which tests to write)
- Progress logbook (timestamped entries)
- Acceptance criteria

Not required for simple fixes. See `.tasks/` for examples.

## Prohibited Actions

**Never do these without explicit user request:**
- Commit secrets or sensitive data
- Force push to main/master
- Skip git hooks (--no-verify)
- Amend published commits
- Use destructive git commands (reset --hard, clean -f)
- Delete branches
- Push to remote without confirmation

## ADRs (Architecture Decision Records)

Read existing ADRs in `adrs/` before making architectural changes. Create new ADRs for significant decisions using the repo's template.

## Commit Message Format

Use [Conventional Commits](https://conventionalcommits.org/):

```
<type>(<scope>): <description>

<optional body>
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

**Scopes:** `assert`, `runner`, `cli`, `docs`, etc.

**Examples:**
```
feat(assert): add assert_json_contains function

Adds new assertion to validate JSON key-value pairs.
Supports nested keys and provides clear error messages.
```

```
fix(runner): resolve parallel execution race condition

Fixed race condition when multiple tests write to temp files.
```

## Help & Resources

### Documentation
- **Getting started:** @.claude/GETTING_STARTED.md (5-minute intro)
- **Quick reference:** @.claude/QUICK_REFERENCE.md (one-page cheat sheet)
- **Full docs:** https://bashunit.typeddevs.com
- **Contributing:** @.github/CONTRIBUTING.md

### Claude Code
- **This directory:** @.claude/README.md (comprehensive guide)
- **Skills:** See `.claude/skills/` directory
- **Commands:** See `.claude/commands/` directory
- **Automation:** See `.claude/agents/` directory

### Community
- **Issues:** https://github.com/TypedDevs/bashunit/issues
- **Discussions:** https://github.com/TypedDevs/bashunit/discussions

---

**Need help?** Start with `@.claude/GETTING_STARTED.md` for a quick introduction to the Claude Code configuration.
