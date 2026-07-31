# Splitting large `src/` files into module directories

* Status: accepted, amended 2026-08-01
* Deciders: Chemaclass
* Date: 2026-07-30

Technical Story: https://github.com/TypedDevs/bashunit/issues/924

> **Amendment, 2026-08-01.** The aggregator moves *inside* the module directory
> as `index.sh`, replacing the original `src/<module>.sh` beside it. The
> reasoning that first chose "beside" was wrong, and one of the two arguments
> that overturn it is a correctness bug rather than a preference — see
> [Aggregator placement](#aggregator-placement-amended-2026-08-01).

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
* Split into a `src/runner/` directory behind a thin aggregator **beside** it
  (`src/runner.sh` + `src/runner/*.sh`)
* Split into a `src/runner/` directory with the aggregator **inside** it as an
  index (`src/runner/index.sh` + `src/runner/*.sh`)

## Decision Outcome

Chosen option: **`src/runner/` directory with the aggregator inside it as
`index.sh`** (originally "beside it"; amended 2026-08-01, below).

The entrypoint keeps a single `source` line per module —
`src/runner/index.sh` — and that file is ten `source` lines plus comments.
`build.sh` needs no per-module knowledge: it already recurses into `source`
lines, so the module children are discovered through the aggregator.

### Aggregator placement (amended 2026-08-01)

The aggregator lives **inside** the module directory as `index.sh`:

```
src/runner/index.sh    <- the module's entry point
src/runner/exec.sh
src/coverage/index.sh
src/coverage/engine.sh
```

Both placements are identical to `build.sh` — it follows the `source` graph and
cannot tell the difference (next section) — so this is a source-tree decision,
not an artifact one.

The original decision was "beside" (`src/runner.sh` + `src/runner/*.sh`), on the
grounds that it matched the `src/assertions.sh` → `src/assert_*.sh` precedent and
kept one aggregator convention in `src/`. **That reasoning was wrong.**
`src/assertions.sh` aggregates *flat* files; there is no `src/assert/` directory.
It is not a module aggregator at all, it is unaffected by this choice, and it
would remain exactly as it is under either placement. There was never a
"two conventions" risk to avoid.

Two arguments settle it for inside:

* **A hand-maintained aggregator list drifts; a glob cannot.** The rule that
  aggregators hold only `source` lines is enforced by
  `test_module_aggregators_hold_only_source_lines_and_comments`, which named its
  aggregators in a string: `"src/assertions.sh src/runner.sh"`. `src/coverage.sh`
  was added in #928 and never appended, so the rule silently stopped covering it
  within one module of being introduced. With the aggregator at a predictable
  `src/*/index.sh`, the test discovers modules by glob and cannot drift. This is
  the deciding argument: it is a correctness property, not a preference.
* **The cost only grows.** Converting two shipped modules costs two renames and
  two entrypoint lines. #931 adds nine more; converting after it costs eleven.

Alongside those, the ordinary case for treating a directory as the module: `mv`
or `rm -r` moves it as one unit, an orphaned `src/runner.sh` left behind by a
deleted `src/runner/` becomes impossible, and `ls src/` lists modules rather than
aggregator/directory pairs. The convention also matches what most ecosystems do —
`index.ts`, `__init__.py`, `mod.rs`.

`index.sh` over `main.sh` or `init.sh`: both of those collide with existing
concepts here (`src/main.sh`, and `src/init.sh` implementing `bashunit init`).

Apply this to every module. Mixing placements is the outcome worth avoiding.

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

### The build is depth-agnostic — measured, not assumed

`build::process_file` is a depth-first walk of `source` **statements**, not a walk
of directories. It emits a file's body (shebang stripped via `tail -n +2`),
recurses into every `^source ` line, dedupes on the repo-relative path (#923), and
the final artifact has all `source` lines stripped. Nothing in it knows or cares
how deep a file sits, or whether an aggregator is beside its directory or inside
it.

Verified on `main` with a throwaway three-level module —
`src/x.sh → src/x/mid.sh → src/x/deep/leaf.sh` — built into a temp dir: all three
bodies embedded, in DFS order, zero `source` lines remaining, and the depth-3
function present in the single-file binary.

So arbitrarily nested modules need no build work. That property is currently
undocumented in the build itself and untested; #932 pins it, because two
regressions have already shipped through this seam (#735 dropped `src/watch.sh`
from the release build; #923's dedupe keyed on basename, which would have collided
`src/parallel.sh` with `src/runner/parallel.sh`).

### Constraints a split must respect

Beyond the aggregator rule, five traps have cost real time. The first was found in
#924, the rest in #925/#928:

* **Order-dependent file-scope initialisers must stay contiguous and in order.**
  `_BASHUNIT_COVERAGE_XTRACE_PS4` expands `$_BASHUNIT_COVERAGE_XTRACE_FS` at file
  scope, and `_NONEXEC_PATTERN` is built across seven successive lines. Grep for
  file-scope assignments that read another file-scope variable before splitting.
* **`.gitignore` can silently swallow a new module directory.** `coverage/` was
  unanchored, so it also matched `src/coverage/` and excluded all twelve new files
  from git — `git status` showed no `??` entries at all, and the split would have
  shipped empty. Anchored to `/coverage/` in #928. Always run
  `git check-ignore -v src/<module>/<file>.sh` before committing a new module.
* **CI runs ShellCheck per file without `-x`, so it cannot follow `source`.** A
  monolith hides cross-file symbol use that a split exposes; in #928 this surfaced
  a genuinely dead local (SC2034) that `make sa` passed locally. Reproduce CI's
  mode before pushing.
* **Per-file `.editorconfig` rules are lost by a split.**
  `[src/coverage.sh] max_line_length = unset` would have silently become the global
  120 for twelve new files. #928 rescoped it to the two files that actually needed
  it and reflowed the rest — a net tightening. Decide deliberately, state it in the PR.
* **Dynamic-scope helper groups cannot be separated.** Helpers that mutate a
  caller's locals must land in the same file as their caller, with the inline
  justification comment travelling with them (`src/coverage/branches.sh`).

**Verification that a split is a pure relocation**: compare the non-blank line
multiset before and after — it must differ only by the new shebangs and module
header comments — together with an unchanged function count. This caught every
accidental edit in #928.

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
* The pattern generalised: `src/coverage.sh` (2548 lines, 59 functions) followed
  in #925/#928 as twelve modules, unchanged process, no build work. Nine large
  flat files remain (#931).

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

### `src/runner/` directory behind an aggregator beside it (rejected on amendment)

* Good, because `build.sh` discovers children through recursion, so adding a
  module file needs no build change.
* Good, because the entrypoint line keeps the shape it had when the module was a
  single file.
* Bad, because the aggregator's path is unpredictable, so the test enforcing the
  "only `source` lines" rule needs a hand-maintained list — which drifted the
  first time a second module appeared (#928 added `src/coverage.sh` and never
  appended it, silently un-enforcing the rule for that file).
* Bad, because `ls src/` shows an aggregator/directory pair per module, and the
  pair can desync: deleting `src/runner/` leaves an orphaned `src/runner.sh`.
* Bad, because it required fixing the build's dedupe key first (#923).
* ~~Good, because it mirrors the `src/assertions.sh` → `src/assert_*.sh`
  precedent~~ — withdrawn. `src/assertions.sh` aggregates flat files and has no
  directory, so it is not a module aggregator and is unaffected either way.

### `src/runner/index.sh` inside the directory (chosen on amendment)

* Good, because the aggregator sits at a predictable `src/*/index.sh`, so the
  enforcement test discovers modules by glob and cannot drift.
* Good, because a module becomes one self-contained directory — `mv`/`rm -r`
  moves it as a unit, no orphan is possible, and `ls src/` lists modules.
* Good, because it matches the convention most ecosystems already use
  (`index.ts`, `__init__.py`, `mod.rs`), so the entry point is where a reader
  looks for it.
* Neutral on the build: identical to beside, which walks the `source` graph.
* Bad, because it cost renaming the two shipped modules and their entrypoint
  lines — a cost that only grows, hence doing it before #931 adds nine more.

## Links

* Enabled by [#923](https://github.com/TypedDevs/bashunit/issues/923) — repo-relative embed markers
* First application: [#924](https://github.com/TypedDevs/bashunit/issues/924) — `src/runner/`
* Second application: [#925](https://github.com/TypedDevs/bashunit/issues/925) — `src/coverage/`,
  which produced the five constraints above
* Remaining work: [#931](https://github.com/TypedDevs/bashunit/issues/931) — nine flat files left
* Build depth pinned by: [#932](https://github.com/TypedDevs/bashunit/issues/932)
* Tests stay flat: `make test` globs one level, so `tests/unit/runner_*_test.sh`,
  never `tests/unit/runner/`
