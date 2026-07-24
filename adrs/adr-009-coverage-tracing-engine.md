# Coverage Tracing Engine: xtrace fast path with DEBUG-trap fallback

* Status: accepted (direction); implementation deferred to a follow-up
* Date: 2026-07-24
* Spike: #854 · builds on #853 (shelved dedup) and ADR-007/ADR-008

## Context and Problem Statement

Line/branch coverage is driven by a `DEBUG` trap that invokes
`bashunit::coverage::record_line` for **every executed command** (`src/coverage.sh`).
That per-line callback is a full shell-function dispatch, and it dominates the
cost of `--coverage`: on a loop-heavy fixture the whole run takes ~35s, and the
#853 experiment (dedup line hits at source) moved that by ~0s — collapsing ~1500
duplicate records to 1 changed wall time from 35.7s to 34.6s. That negative
result is the proof that the **trap dispatch, not the buffer/disk I/O, is the
bottleneck**. Because coverage is this expensive, it runs nightly and never
gates a PR (`.github/workflows/coverage.yml`).

Question for this spike: can a fundamentally different capture mechanism —
`set -x` writing to a dedicated file descriptor (`BASH_XTRACEFD`) and parsed
offline — make coverage cheap enough to gate, without breaking the Bash 3.0
floor?

## Decision Drivers

* Bash 3.0+ compatibility of the framework core is non-negotiable.
* Coverage output (covered-line set, branch arms, per-test attribution) must be
  preserved bit-for-bit.
* `--parallel` must keep working.
* Must not corrupt test stdout/stderr.

## Measurements (this spike)

Micro-benchmark: an identical 20 000-iteration workload (~80 000 executed
commands) captured three ways — no instrumentation, a `DEBUG` trap that buffers
line numbers like `record_line`, and `set -x` with `PS4='+$LINENO '` redirected
to a file. Timed with `perl Time::HiRes` (bash 3.2/macOS has no `EPOCHREALTIME`).
Script committed at `adrs/assets/adr-009-cov-engine-bench.sh`.

| bash | baseline | DEBUG-trap overhead | xtrace overhead (run+parse) | speedup |
|------|----------|---------------------|-----------------------------|---------|
| 3.2.57 | 0.093s | **+0.855s** (80 005 events) | **+0.127s** (0.116 + 0.011) | **~6.7×** |
| 5.3.15 | 0.082s | **+0.730s** | **+0.131s** (0.120 + 0.011) | **~5.6×** |

Raw trace was ~1.25 MB for 80 k events (~15 B/event) — cheap to stream-parse
(0.011s).

Correctness probe (bash 5, `PS4='@@${BASH_SOURCE}:${LINENO} '`, `BASH_XTRACEFD`
to a dedicated fd): a function exercised down its `else` arm produced a trace
from which the covered-line set reconstructs exactly — the taken `else` line
present, the untaken `if` line absent — and **test stdout/stderr came back with
zero trace lines** (the fd fully separated the trace). So xtrace both captures
accurately and keeps the trace out of the program's own output.

## Considered Options

1. **Keep the DEBUG trap only** — status quo. Simple and Bash 3.0-clean, but ~6× more expensive per line, so coverage stays nightly and non-gating.
2. **Replace the trap with an xtrace engine everywhere** — fastest, but `BASH_XTRACEFD` is **Bash 4.1+**. On Bash 3.0–4.0 xtrace can only go to stderr, where it intermixes with the program-under-test's own stderr and cannot be reliably separated (test output may itself contain `+`-prefixed lines). This breaks the floor.
3. **Hybrid: xtrace fast path on Bash 4.1+, DEBUG-trap fallback below** — `BASHUNIT_COVERAGE_ENGINE=auto|xtrace|trap`, with `auto` picking xtrace iff `BASH_XTRACEFD` is available. Keeps the floor and delivers the ~6× win where the fd exists (all modern CI images and most dev machines).

## Decision Outcome

Chosen: **Option 3 (hybrid)**. The ~6× speedup is real on both Bash 3.2 and 5,
and it is achievable without regressing the Bash 3.0 floor because the slow but
correct trap engine stays as the fallback exactly where the fast fd is missing.
This is the only measured lever that can plausibly make `--coverage` gate PRs
(a ~35s loop-heavy run projects to ~6–8s).

Because the change is large and touches the coverage hot path plus per-test
attribution and `--parallel`, it is **not implemented in this spike** — this ADR
records the validated direction and a follow-up issue carries the build.

### Positive Consequences

* ~6× lower per-line coverage cost on Bash 4.1+; opens the door to gating.
* Trap engine retained → Bash 3.0 floor and current behaviour preserved as the
  fallback and the equivalence oracle.
* The #853 dedup keying (branch `feat/853-coverage-dedup-line-hits`) can be
  reused to de-dup the offline-parsed trace if ever needed (parse was 0.011s, so
  probably not).

### Negative Consequences / Risks (for the implementation issue)

* **Per-test attribution:** the trap sets `_BASHUNIT_COVERAGE_CURRENT_TEST_*`
  per test; xtrace must instead emit a sentinel line into the trace at each
  test boundary and partition the parse by sentinel.
* **Self-instrumentation:** tests that run `set -x` or set their own `PS4` must
  be sandboxed; save/restore `PS4`/`BASH_XTRACEFD` around the test body.
* **`--parallel`:** one trace fd/file per worker, merged like the current
  per-`$$` data files.
* **Framework-line noise:** the trace includes bashunit's own lines (e.g. the
  `set +x` toggle, the call site) — filtered by the existing `should_track`
  path rules, same as the trap.
* **Multi-line / subshell / pipe commands:** `$LINENO` in `PS4` attributes each
  to its own source line; verify against the trap oracle on a fixture corpus.

## Follow-up

* File an implementation issue for the hybrid engine behind
  `BASHUNIT_COVERAGE_ENGINE=auto|xtrace|trap`, gated on byte-for-byte output
  equivalence with the trap engine across the coverage fixture suite, before any
  default flip. Only after that, consider promoting `--coverage` to a gating CI
  job.

## Links

* Spike issue #854; dedup finding #853; branch-coverage ADR-007; per-test
  timing ADR-008.
* `BASH_XTRACEFD` introduced in Bash 4.1 (2009).
