# How `src/` is laid out and how the binary is built

* Status: accepted
* Deciders: Chemaclass
* Date: 2026-08-01

Technical Story: the layout settled across
[#924](https://github.com/TypedDevs/bashunit/issues/924),
[#925](https://github.com/TypedDevs/bashunit/issues/925),
[#931](https://github.com/TypedDevs/bashunit/issues/931),
[#940](https://github.com/TypedDevs/bashunit/issues/940),
[#948](https://github.com/TypedDevs/bashunit/issues/948) and
[#949](https://github.com/TypedDevs/bashunit/issues/949).

## Context and Problem Statement

ADR-010 decided *that* large files become module directories, and later amended *where* the
aggregator lives. What neither it nor any other document states is the whole picture: what the
modules are, in what order they load, how a single-file binary is assembled from them, and
which tests keep all of that honest.

That picture was spread across ADR-010, `build.sh` comments, `.claude/rules/architecture-map.md`
and eight issues. Someone arriving at the project — a contributor or an agent — had no single
place to read it.

This ADR is **descriptive, not a new decision.** It records the architecture as settled so it
can be understood from the outside without archaeology.

## The rule

**`src/` contains module directories and nothing else.** There are no loose `.sh` files.

A module is a directory whose entry point is `index.sh`:

```
src/<module>/index.sh    <- the entry point: `source` lines and comments ONLY
src/<module>/<file>.sh   <- one file per responsibility
```

`index.sh` means exactly one thing, everywhere: *a pure aggregator*. It never holds a
statement. That is load-bearing, not stylistic — see the build section — and it is why
`src/main.sh` was **not** renamed to `src/index.sh` when the question came up: a root
`index.sh` holding real code would make the name mean two things depending on depth.

## The modules

Seventeen, in the order the `bashunit` entrypoint sources them. The order is the dependency
layering: leaves first.

| # | Module | Files | Lines | Owns |
|---|---|---|---|---|
| 1 | `dev/` | 1 | 18 | debug helpers; **excluded from the build** |
| 2 | `system/` | 4 | 192 | capability probing: OS, `command -v`, small I/O |
| 3 | `util/` | 4 | 476 | computation: strings, arithmetic, time |
| 4 | `api/` | 5 | 207 | the surface a user's test file calls (except assertions) |
| 5 | `config/` | 4 | 964 | `BASHUNIT_*` defaults, scratch dirs, parallel mode, rerun cache |
| 6 | `coverage/` | 13 | 2644 | line/branch tracking and the four report formats |
| 7 | `state/` | 6 | 477 | counters, per-test context, result payload, parallel aggregation |
| 8 | `console/` | 9 | 1281 | everything printed: palette, header, per-test lines, totals |
| 9 | `helper/` | 8 | 976 | naming, discovery, data providers, tags, encoding |
| 10 | `cli/` | 5 | 447 | the `doc`/`init`/`upgrade`/`watch` subcommand implementations |
| 11 | `assert/` | 11 | 2336 | every assertion |
| 12 | `reports/` | 7 | 467 | JUnit, TAP, JSON, GHA and HTML writers |
| 13 | `runner/` | 11 | 2172 | the file loop, per-test execution, retry, result parsing |
| 14 | `benchmark/` | 4 | 221 | the bench implementation (`runner/bench.sh` is its loop) |
| 15 | `learn/` | 5 | 240 | the interactive tutorial |
| 16 | `main/` | 8 | 1475 | flag parsing per subcommand and the run lifecycle |

Namespaces track directories: `src/runner/` holds `bashunit::runner::*`. Two exceptions are
deliberate — `assert/` holds bare `assert_*` (the public API is unprefixed) and `console/`
holds `bashunit::console_results::*` in files named for what they do.

### Load order is not arbitrary

Most of it is ordinary dependency layering, but three points are genuinely load-bearing:

* **`api/globals.sh` runs `set -euo pipefail` at file scope.** Everything sourced after it
  inherits strict mode. It must stay first inside `api/`, and `api/` must stay where it is.
* **`config/env.sh` executes at source time** — it loads `.bashunitrc` and `.env` and creates
  the scratch dirs. It must come before `console/`, whose palette is built at file scope from
  the values it resolves.
* **`main/` is sourced last**, after everything it dispatches to.

## How the binary is built

`build.sh` turns the module tree into one executable file. It is a **depth-first walk of
`source` statements, not a walk of directories** — so nesting depth and directory shape are
invisible to it.

```
1. build::dependencies    read `^source ` lines from the `bashunit` entrypoint,
                          minus src/dev/  ->  the embed list
2. build::process_file    for each: emit `# <repo-relative path>`, then the file body
                          (shebang stripped), THEN recurse into its own `source` lines
                          dedupe on the repo-relative path
3.                        strip every `^source ` line from the result
4. build::embed_docs      swap docs/assertions.md into a heredoc between the markers
                          in src/cli/doc.sh, so the binary needs no docs/ directory
5. build::assert_valid_syntax   bash -n
6. build::verify (-v)     run the whole suite against the built binary
```

**Step 2 is why an aggregator may hold only `source` lines.** A file's body is emitted *before*
its dependencies are recursed into, so a statement in an `index.sh` would run before the code
it depends on in the built binary, while running after it in dev mode — the two modes would
disagree.

The dedupe keys on the **repo-relative path**, never a basename: the top-level loop passes
relative paths and the recursion absolute ones, and two modules legitimately share a basename
(`config/parallel.sh` answers "is this run parallel"; `runner/parallel.sh` waits on job slots).

## The contracts that keep it honest

Every rule above is enforced by a test. This is the list to check before changing anything
structural.

| Contract | Test |
|---|---|
| Aggregators hold only `source` lines and comments | `build_test.sh` — globs `src/*/index.sh`, so it cannot drift |
| Every entrypoint-sourced file reaches the binary, and no others | `build_test.sh` — the #735 and bench-#0.31.0 regressions |
| Arbitrary nesting depth is embedded, in DFS order, with no `source` lines surviving | `build_test.sh` (#932) |
| Same basename in two modules does not collide | `build_test.sh` (#923) |
| `state/` never calls the renderer or `parallel` | `state_test.sh` — globs `src/state/*.sh` (#868, #862) |
| Shell completions match the flags `main/` actually parses | `completions_test.sh` |
| Every unprefixed env alias is declared and listed | `env_deprecated_aliases_test.sh` |
| No Bash 4+ syntax anywhere in `src/` | `bash_compatibility_test.sh` |

**These greps are the fragile part of the design.** A contract that greps a path passes
*vacuously* the moment that path moves — green, and checking nothing. It has happened: #946
moved `state.sh` and the layering contract kept passing while testing nothing. Prefer a glob
over a module to a path to a file, and after repointing one, **mutate the thing it guards and
watch it go red**.

## How to change things

**Add a function** — put it in the module file that owns the responsibility; nothing else to do.

**Add a file to a module** — create it, add one `source` line to that module's `index.sh`.
Its first line must be `#!/usr/bin/env bash` (`tail -n +2` strips it when embedding).

**Add a module** — create `src/<name>/index.sh` plus its files, and add one `source` line to
the `bashunit` entrypoint at the right point in the layering. Then check
`git check-ignore -v src/<name>/<file>.sh`: an unanchored `.gitignore` pattern once matched
`src/coverage/` and hid twelve files from git with no `??` in `git status` (#928).

**Add a subcommand** — implementation in `src/cli/`, flag parsing in `src/main/subcommands.sh`,
routing in the `bashunit` entrypoint, and entries in **both** completion scripts or
`completions_test.sh` fails.

**Split a file** — derive segment boundaries from the *next function's start*, never from a
`^}$` closing brace: a brace inside a heredoc or a `case` arm ends the segment early and
silently splits a function across files (#938). Prove the result is a relocation by comparing
the non-blank line multiset and the function count before and after, then diff the built
artifact — its code content should be identical.

## Consequences

**Good**

* `ls src/` names the architecture. Every entry is a concept, not a file.
* One convention for entry points at every depth.
* The build needs no per-module knowledge, so adding a module is one `source` line.
* Each file is small enough to read whole. The two largest are deliberate and were re-examined
  more than once: `assert/core.sh` (970 lines) is one assertion catalogue whose size is
  inherent to holding 42 assertions, and `main/test.sh` (489) is a single `case` over ~60
  flags, which is the one shape that must not be cut across files. `config/env.sh` (754) is
  likewise whole: 51 functions, but 33 of them are `is_*` predicates over one concern.

**Bad**

* More indirection when grepping: `bashunit::runner::*` spans eleven files.
* Return-slot globals cross file boundaries, so ShellCheck cannot see both ends. CI runs it
  per file without `-x`, which surfaces cross-file symbol use a monolith hid — occasionally a
  genuine dead local (#928), occasionally a needed `disable` comment.
* Every path-grepping contract is now one rename away from going vacuous. Mitigated by globbing
  modules rather than naming files, and by mutation-testing after any repoint.

## Links

* [ADR-010](adr-010-src-module-directories.md) — the decision this describes the outcome of
* `.claude/rules/architecture-map.md` — the per-file map and the call flow of a run
* `.claude/rules/perf-fork-budget.md` — why per-test paths must stay fork-free
* `.claude/rules/bash-style.md` — the Bash 3.0 floor and the return-slot pattern
