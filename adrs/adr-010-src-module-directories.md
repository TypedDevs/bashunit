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
* Split into a `src/runner/` directory behind a thin aggregator **beside** it
  (`src/runner.sh` + `src/runner/*.sh`)
* Split into a `src/runner/` directory with the aggregator **inside** it as an
  index (`src/runner/index.sh` + `src/runner/*.sh`)

## Decision Outcome

Chosen option: **`src/runner/` directory behind a thin aggregator beside it**.

`src/runner.sh` keeps its single `source` line in the `bashunit` entrypoint and
becomes ten `source` lines plus comments. `build.sh` needs no per-module
knowledge: it already recurses into `source` lines, so the module children are
discovered through the aggregator.

The aggregator sits **beside** the directory rather than inside it as an
`index.sh`. Both are identical to `build.sh` — see the next section, the build
follows the `source` graph and cannot tell the difference — so the choice is
about the source tree, not the artifact. Beside wins on precedent: it is exactly
how `src/assertions.sh` has aggregated the flat `src/assert_*.sh` files since
long before module directories existed, so there is one aggregator convention in
`src/` rather than two. Inside would make each module a self-contained directory
and keep `ls src/` free of aggregator/directory pairs, which is the real argument
for it; it was rejected as not worth renaming shipped modules and rewriting
entrypoint lines for a cosmetic gain. Revisit only with a deliberate amendment
here — not per module, or `src/` ends up with both conventions.

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

### `src/runner/` directory behind an aggregator beside it

* Good, because it mirrors the existing `src/assertions.sh` → `src/assert_*.sh`
  aggregator precedent, and `src/dev/debug.sh` already proved `src/` can nest.
* Good, because `build.sh` discovers children through recursion, so adding a
  module file needs no build change.
* Good, because the entrypoint keeps one `source` line per module, unchanged in
  shape from when the module was a single file.
* Bad, because it required fixing the build's dedupe key first (#923).
* Bad, because `ls src/` shows an aggregator/directory pair per module.

### `src/runner/index.sh` inside the directory

* Good, because a module becomes one self-contained directory — moving or
  deleting it is a single `mv`/`rm -r`, and `ls src/` shows modules, not pairs.
* Good, because it scales more cleanly if `src/` ever reaches a dozen modules.
* Neutral on the build: identical to beside, which walks the `source` graph.
* Bad, because it would rename the two shipped modules and rewrite their
  entrypoint lines for no behavioural gain.
* Bad, because `src/assertions.sh` would stay a beside-aggregator (it has no
  directory), leaving `src/` with two aggregator conventions.

## Links

* Enabled by [#923](https://github.com/TypedDevs/bashunit/issues/923) — repo-relative embed markers
* First application: [#924](https://github.com/TypedDevs/bashunit/issues/924) — `src/runner/`
* Second application: [#925](https://github.com/TypedDevs/bashunit/issues/925) — `src/coverage/`,
  which produced the five constraints above
* Remaining work: [#931](https://github.com/TypedDevs/bashunit/issues/931) — nine flat files left
* Build depth pinned by: [#932](https://github.com/TypedDevs/bashunit/issues/932)
* Tests stay flat: `make test` globs one level, so `tests/unit/runner_*_test.sh`,
  never `tests/unit/runner/`
