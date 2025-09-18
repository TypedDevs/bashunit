# AGENTS instructions

**bashunit is a fast, portable Bash testing framework/library.** This guide complements (does not replace) `.github/copilot-instructions.md`.

## Prime Directives

- **TDD by default**: Red → Green → Refactor. Fail **for the right reason**. Implement the **smallest** code to pass. Refactor with all tests green.
- **Task file is mandatory**: Create **`./.tasks/YYYY-MM-DD-slug.md`** before any work; keep it updated (acceptance criteria, **test inventory**, current red bar, timestamped logbook).
- **Definition of Done** must be satisfied to finish.
- **Clarity rule**: If something is ambiguous, ask first; record answers in the task file.
- **ADRs**: Read existing ADRs first; for new decisions, create an ADR using the repo's template and match existing format.

## Agent Workflow

1) **Before coding**
   - Create `./.tasks/YYYY-MM-DD-slug.md` with context, acceptance criteria, test inventory, current red bar, and a timestamped **Logbook**.
   - Read `.github/copilot-instructions.md` + relevant ADRs; record links/assumptions in the task file.
   - Create a list with all tests needed to cover acceptance criteria
   - Add this list to the task file as a **test inventory** (unit, functional, acceptance).
   - Prioritize tests by the smallest next step.
   - Pick the first test to implement.
   - For the testing approach, see the concise overview of the **TDD approach** in `.github/copilot-instructions.md` and keep this file concise.

2) **Red**
   - Add a test that fails for the intended reason, using **only existing patterns** from `./tests/**`.

3) **Green**
   - Implement the **minimal** change in `./src/**` to pass; update the Logbook.

4) **Refactor**
   - Improve code/tests incrementally while keeping all tests green. Update docs/ADR if behavior or decisions change.
   - Use `shellcheck -x $(find . -name "*.sh")` and `shfmt -w .` to ensure lint/format compliance.
   - Run the test suite with `./bashunit tests/` to ensure everything remains green.
   - Run the linting/formatting checks again and ensure compliance.
   - Evaluate if any existing tests can be removed or simplified due to refactoring; Or if new tests are needed to cover edge cases discovered during refactoring, add them to the test inventory in the task file.
   - Update the task file's Logbook with details of the refactoring process, including any challenges faced and how they were addressed.
   - if all the tests are green and the code is clean easy to read and maintain, pick the next test from the inventory and repeat steps 2-4 untill all tests in the inventory are done. and the acceptance criteria are met.

5) **Quality Gate (pre-commit)**
   - Run repo's real lint/format: `shellcheck -x $(find . -name "*.sh")` and `shfmt -w .`
   - Run tests with `./bashunit tests/` (or scoped runs as appropriate).

6) **Docs & ADR**
   - Update `README`/docs when CLI/assertions/behavior changes.
   - Add/update ADRs for significant decisions; link from the task file.

7) **Finish (Definition of Done)**
   - Linters/formatters **clean**.
   - All tests **green for the right reason**.
   - Acceptance criteria **met** in the task file.
   - Docs/CHANGELOG updated when user-visible changes occur.

## bashunit Guardrails

- Use **only verified** features/patterns proven by `./src/**` and `./tests/**` (assertions, test doubles `mock`/`spy` + `assert_have_been_called*`, data providers, snapshots, skip/todo, globals like `temp_file`/`temp_dir`/`data_set`, lifecycle hooks).
- Prefer spies/mocks for time/OS/tooling; avoid depending on external binaries in unit tests.
- Don't break public API/CLI without semver + docs/CHANGELOG.
- No speculative work: every change starts from a failing test and explicit acceptance criteria.
- Isolation/cleanup: use `temp_file`/`temp_dir`; do not leak state across tests.

## Tests & Patterns (usage, not code)

Examples must mirror **real** patterns from `./tests/**` exactly:
- **Core assertions**: Study `tests/unit/assert_test.sh` for line continuation patterns and failure testing
- **Test doubles**: Study `tests/functional/doubles_test.sh` for mock/spy with fixtures
- **Data providers**: Study `tests/functional/provider_test.sh` for `@data_provider` syntax
- **Lifecycle hooks**: Study `tests/unit/setup_teardown_test.sh` for `set_up_before_script` patterns
- **CLI acceptance**: Study `tests/acceptance/bashunit_test.sh` for snapshot testing

## Path-Scoped Guidance

- `./src/**`: small, portable functions, namespaced; maintain Bash 3.2+ compatibility
- `./tests/**`: behavior-focused tests using official assertions/doubles; avoid networks/unverified tools
- `./.tasks/**`: one file per change (`YYYY-MM-DD-slug.md`); keep AC, test inventory, current red bar, and timestamped Logbook updated
- `./adrs/**`: read first; when adding, use template and match existing ADR style

## Prohibitions

- Don't invent commands or interfaces; extract from repo only.
- Don't change CI/report paths without explicit acceptance criteria and doc/test updates.
- Don't skip the task-file requirement; don't batch unrelated changes in one PR.

## Two-Way Sync (mandatory)

- When **`.github/copilot-instructions.md`** changes, **evaluate** whether the change belongs in `AGENTS.md` and **update `AGENTS.md`** to stay aligned.
- When **`AGENTS.md`** changes, **evaluate** whether the change belongs in `.github/copilot-instructions.md` and **update `.github/copilot-instructions.md`** to stay aligned.
- If a change is intentionally **not** mirrored, record the rationale in the active `./.tasks/YYYY-MM-DD-slug.md`.

## PR Checklist

- ✅ All tests green for the **right reason**
- ✅ Linters/formatters clean
- ✅ Task file updated (AC, test inventory, Logbook, Done timestamp)
- ✅ Docs/README updated; CHANGELOG updated if user-visible
- ✅ ADR added/updated if a decision was made
- ✅ **Two-way sync validated** (`AGENTS.md` ↔ `.github/copilot-instructions.md`)

For complete details, patterns, and examples, see `.github/copilot-instructions.md`.
