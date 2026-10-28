---
scope: src
---

# Architecture map

Repository paths are relative to the root. Module paths below are under `src/` unless stated otherwise. Use function names as anchors; verify the current caller before changing a path. The per-module ownership table is in `.agnostic-ai/skills/fork-census/references/module-map.md`.

## Run lifecycle

1. `bashunit` checks the Bash version, scans early flags, sources modules, and routes to `bashunit::main::cmd_test`.
2. `runner/discovery.sh` discovers and loads files, checks duplicates, builds metadata and filters selected functions. Header counting in `helper/discovery.sh` uses static metadata where safe and sources dynamic files only when needed. Sequential multi-file counting caches snapshots and metadata for unchanged files up to 512 bytes; `helper/provider.sh` validates the path and contents before reuse.
3. The header calls `find_total_tests` directly and reads its return slot. Do not wrap it in `$()`, which discards shell-state cache changes.
4. `runner/exec.sh` dispatches tests and providers, captures the test body in a subshell, and manages retries, timeouts and hooks. `runner/payload.sh` and `state/payload.sh` transport results; mutations inside a test do not update parent counters directly.
5. `runner/result.sh` handles synchronous results or writes parallel `.result` files. Under `--parallel`, file dispatch also runs in a background subshell; results and explicit files carry state back. `state/parallel.sh` aggregates worker results in the parent.
6. Console and report modules render results. Rerun persistence, temporary-output cleanup and exit status complete the run.

## Cross-cutting invariants

- Follow `.agnostic-ai/rules/bash-style.md` for Bash 3.0 parsing and `.agnostic-ai/rules/return-slots.md` for return values. `local` is dynamically scoped; helper locals can shadow caller-named outputs.
- Follow `.agnostic-ai/rules/perf-fork-budget.md` for process costs. Preserve the acceptance budgets rather than assuming every path has the same allowance.
- Background file dispatch cannot return counters or flags through shell state. Put whole-file validation before dispatch or return failures through explicit results. Always test sequential and parallel modes when changing this boundary.
- Use dispatcher ordinals for worker identity. Subshells share `$$`; `RANDOM` reseeding varies by platform and nesting and cannot guarantee uniqueness.
- Framework binaries are pinned at startup (`$GREP`, `$MKTEMP`, `$CAT` in `config/env.sh`) so test doubles and PATH changes cannot hijack internal plumbing.
- Snapshots use an 80-column non-TTY fallback. Rendering width changes affect `tests/acceptance/snapshots/`.
- `build.sh` emits a file's body before recursively flattening its source lines and deduplicates by repository-relative path. Module `index.sh` files must contain only source lines and comments; other statements can run in a different order in the built artifact. Every source file starts with a shebang, which the build strips. See ADR-010.
