# Hybrid tput + ANSI for terminal output

* Status: accepted
* Deciders: @Chemaclass
* Date: 2026-04-29

Technical Story: [#247](https://github.com/TypedDevs/bashunit/issues/247) — evaluate replacing hardcoded ANSI escape sequences with `tput` (terminfo).

## Context and Problem Statement

bashunit emits colored output and screen-clear sequences via hardcoded ANSI escapes (`\e[31m`, `\033[2J\033[H`). `tput` queries the `terminfo` database, adapting to terminal capabilities and providing safer, more portable codes. A previous attempt to fully migrate to `tput` (around PR #245) caused widespread test instability across CI environments, so any move toward `tput` must be incremental and reliable.

Should bashunit replace ANSI escapes with `tput`?

## Decision Drivers

* Bash 3.0+ portability (macOS, Linux, BSD, Windows runners)
* Reliability across CI matrices (GitHub Actions, dumb terminals, non-TTY pipelines)
* Minimal behavioral churn — tests and snapshots must keep passing
* Single source of truth for color/control sequences
* Auto-disable color when terminal does not support it (avoid garbled output)

## Considered Options

* A. Full migration: replace every ANSI escape with `tput`
* B. Status quo: keep ANSI everywhere
* C. Hybrid: keep ANSI as primary mechanism via centralized helper, adopt `tput` for capability probing and select control sequences (e.g. screen clear)

## Decision Outcome

Chosen option: **C. Hybrid**.

Rationale: ANSI SGR codes are stable and identical to what `tput setaf` emits on color terminals, so a wholesale `tput` rewrite buys little while introducing the failure modes that broke the previous attempt (e.g. `tput` returning empty strings under `TERM=dumb`, missing `terminfo` entries on stripped-down CI images, subprocess overhead per call). The real wins from `tput` are (1) capability probing (`tput colors`) to auto-disable color when unsupported and (2) portability for non-color sequences like screen clear. We adopt those targeted uses while keeping the existing centralized `bashunit::sgr` helper as the only emitter of color escape sequences.

Concretely:

1. Keep `bashunit::sgr` and `_BASHUNIT_COLOR_*` constants as the only place that emits color sequences. All ad-hoc `\033[...m` literals in `src/` are migrated to these constants.
2. Add `bashunit::env::supports_color` that returns false when `TERM=dumb`, `NO_COLOR` is set, or `tput colors` reports fewer than 8 colors. Wire this into `colors.sh` so colors auto-disable.
3. Replace the hardcoded `printf '\033[2J\033[H'` screen clear with `tput clear` when available, falling back to the ANSI sequence otherwise.
4. `tput` is already used for `tput cols` in `src/env.sh:215-219` — that pattern (probe + ANSI fallback) is the model.

### Positive Consequences

* One place (`bashunit::sgr` + `_BASHUNIT_COLOR_*`) to change colors.
* Color auto-disables on dumb terminals and non-TTY pipelines without requiring `--no-color`.
* Screen clear works on terminals where the hardcoded sequence is wrong.
* No subprocess explosion: `tput` is invoked once at init for capability probing, not per emitted color.
* Avoids the failure mode from the previous attempt (per-call `tput setaf` returning empty strings under unusual `TERM` values).

### Negative Consequences

* Slight init-time cost for the `tput colors` probe.
* Test suite must mock `tput` in scenarios that depended on guaranteed-color output. Existing tests already mock `tput` for `find_terminal_width` (see `tests/unit/env_test.sh:144`), so the pattern is established.

## Pros and Cons of the Options

### A. Full migration

* Good, because terminfo is the canonical Unix way to handle terminals.
* Good, because `tput` adapts to capability quirks (e.g. 8 vs 256 colors).
* Bad, because the previous attempt destabilized CI tests across environments.
* Bad, because every color emission becomes a subprocess call (`$(tput setaf 1)`), measurable overhead in tight loops like the runner output.
* Bad, because `terminfo` databases on minimal CI images may lack capabilities, returning empty strings and silently breaking output.

### B. Status quo

* Good, because it is known to work across the entire current CI matrix.
* Bad, because color does not auto-disable on dumb terminals.
* Bad, because ad-hoc `\033[...m` literals in `coverage.sh` and `main.sh` bypass the centralized helper.

### C. Hybrid (chosen)

* Good, because it gets the practical benefits of `tput` (capability probing, portable control sequences) without the per-emission failure modes.
* Good, because it consolidates color emission through one helper, simplifying future changes (themes, 256-color, truecolor).
* Good, because it aligns with the existing `tput cols` pattern in `env.sh`.
* Bad, because two mechanisms coexist; contributors must know to use the constants, not raw escapes. Mitigated by lint/grep rules and code review.

## Links

* [Issue #247](https://github.com/TypedDevs/bashunit/issues/247)
* [PR #245 — Increase contrast of test results](https://github.com/TypedDevs/bashunit/pull/245)
* [terminfo(5) man page](https://man7.org/linux/man-pages/man5/terminfo.5.html)
* [NO_COLOR specification](https://no-color.org/)
