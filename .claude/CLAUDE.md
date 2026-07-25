# bashunit - Bash Testing Framework

## Project Overview

**bashunit** is a lightweight Bash testing framework (Bash 3.2+) focused on developer experience. Provides assertions, test doubles (spies/mocks), data providers, snapshots, and more.

**Documentation:** https://bashunit.com

## Core Principles

### TDD by Default
**RED → GREEN → REFACTOR** — every change starts from a failing test. No exceptions.

### Bash 3.2+ Compatible

Works on macOS default bash. **Prohibited features:**
- `declare -A` (associative arrays - Bash 4.0+)
- `[[ ]]` (use `[ ]` instead)
- `${var,,}` (case conversion - Bash 4.0+)
- `${array[-1]}` (negative indexing - Bash 4.3+)
- `&>>` redirect (Bash 4.0+)

See `.claude/rules/bash-style.md` for complete compatibility guide (auto-loaded when editing `src/` or `tests/`).

### Quality Standards

Every change must pass:
```bash
make sa          # ShellCheck static analysis
make lint        # EditorConfig linting (the formatting authority — 2-space indent)
./bashunit tests/  # All tests passing
```

**Never run `shfmt -w`.** shfmt and `.editorconfig` disagree on this repo: 146
tracked files are already shfmt-dirty on a clean `main`, and satisfying shfmt
breaks `make lint`. See "Formatting" below.

## Architecture

```
bashunit/
├── src/                    # Core framework code (Bash 3.2+ compatible)
│   ├── bashunit.sh        # Main entry point
│   ├── assertions.sh      # Assertion functions
│   ├── assert_*.sh        # Specialized assertions
│   └── *.sh               # Utilities (io, math, etc.)
├── tests/
│   ├── unit/              # Unit tests for src/ (isolated, with mocks)
│   ├── functional/        # Integration tests
│   └── acceptance/        # End-to-end CLI tests
├── .claude/               # Claude Code configuration
│   ├── CLAUDE.md         # This file
│   ├── skills/           # Custom workflows (invoke with /skill-name)
│   └── rules/            # Modular guidelines
├── .tasks/               # Optional task tracking files
├── adrs/                 # Architecture Decision Records
└── bashunit             # CLI entry point
```

## Common Commands

```bash
./bashunit tests/              # Run all tests
./bashunit --parallel tests/   # Parallel execution
./bashunit tests/unit/         # Run unit tests only
make sa                        # ShellCheck static analysis
make lint                      # EditorConfig checker (formatting authority)
```

## Formatting

Match the surrounding 2-space style by hand and verify with `make lint`. There is
no `shfmt` target, and **`shfmt -w .` must not be run** — it fights `.editorconfig`
two ways:

- `.editorconfig` sets `indent_size = unset` for `tests/acceptance/**.sh` and
  `src/console_header.sh`; shfmt reads `unset` as "use my default", which is tabs,
  while `[*]` sets `indent_style = space`. Any new file under `tests/acceptance/`
  therefore shows up shfmt-dirty — that is expected, not a defect.
- shfmt collapses `\`-continued strings onto one line, which would push
  `src/state.sh`'s record writer past `max_line_length = 120`.

To check you introduced no new drift, compare the dirty-file *list* against main
rather than requiring it to be empty:

```bash
git ls-files -z '*.sh' bashunit | xargs -0 shfmt -d 2>/dev/null \
  | grep '^--- ' | sed 's|--- ||; s|\.orig.*||' | sort
```

## Test Patterns

Study existing tests before writing new ones:

- **Assertions**: `tests/unit/assert_test.sh`
- **Test Doubles**: `tests/functional/doubles_test.sh`
- **Data Providers**: `tests/functional/provider_test.sh`
- **Lifecycle Hooks**: `tests/unit/setup_teardown_test.sh`
- **CLI Testing**: `tests/acceptance/bashunit_test.sh`

## Skills

Invoke with `/skill-name`:

| Skill | Purpose |
|-------|---------|
| `/tdd-cycle` | Complete RED → GREEN → REFACTOR cycle |
| `/fix-test` | Debug and fix failing tests |
| `/add-assertion` | Add new assertion with TDD |
| `/check-coverage` | Analyze test coverage gaps |
| `/pre-release` | Pre-release validation checklist |
| `/release` | Run pre-release checks and execute release |
| `/commit` | Stage and commit with conventional commits |
| `/gh-issue <N>` | GitHub issue → branch → implement → PR |
| `/pr [#N]` | Push branch and create PR |

## Path-Scoped Guidelines

Rules auto-load based on file paths being edited (via `paths:` frontmatter in each rule file).

### `src/**/*.sh`
- Small, portable functions
- Bash 3.2+ compatibility (no associative arrays, no `[[`, no `${var,,}`)
- Proper namespacing (`bashunit::*`)
- No external dependencies in core

### `tests/**/*_test.sh`
- Behavior-focused tests
- Use official assertions/doubles only
- Avoid network calls
- Use `temp_file`/`temp_dir` for isolation
- Test both success and failure paths

### `adrs/*.md`
- Read existing ADRs before major changes
- Use template for new decisions

## Guardrails

### Never:
- Invent commands/features not in the codebase
- Break Bash 3.2+ compatibility
- Skip tests or quality checks
- Change public API without docs/CHANGELOG
- Commit without tests passing
- Batch unrelated changes in one PR
- Create a PR without using the `/pr` skill

### Always:
- Write tests before implementation
- Use existing patterns from `tests/**` and `src/**`
- Minimal code in GREEN phase
- Keep tests passing during REFACTOR
- Update CHANGELOG.md for user-visible changes
- Run quality checks before committing
- Maintain Bash 3.2+ compatibility

## Definition of Done

- All tests green for the **right reason**
- `make sa` passes (ShellCheck)
- `make lint` passes (EditorConfig)
- Code formatted to 2-space indent by hand (verified by `make lint`, never `shfmt -w`)
- Bash 3.2+ compatible
- Parallel tests passing (`./bashunit --parallel tests/`)
- CHANGELOG.md updated (if user-facing changes)
- ADR created/updated (if architectural decision)

## Commit Message Format

[Conventional Commits](https://conventionalcommits.org/): `<type>(<scope>): <description>`

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
**Scopes:** `assert`, `runner`, `cli`, `docs`, etc.

## Prohibited Actions

**Never without explicit user request:**
- Commit secrets or sensitive data
- Force push to main/master
- Skip git hooks (--no-verify)
- Amend published commits
- Use destructive git commands (reset --hard, clean -f)
- Push to remote without confirmation
