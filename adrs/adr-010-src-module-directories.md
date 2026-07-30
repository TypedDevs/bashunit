# Splitting large `src/` files into module directories

* Status: accepted
* Deciders: Chemaclass
* Date: 2026-07-30

Technical Story: https://github.com/TypedDevs/bashunit/issues/924

## Context and Problem Statement

`src/runner.sh` had grown to 2145 lines and 57 functions covering five unrelated
responsibilities: the per-file loop, per-test execution, retry/timeout, result
parsing and failure context. Navigating it meant scrolling, and every change
touched the same file no matter which concern it belonged to.

`src/` was flat, so the obvious fix — one file per responsibility — would have
added ten more entries to an already-40-file directory. Can we group them into a
directory without changing what the released single-file binary does?

## Decision Drivers

* The distributable is a single concatenated bash script; its execution order
  must not change.
* Bash 3.0+ floor, so no clever loading tricks.
* Per-test paths are fork-free and budgeted (`.claude/rules/perf-fork-budget.md`).
* `make test` globs `tests/*/*[tT]est.sh` — exactly one level deep.

## Considered Options

* Leave `src/runner.sh` as one file
* Split into flat `src/runner_*.sh` files
* Split into a `src/runner/` directory behind a thin aggregator

## Decision Outcome

Chosen option: **`src/runner/` directory behind a thin aggregator**.

`src/runner.sh` keeps its single `source` line in the `bashunit` entrypoint and
becomes ten `source` lines plus comments. `build.sh` needs no per-module
knowledge: it already recurses into `source` lines, so the module children are
discovered through the aggregator.

This required fixing `build.sh` first (#923). Its embed dedupe was keyed on a
file's *basename*, which both hid a genuine double-embed (the top-level loop
passes repo-relative paths, the recursion absolute ones, so the two spellings
never matched) and would have collided `src/parallel.sh` with
`src/runner/parallel.sh`. The key is now the repo-relative path.

**The constraint this buys is worth stating explicitly: an aggregator may contain
only `source` lines and comments.** `build::process_file` emits a file's body and
*then* recurses into its sources, so any statement in an aggregator would run
before its dependencies in the built binary but after them in dev mode. This is
enforced by `test_module_aggregators_hold_only_source_lines_and_comments`.

Sourcing follows the dependency layering, leaves first:

```
context · payload · diagnostics → parallel · hooks · result → provider · exec → discovery · bench
```

53 of the 57 functions are leaves; only `load_test_files`, `load_bench_files`,
`run_test` and `parse_result` have callees, so the layering is acyclic.

### Positive Consequences

* Each file is 90-540 lines with one responsibility; `src/` root gains a
  directory instead of ten files.
* No runtime cost. Cold start is dominated by parse time, not file opens
  (measured in #798), and a file split adds no forks — the fork-budget
  acceptance tests pass unchanged.
* The pattern generalises: `src/coverage.sh` (2548 lines) is the next candidate.

### Negative Consequences

* Return-slot globals now cross file boundaries — `runner/payload.sh` declares
  the 13 `_BASHUNIT_RUNNER_*_OUT` slots that `runner/exec.sh` reads. ShellCheck
  can no longer see both ends, so `runner/exec.sh` needs one scoped `SC2154`
  disable for the `exit_code` assigned inside an EXIT trap body and read by
  `cleanup_on_exit` in `runner/hooks.sh`.
* One more indirection when grepping: `bashunit::runner::*` now spans ten files.

## Pros and Cons of the Options

### Leave `src/runner.sh` as one file

* Good, because zero risk and zero churn.
* Bad, because the file had five responsibilities and no seam to test them apart.

### Flat `src/runner_*.sh` files

* Good, because it needs no `build.sh` change at all.
* Bad, because it grows the flat `src/` root by ten entries and encodes the
  grouping in a filename prefix rather than in the directory structure.
* Bad, because it does not generalise — `src/coverage.sh` would add nine more.

### `src/runner/` directory behind an aggregator

* Good, because it mirrors the existing `src/assertions.sh` → `src/assert_*.sh`
  aggregator precedent, and `src/dev/debug.sh` already proved `src/` can nest.
* Good, because `build.sh` discovers children through recursion, so adding a
  module file needs no build change.
* Bad, because it required fixing the build's dedupe key first (#923).

## Links

* Enabled by [#923](https://github.com/TypedDevs/bashunit/issues/923) — repo-relative embed markers
* Tests stay flat: `make test` globs one level, so `tests/unit/runner_*_test.sh`,
  never `tests/unit/runner/`
