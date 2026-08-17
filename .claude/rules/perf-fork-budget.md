---
paths:
  - "src/**/*.sh"
  - "tests/acceptance/bashunit_*forks*_test.sh"
---

# Performance: Fork Budget & Census Method

bashunit's dominant runtime cost on Bash 3.2 (macOS) is **process forks**, not
shell execution. A fork costs ~1-3ms; the acceptance suite spawns ~258 nested
`./bashunit` runs, so one avoidable fork per file or per test multiplies fast.
PRs #801-#817 removed the per-test, per-file and cold-start forks (the full
`--parallel` acceptance suite went from ~61s to ~17s wall, CPU time halved);
this file records how to measure and the traps found, so future work starts
from evidence.

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

**A shim census only sees forks that exec a binary.** `$(some_shell_function)`
forks a subshell and execs nothing, so it is invisible to every shim and to the
`^\++ +/path/to/binary` trace patterns above — yet it costs the same ~0.6ms.
That blind spot hid sixteen of them in the colour palette (`$(bashunit::sgr N)`
per colour, ~9ms, the largest single cost in a cold start) straight through the
#801-#851 campaign that pinned everything else on this page. To count them,
match the *function name* in the trace (`^\++ +bashunit::fn( |$)`), or profile
by injecting `$EPOCHREALTIME` echoes at the `# src/<path>` markers the build
emits — that attributes startup cost per source file and is how this one
surfaced.

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
| `printf \| grep -cE` per line as a classifier fallback | `case` globs translating each regex alternation | #1005 (286 lines cost 1055 forks) |

`shopt -s extdebug` for `declare -F`: enable it **inside the capture subshell
only** — toggling it in the caller's shell clobbers caller state (#808).

## Where pure bash LOSES — measured, do not "optimize" these

- **`… | awk` over ≳100 lines**: a `while read` loop was 5x slower than the awk
  fork (19ms vs 3.5ms for 600 `declare -F` lines). File scans (provider map,
  duplicate check) stay awk.
- **`${var//pattern/}` on large strings**: quadratic on Bash 3.2 — 2.7 s where
  awk takes 3.5ms. Never string-replace over big captures.
- **Regex assertions** (`assert_matches`): the `grep -E` fork is **not** because
  `[[ =~ ]]` is missing — it was verified working on a real Bash 3.0 build. It is
  because 3.2 changed whether a quoted right-hand side is a regex or a literal,
  so at the 3.0 floor the same pattern would match differently across supported
  versions. Removing the fork means picking one semantic and breaking the other.
  Measured cost of keeping it, so the trade is at least quantified: 2000
  `assert_same` run in ~130 ms (0.065 ms each), 500 `assert_matches` in ~1.25 s
  (**2.5 ms each, ~38x**). That is the fork, and it is the price of the 3.0
  floor -- not a regression to chase.
