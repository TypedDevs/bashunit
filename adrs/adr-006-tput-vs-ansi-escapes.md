# Keep ANSI for colors, use tput where it pays off

* Status: accepted
* Deciders: @Chemaclass
* Date: 2026-04-29

Technical Story: [#247](https://github.com/TypedDevs/bashunit/issues/247)

## Context

bashunit prints colors and clears the screen with hardcoded ANSI escapes (`\e[31m`, `\033[2J\033[H`). The idea floated in #247 was to switch to `tput`, which reads terminfo and is in theory more portable.

We tried something similar around PR #245 and it broke the test suite across CI envs. Lots of runners ship with `TERM=dumb` or no `TERM` at all, so `tput setaf` returns empty and colored output silently disappears.

So the question is not really "tput or ANSI" but "where does tput actually help us, and where does it just break things?"

## Options

* A. Replace every ANSI escape with `tput`.
* B. Keep ANSI everywhere, change nothing.
* C. Keep ANSI for colors. Use tput only where it gives us something ANSI cannot.

## Decision

Option C.

Reasoning:

* For colors, tput just emits the same ANSI codes we already write by hand. The only thing it adds is breaking on dumb terminals.
* For things ANSI cannot do well, like probing whether the terminal supports color at all, or producing the right "clear screen" sequence on weird terminals, tput is genuinely useful.
* We already use `tput cols` in `src/env.sh` with an ANSI/`stty` fallback. Same pattern fits here.

What this PR does:

1. All color escapes go through `bashunit::sgr` and the `_BASHUNIT_COLOR_*` constants. No more raw `\033[...m` literals in `src/coverage.sh` or `src/main.sh`.
2. New `bashunit::env::supports_color` (false on `TERM=dumb` or `tput colors < 8`). Exposed but not wired into `colors.sh` init yet. The same auto-disable broke CI in PR #245 and again on the first push of this branch, so it waits until we add a `CI` / `FORCE_COLOR` override.
3. New `bashunit::io::clear_screen` runs `tput clear` and falls back to `\033[2J\033[H` if tput is missing or returns nothing. Replaces the hardcoded clear in `--watch` mode.

## Consequences

Good:

* One place to change colors.
* Screen clear works on terminals where the literal ANSI is wrong.
* `supports_color` is ready for the next step (auto-detect with a CI override).

Bad:

* Two mechanisms (constants for colors, tput for clear/probe). Contributors need to know not to add raw escapes back.

## Links

* Issue [#247](https://github.com/TypedDevs/bashunit/issues/247)
* PR [#245](https://github.com/TypedDevs/bashunit/pull/245)
* [NO_COLOR spec](https://no-color.org/)
