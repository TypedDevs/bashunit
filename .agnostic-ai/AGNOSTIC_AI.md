# bashunit - Bash Testing Framework

## Project Overview

**bashunit** is a lightweight Bash testing framework (Bash 3.0+) focused on developer experience. Provides assertions, test doubles (spies/mocks), data providers, snapshots, and more.

**Documentation:** https://bashunit.com

## Core Principles

### TDD by Default
**RED → GREEN → REFACTOR**, every change starts from a failing test. No exceptions.

### Bash 3.0+ Compatible

Works on macOS default bash (3.2) and older. **Prohibited features:**
- `printf -v` (Bash 3.1+)
- `x+=y` string append assignment (Bash 3.1+)
- `arr+=(x)` array append (a Bash 3.0 **parse** error, it kills the file even in dead code)
- `declare -A` (associative arrays - Bash 4.0+)
- `[[ ]]` (use `[ ]` instead, house style, not a version limit)
- `[[ =~ ]]` (exists on 3.0, but 3.2 changed quoted-pattern semantics)
- `${var,,}` (case conversion - Bash 4.0+)
- `${array[-1]}` (negative indexing - Bash 4.3+)
- `&>>` redirect (Bash 4.0+)

See `.agnostic-ai/context/bash-style.md` for the complete compatibility guide.

### Quality Standards

Every change must pass:
```bash
make sa          # ShellCheck static analysis
make lint        # EditorConfig linting (the formatting authority, 2-space indent)
./bashunit tests/  # All tests passing
```

**Never run `shfmt -w`.** shfmt and `.editorconfig` disagree on this repo: 146
tracked files are already shfmt-dirty on a clean `main`, and satisfying shfmt
breaks `make lint`. See "Formatting" below.

## Formatting

Match the surrounding 2-space style by hand and verify with `make lint`. There is
no `shfmt` target, and **`shfmt -w .` must not be run**, it fights `.editorconfig`
two ways:

- `.editorconfig` sets `indent_size = unset` for `tests/acceptance/**.sh` and
  `src/console_header.sh`; shfmt reads `unset` as "use my default", which is tabs,
  while `[*]` sets `indent_style = space`. Any new file under `tests/acceptance/`
  therefore shows up shfmt-dirty, that is expected, not a defect.
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

## Task Context

All paths below are relative to the repository root, including from a generated skill or agent directory. Read only the guides relevant to the task before editing. Rules select the matching tasks and point to these guides. Follow the table even when the client cannot load path-scoped rules automatically.

| Task | Read |
|------|------|
| Changes to `src/` or `bashunit` | `.agnostic-ai/context/architecture-map.md` |
| Shell changes under `src/` or `tests/` | `.agnostic-ai/context/bash-style.md` |
| Changes to `src/` or fork census acceptance tests | `.agnostic-ai/context/perf-fork-budget.md` |
| Shell development or task plans | `.agnostic-ai/context/tdd-workflow.md` |
| Test changes | `.agnostic-ai/context/testing.md` |

## Delegation

Keep one acceptance scenario and a short plan in the main session. Handle small edits directly. Delegate independent lookups to `code-locator`, a bounded implementation to `code-implementer`, and defect review to `code-reviewer` before pushing. Give each agent a specific question or file scope, a base revision, and a validation budget. Reuse its findings instead of repeating its searches.

Keep at most two delegates active. Workers share the checkout: assign separate files and never revert another worker's edits. Run the full quality gate once in the main session after the change set is complete. Delegates run only a targeted check when needed to prove a finding. Return concise evidence with file and line references; put longer reports under the ignored `.agnostic-ai/local/` directory.

## Editing Instructions

Edit `.agnostic-ai/` and `agnostic-ai.yaml`, then run `agnostic-ai validate`, `agnostic-ai lint --strict`, `agnostic-ai sync`, and `agnostic-ai sync --check`. Native instruction files, skills, agents, and settings are generated and ignored by Git. Never edit them directly.

## Guardrails

### Never:
- Invent commands/features not in the codebase
- Break Bash 3.0+ compatibility
- Skip tests or quality checks
- Change public API without docs/CHANGELOG
- Commit without tests passing
- Batch unrelated changes in one PR
- Create a PR without using the `pr` skill

### Always:
- Write tests before implementation
- Use existing patterns from `tests/**` and `src/**`
- Minimal code in GREEN phase
- Keep tests passing during REFACTOR
- Update CHANGELOG.md for user-visible changes
- Run quality checks before committing
- Maintain Bash 3.0+ compatibility

## Definition of Done

- All tests green for the **right reason**
- `make sa` passes (ShellCheck)
- `make lint` passes (EditorConfig)
- Code formatted to 2-space indent by hand (verified by `make lint`, never `shfmt -w`)
- Bash 3.0+ compatible
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