- **Single-file build artifact**: sourcing `bin/bashunit` is *not* faster than
  sourcing `src/*.sh` (parse time dominates, file opens don't).
- **`tput cols` at startup**: returns 80 on non-tty; snapshots depend on that
  width. Not removable.

## Estimating: three ways an estimate lied, all in one day

The coverage work in #1084-#1112 produced three wrong predictions, each of
which cost a full implement-and-measure cycle. Check against these before
believing a number.

- **A micro-benchmark of a function the DEBUG trap calls overstates the win.**
  A same-file memo for `record_line`'s path lookups predicted 5x from a loop
  benchmark and delivered **4%** in situ (#1102). Whatever the trap costs
  around the call swamps what the call itself costs.
- **Stubbing tells you what a stage costs, not what removing a syscall from it
  saves.** Returning early from `record_line` attributed 705 ms to its two
  `>>` appends; holding the files open on persistent descriptors recovered
  **184 ms** of it, not 705 (#1110).
- **A benchmark path must be the path that occurs.** `${file//[^a-zA-Z0-9]/_}`
  costs 7.8 µs at 7 characters, 131 µs at 59 and 549 µs at 121 — so measuring
  it with an absolute path when the trap actually sees `./src/x.sh` inflated
  the estimate by 4x (#1102).

**A/B in the same tree.** Comparing a worktree under `/private/tmp` against the
repo under `/Users` made a 70 ms *improvement* read as a 40 ms regression.
Check out the two versions of the file into one tree and alternate rounds.

## Process substitution as an argument fails under load

`cmd <(a) <(b)` passes `/dev/fd/N` paths that **`cmd` itself must open**. Under
a loaded parallel suite that open fails:

```
diff: /dev/fd/62: Bad file descriptor
```

`diff` then produces no comparison and writes that to stderr, which a caller
collecting output reads as a real difference. Both coverage differentials did
this once per repo file — 473 iterations — and failed roughly 1 full suite run
in 3, each time reporting "the classifiers disagree" over a file that agreed
perfectly (#1152). Two earlier attempts blamed `awk`; the `AWK-FAILED` marker
from #1143 is what finally ruled it out.

The redirect form `while read …; done < <(cmd)` is **not** the same shape: the
shell opens the descriptor and dups it to stdin, so no external process opens
`/dev/fd/N`. It is used throughout `src/` and has never been seen to fail.

So: never put `<(...)` in an external command's **argument list** inside a loop
that runs per file or per test. Write real files (concurrently, so the two
sides still overlap — serialising them was measurably slower) and compare with
`[ "$a" != "$b" ]`, which the shell does without a fork.

## Where pure bash LOSES on some Bash versions but not others

- **`${var//&/…}` is not portable.** Bash 5.2 made a bare `&` in a substitution
  REPLACEMENT mean "the matched text", so `${line//</&lt;}` yields `<lt;` on
  5.2+ while producing `&lt;` on 3.2 and 4.4. Escaping it as `\&` for 5.2 emits
  a literal backslash on 3.2. There is no spelling that is right across the
  supported range, and **both failure modes are silent** — this is why HTML
  escaping goes through `awk` and not parameter expansion (#1096). Grep for
  `&` in any replacement before writing one.
- **`${var//#/…}` does not substitute on Bash 3.0.** The `#` right after `//`
  is read as the anchor-to-start syntax with an empty pattern, so the
  replacement is *prepended* and the text is left alone: `check # SKIP me`
  became `\#check # SKIP me`. Write the pattern as `[#]` (or quote it), which
  means the same thing on 3.0, 3.2, 4.4 and 5 (#1119). Same family as the `&`
  trap above: silent, and only on some versions.
- **`\x` escapes are not POSIX awk.** They happen to work in macOS awk,
  BusyBox awk and mawk, but pass the byte in with `-v` instead of relying on
  it (#1098).
- **The DEBUG trap does not reach a subshell before Bash 4**, even under
  `set -T`. Anything measuring or recording per executed line will see fewer
  lines on Bash 3.x, and no amount of buffering or flushing changes that
  (#1101, #1112).

## Where the time actually goes, per test vs per assertion

Measured on macOS, sequential, fork-free paths (repeat before trusting; single
runs vary):

| shape | wall | per unit |
|---|---|---|
| 1 test, 500 `assert_same` | ~73 ms | **0.15 ms** per assertion |
| 500 tests, 1 assertion each | ~3.9 s | **7.8 ms** per test |
| 2000 `assert_same` | ~130 ms | 0.065 ms |
| 500 `assert_matches` | ~1.25 s | 2.5 ms (the `grep -E` fork) |

**A test costs ~50x an assertion.** Shaving microseconds off an assertion is
close to pointless next to anything that touches the per-test path -- which is
why #801-#851 went after per-test forks and not the assertion layer.

Two things that were checked and are *not* the explanation, so nobody re-checks
them:

- **Not forks.** A PATH-shim census over 30 binaries counts **12 forks for 500
  tests** (3 perl, 2 rm, 2 awk, and one each of uname/tput/mkdir/bc/base64).
  The per-test path is genuinely fork-free.
- **Not the capture subshell.** A bare `$( )` costs ~0.46 ms here, about 6% of
  the 7.8 ms. The rest is bash work in the per-test machinery.
- **Not quadratic.** Per-test cost is 7.17 ms at 100 tests and 8.06 ms at 1000
  -- +12% over a 10x range, so the #830 fn-accumulation fix still holds. A
  regression there would show as per-test cost climbing with suite size.

No win was found in this pass; the numbers are here so the next attempt starts
from them rather than re-deriving them.

## Current budgets (Bash 3.2 macOS)

**Sequential 1-test file run:** 2 `awk` (provider map — built once in the main
shell since #817, the header count reads a return slot so the cache survives
into the runner — plus the duplicate check), `perl` ×2 clock reads (start/end;
no `EPOCHREALTIME` before Bash 5), 1 `base64` capability probe, 1 `mkdir`,
1 `tput`. Per-test cost is fork-free.

**Cold start: 3 binary forks** — `uname` (OS detect), `tput` (snapshot width),
`perl` (clock before Bash 5). It was 5 until #1124: `check_os::init` ran twice,
once at source time and again from the entrypoint, and `BASHUNIT_ROOT_DIR` came
from `$(dirname …)`. Plus a handful of *subshell* forks no shim census sees
(see the blind-spot note above); the sixteen in the palette are gone.

Sourcing `src/` is the rest of it, and it is **not** all irreducible — that was
assumed here until a per-source-file profile disproved it. Measured on macOS
with the `# src/<path>` marker technique: 41.6ms of executed top-level code,
against 10ms to parse the whole 600KB artifact and define all 915 functions.
Parsing is cheap; what runs at source time is not. The current shape is
`config/env.sh` ~12.6ms (config files, `tput`, `mkdir`), `state/payload.sh`
~2.9ms (the `base64 --help` probe) and `system/check_os.sh` ~2.4ms (`uname`).
Lazy-loading whole modules was still rejected in #798.

Measuring a change this small needs ~200 invocations per sample: the two forks
are ~4ms against a ~65ms startup, and single runs vary by ±10ms. The acceptance
suite is useless for it — consecutive runs there differ by 5s.
`--coverage` adds ~3 forks per unique file first seen by the DEBUG trap
(decision-cache miss: grep|head + dirname) — bounded by file count, nightly
non-gating workflow, not worth chasing.

**Don't assume the engine is the cost.** Profiling `--coverage` for #1005 found
the *report* phase was ~50-60% of wall time and identical for both engines: the
per-line executable/non-executable classifier fell back to a `grep -E` fork for
every line it could not decide in pure Bash, and every tracked line is classified
twice per run (`precompute_file_stats`, then `report_lcov`). Budget guarded by
`tests/acceptance/bashunit_coverage_forks_test.sh`, expressed as "fork count does
not grow with source-line count" rather than an absolute number.

Two traps when replacing a regex classifier with `case` globs — both silently
change coverage numbers rather than erroring:

- Inside a POSIX bracket expression a backslash is a **literal member of the
  set**, so `[^\)]` excludes `\` as well as `)`. `x=$(foo)` and
  `x=$(printf '%s\n')` therefore classify differently.
- `[\{\}]` likewise matches a lone `\`, so a bare line continuation counts as a
  brace-only line.

Verify such a rewrite by running both implementations over the same input
(`git show HEAD:<file>` + `declare -f | sed` to alias the old one) across every
`git ls-files '*.sh'` line, and mutation-test the harness itself — a differential
that cannot fail proves nothing.

**Parallel 10-test file run (CI's mode):** ~11 forks — 3 `mkdir`, 4 `rm`,
3 `awk` (#813; was 61). The per-test result file is named by a per-suite
ordinal the single-threaded dispatcher assigns just before each `&` (the fork
inherits it), so it costs **no** `mktemp` + `mv` per test (#851; was 10
`mktemp` + 10 `mv`). This replaced the old sanitized-test-name scheme, whose
deterministic names could collide (different provider args sanitize identically)
because Bash 3 workers can't mint a unique token — subshells inherit `$$` and
the `RANDOM` state, and `BASHPID` is 4.0+; an ordinal sidesteps that entirely.
`wait_for_job_slot` already uses `wait -n` on Bash 4.3+ and an adaptive
sleep-poll fallback — don't "fix" it. The spinner forks `sleep` ~1/s on
non-tty; not worth chasing.

**Reports are on the per-test path too.** Any `--log-*`/`--report-*` flag makes
each worker spool a result row, and that row used to base64 each of its nine
fields on its own — 14 `base64` forks per test counting the parent's decode,
with a `tr` on each encode. `--log-junit` therefore cost more than the run it
reported on (300 tests: 1.2s → 9.2s wall, 5.8s → 27.4s CPU). Now only the four
fields that can hold arbitrary text are encoded and the row is joined with
0x1F. The main workflow passes no report flag, so CI never showed this; the
budget is guarded by `bashunit_run_forks_test.sh`. When adding a field to that
row, ask whether it can hold arbitrary text before reaching for base64.
