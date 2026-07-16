---
paths:
  - "src/**/*.sh"
  - "tests/acceptance/bashunit_*forks*_test.sh"
---

# Performance: Fork Budget & Census Method

bashunit's dominant runtime cost on Bash 3.2 (macOS) is **process forks**, not
shell execution. A fork costs ~1-3ms; the acceptance suite spawns ~258 nested
`./bashunit` runs, so one avoidable fork per file or per test multiplies fast.
PRs #801-#811 removed the per-test and cold-start forks; this file records how
to measure and the traps found, so future work starts from evidence.

## Measuring: shim census is ground truth, traces overcount

**PATH-shim census (authoritative).** Wrap a binary, count invocations:

```bash
real_awk="$(command -v awk)"          # resolve BEFORE prepending the shim dir
printf '#!/usr/bin/env bash\necho x >> /tmp/count\nexec "%s" "$@"\n' "$real_awk" > shim/awk
chmod +x shim/awk
PATH="shim:$PATH" ./bashunit --no-parallel fixture_test.sh
grep -c . /tmp/count
```

Caveats: binaries pinned at startup via `command -v` (`$GREP`, `$MKTEMP`,
`$CAT`) bypass PATH shims — trace those instead; and shims are unreliable on
Git Bash (skip such tests on Windows).

**`bash -x` trace census (cheap but inflated).** `PS4='+ ' bash -x ./bashunit …`
also counts trace lines **re-echoed inside captured test output**, so it can
overcount 10-20x (one real `grep` appeared 24 times). Use it to *locate* fork
sites (`PS4='+X ${BASH_SOURCE##*/}:$LINENO> '`), never to *count* them. It also
misses forks inside `--parallel` workers. Anchor real execs with
`grep -cE '^\++ +/[^ ]*mktemp$'`-style patterns (absolute path, exact argv
shape) to skip `command -v` probes and variable assignments.

**Regression tests.** Budgets are enforced in
`tests/acceptance/bashunit_coldstart_forks_test.sh` (cold start: mktemp/perl/
grep/mkdir) and `tests/acceptance/bashunit_run_forks_test.sh` (run path:
grep/cat/sed/sort/awk budget, run-dir cleanup). Extend these when you remove a
fork class; they are the RED test of the TDD cycle.

## Replacement patterns that worked

| Fork | Replacement | Example |
|------|-------------|---------|
| `echo x \| grep -c fixed` | `case` glob match | #803, #804 |
| `cat <<EOF` heredoc emit | `printf '%s\n' "$payload"` | #806 (was 1 fork/test) |
| `sed -n Np` per line in a loop | one `while IFS= read -r` pass over the file | #807 (quadratic → flat) |
| `declare -F \| awk '{print $3}'` | `compgen -A function` builtin (identical output) | #810 |
| small-list `awk \| sort \| awk` | pure-bash filter + insertion sort | #809 (tens of items only) |
| N × `mktemp` scratch files | one run-unique dir + fixed names, lazy `>>` creation | #801, #811 |
| probe fork + first-use fork | probe does the real work and seeds the return slot | #802 (clock perl) |
| per-worker `mkdir -p` | parent pre-creates before spawning workers (`[ -d ]` inside a worker races its siblings) | #813 |
| sanitize-args pipeline on empty input | guard: skip the pipeline when the input is empty | #813 |

`shopt -s extdebug` for `declare -F`: enable it **inside the capture subshell
only** — toggling it in the caller's shell clobbers caller state (#808).

## Where pure bash LOSES — measured, do not "optimize" these

- **`… | awk` over ≳100 lines**: a `while read` loop was 5x slower than the awk
  fork (19ms vs 3.5ms for 600 `declare -F` lines). File scans (provider map,
  duplicate check) stay awk.
- **`${var//pattern/}` on large strings**: quadratic on Bash 3.2 — 2.7 s where
  awk takes 3.5ms. Never string-replace over big captures.
- **Regex assertions** (`assert_matches`): Bash 3.0 has no `[[ =~ ]]`; the
  `grep -E` fork is mandatory.
- **Single-file build artifact**: sourcing `bin/bashunit` is *not* faster than
  sourcing `src/*.sh` (parse time dominates, file opens don't).
- **`tput cols` at startup**: returns 80 on non-tty; snapshots depend on that
  width. Not removable.

## Current budgets (Bash 3.2 macOS)

**Sequential 1-test file run:** ~3 `awk` (provider map ×2 — the counting
subshell can't share its cache with the runner — plus the duplicate check),
`perl` ×2 clock reads (start/end; no `EPOCHREALTIME` before Bash 5), 1 `base64`
capability probe, 1 `mkdir`, 1 `tput`. Per-test cost is fork-free. Cold start
~50ms, ~31ms of which is sourcing `src/` (irreducible without lazy-loading,
rejected in #798).

**Parallel 10-test file run (CI's mode):** ~21 forks — 10 `mktemp` (one per
test: the unique result file; deterministic names collide because different
provider args can sanitize identically and workers can't make unique tokens on
Bash 3 — subshells inherit `$$` and the `RANDOM` state, and `BASHPID` is 4.0+),
3 `mkdir`, 4 `rm`, 3 `awk` (#813; was 61). `wait_for_job_slot` already uses
`wait -n` on Bash 4.3+ and an adaptive sleep-poll fallback — don't "fix" it.
The spinner forks `sleep` ~1/s on non-tty; not worth chasing.
