# Branch Coverage MVP via Static Branch-Point Detection

* Status: accepted
* Date: 2026-05-04

## Context and Problem Statement

Coverage today reports line-level execution only. Standard tooling (genhtml, Codecov, Coveralls) consumes branch records via the LCOV `BRDA`/`BRF`/`BRH` fields, which let reviewers see whether `else`/`elif` arms and individual `case` patterns were exercised. Adding true branch coverage to a Bash framework is non-trivial because:

1. Bash exposes no native instrumentation comparable to gcov branch counters.
2. The DEBUG trap fires on commands, not on branch decisions.
3. `BASH_COMMAND` reflects the *next* command, not the boolean outcome of a conditional.

We need a path that yields useful, mostly-correct branch metrics in LCOV reports without breaking Bash 3.0+ compatibility or the cost profile of the existing line tracker.

## Decision Drivers

* Bash 3.0+ compatibility (no associative arrays, no `[[`, no Bash 4-only features).
* Reuse existing line-hit data; do not double the runtime cost of coverage.
* LCOV output must be consumable by genhtml, Codecov and Coveralls without custom processing.
* Implementation must fit in `src/coverage.sh` and remain testable with the existing unit-test patterns.
* Behavior must be predictable enough to pin in tests; "best-effort heuristic" outputs are not acceptable.

## Considered Options

1. **Static branch-point detection plus line-hit inference** — parse the source file for branch-introducing constructs (`if`/`elif`/`else`, `case` patterns), compute the line range owned by each outcome, then mark the outcome as "taken" iff any line inside its range was hit.
2. **Runtime decision tracing via `BASH_COMMAND`** — record the actual command being executed in the DEBUG trap and reconstruct decisions taken (`if X` followed by execution of either then-block or else-block).
3. **Patch-based instrumentation** — preprocess source files to insert hit recorders inside each branch arm, run tests against the instrumented copy, post-process the data file.

## Decision Outcome

Chosen option: **Option 1 (static branch-point detection plus line-hit inference)**.

It reuses the existing line-hit data file with no DEBUG-trap changes. Bash 3.0+ compatibility is preserved because the parser is a single pass over the source with brace counting, identical in shape to the existing `extract_functions` walker. The output maps cleanly to LCOV `BRDA` records, and the contract ("an arm is taken iff any executable line inside it was hit") is precise enough to write unit tests against.

### Positive Consequences

* Zero runtime cost beyond the existing line tracker. Branch records are computed during report generation, not during test execution.
* Reuses `is_executable_line` and `get_all_line_hits`, which already tolerate Bash 3.0 limitations.
* LCOV output remains a single file, consumed unchanged by downstream tools.

### Negative Consequences

* Branch detection is line-presence based, not outcome based. A `then` arm whose only statement is a comment-line will register as `not taken` even if the conditional fired (because there are no executable lines inside). This is documented as a known limitation.
* Implicit `else` (when an `if/elif` chain has no explicit `else`) is reported only when at least one explicit arm exists; the synthetic "fall-through" outcome is omitted from this MVP and may be added in a follow-up.
* Compound conditionals (`if A && B`) are reported as a single binary decision, not per sub-expression.

## Pros and Cons of the Options

### Option 1: Static + line-hit inference (chosen)

* Good, because reuses existing data and code paths.
* Good, because matches the implementation pattern of `extract_functions` already shipping in the codebase.
* Good, because output is deterministic and easy to test.
* Bad, because cannot distinguish "arm executed but produced no executable lines" from "arm not executed".

### Option 2: Runtime DEBUG-trap decision tracing

* Good, because reflects actual runtime behavior.
* Bad, because `BASH_COMMAND` semantics across Bash 3.x and 5.x diverge for `((...))`, `[[...]]` and pipelines, requiring per-version logic.
* Bad, because increases per-line overhead; the existing tracker already has measurable cost.
* Bad, because subshell context loss (already documented for line coverage) extends to branches taken inside `$(...)`.

### Option 3: Source-rewrite instrumentation

* Good, because most accurate signal possible.
* Bad, because requires either running tests against a rewritten source tree or hooking `source` to redirect to instrumented copies — both invasive and brittle.
* Bad, because debugging stack traces and line numbers no longer match the user's source.
* Bad, because doubles the code surface and breaks the "DEBUG-trap only" simplicity model.

## Scope of MVP

Included:

* `if`/`elif`/`else` chains: each arm is one outcome.
* `case` statements: each pattern is one outcome.
* LCOV `BRDA:<line>,<block>,<branch>,<taken>` lines.
* `BRF:<count>` and `BRH:<count>` per file.

Deferred (potential follow-ups):

* Synthetic "implicit-else" outcomes for `if/elif` chains without an explicit `else`.
* Per-sub-expression decisions inside `if A && B`.
* `&&` / `||` short-circuit branches outside `if`.
* Loop-entry decisions (`while`/`until`).

## Links

* Builds on the function extractor introduced in `src/coverage.sh` (see `bashunit::coverage::extract_functions`).
* LCOV format reference: <https://manpages.debian.org/unstable/lcov/geninfo.1.en.html>
