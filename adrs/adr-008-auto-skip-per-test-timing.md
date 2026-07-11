# Auto-skip per-test timing when the clock forks an interpreter

* Status: accepted
* Date: 2026-07-11

## Context and Problem Statement

Every test measures its own wall-clock duration: `bashunit::runner::run_test` reads `bashunit::clock::now` once before and once after the test body. On a shell with a native high-resolution clock (`EPOCHREALTIME`, Bash 5.0+) these reads are fork-free. On the default macOS shell (Bash 3.2) there is no `EPOCHREALTIME`, and BSD `date` has no `%N`, so `bashunit::clock::now` falls through to forking a `perl` interpreter for every read.

That is two `perl` process spawns per test. On a ~1200-test suite it is ~2400 `perl` forks and the single largest external cost measured in the runner (~40% of per-test framework overhead on a stock Mac), and it compounds inside every nested `./bashunit` invocation in the acceptance suite.

The duration is only ever consumed by four things: the per-test execution-time column, `--profile`, `--verbose`, and the per-test `duration` recorded in report files (JUnit/JSON/HTML). When none of those is active, the suite pays the `perl` cost and then discards the result.

## Decision Drivers

* The largest available speedup on the framework's own reference platform (Bash 3.2 macOS).
* Bash 3.0+ compatibility: on Bash < 5 there is no way to read a sub-second clock without a subprocess, so the only way to remove the fork is to not measure.
* No behavior change on shells with a cheap clock (Bash 5, Linux CI): timing there is free, so nothing should change.
* Anything that genuinely needs the number (`--profile`, `--verbose`, a report, or an explicit opt-in) must still get an accurate measurement.
* Must be deterministic enough to pin in unit tests.

## Considered Options

1. **Auto-skip based on clock cost** — classify the resolved clock impl as expensive (forks an interpreter: perl/python/node/powershell) or cheap (shell/date). Default per-test timing to `auto`: measure only when a consumer needs it, and on an expensive clock treat display as off unless explicitly enabled. Skip both clock reads when nothing consumes the duration.
2. **Persistent timestamp co-process** — spawn one long-lived `perl` reading timestamps on demand over a FIFO, so the whole suite pays one fork instead of two per test.
3. **Do nothing** — keep measuring unconditionally; accept the `perl` cost.
4. **Always drop per-test timing** — remove per-test measurement on every platform for output consistency.

## Decision Outcome

Chosen option: **Option 1 (auto-skip based on clock cost)**.

`bashunit::clock::is_expensive` reports whether the resolved impl forks an interpreter. `BASHUNIT_SHOW_EXECUTION_TIME` gains an `auto` value and becomes the default: `auto` shows per-test times when the clock is cheap and hides them when it is expensive. `bashunit::runner::needs_test_duration` is true when `--profile`, `--verbose`, any report, or a resolved-on execution-time display needs the number; `run_test` reads the clock only then. On Bash 5 / Linux the clock is cheap, `auto` resolves to shown, and behavior is identical to before. On Bash 3.2 a plain `./bashunit tests/` no longer forks `perl` per test.

### Positive Consequences

* Removes ~2400 `perl` forks from a default suite run on Bash 3.2; largest single speedup in the perf series.
* Zero behavior change on cheap-clock platforms (CI stays byte-identical).
* Opt-in path is intact: `--profile`, `--verbose`, `--report-*`/`--log-junit`, or `BASHUNIT_SHOW_EXECUTION_TIME=true` all force accurate timing back on.

### Negative Consequences

* On Bash 3.2 macOS, a default run no longer shows per-test milliseconds. Users who want them set `BASHUNIT_SHOW_EXECUTION_TIME=true` (and pay the `perl` cost). This is a visible default change, documented in the CHANGELOG and docs.
* `needs_test_duration` must enumerate every duration consumer; adding a new consumer without updating the predicate would make it read a zero duration. Mitigated by keeping all consumers behind the single predicate and testing it.

## Pros and Cons of the Options

### Option 1: Auto-skip based on clock cost (chosen)

* Good, because it removes the fork entirely on the affected platform rather than reducing it.
* Good, because cheap-clock platforms are provably unaffected (the predicate resolves to "measure").
* Good, because the classification is a `case` on a cached global — no per-test cost.
* Bad, because it changes default output on Bash 3.2.

### Option 2: Persistent timestamp co-process over a FIFO

* Good, because it preserves per-test timing everywhere at one fork per suite.
* Bad, because concurrent readers under `--parallel` race on the FIFO and stock macOS has no portable `flock` to serialize them.
* Bad, because co-process lifecycle and cleanup (crash, SIGINT, timeout kills) add real complexity to the hot path for a feature most default runs do not use.

### Option 3: Do nothing

* Good, because zero risk and per-test times always shown.
* Bad, because it forfeits the largest speedup on the reference platform.

### Option 4: Always drop per-test timing

* Good, because output is consistent across platforms.
* Bad, because it discards timing that is free on Bash 5 / Linux, a needless regression there.

## Links

* Issue #765
* Related perf series: #762, #763, #764, #766
