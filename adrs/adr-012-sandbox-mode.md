# Sandbox mode: how an unmocked external command is blocked

* Status: accepted
* Deciders: bashunit maintainers
* Date: 2026-08-11

Technical Story: https://github.com/TypedDevs/bashunit/issues/1022

## Context and Problem Statement

Nothing stopped a test from calling a real command. A test that means to
exercise a mocked `curl`, but has a typo in the mock name — or whose mock a
previous `bashunit::unmock` removed — hits the network and **passes**: slowly,
non-deterministically, and differently in CI. The same holds for `git`, `aws`,
`docker` and `rm`.

`--sandbox` has to make that a failure. The question is by what mechanism, in a
framework whose floor is Bash 3.0 and whose own code shells out to `awk`, `sed`
and friends *while a test runs*.

## Decision Drivers

* The failure must name the command, or the report sends the reader hunting.
* It must hold when the test redirects stderr or ignores an exit status —
  `curl … 2>/dev/null` followed by a passing assertion is the exact case that
  motivated the feature.
* Bash 3.0: no `command_not_found_handle` (4.0+), no `declare -A`.
* The suite runs under Spanish, Japanese and Brazilian locales in CI, so no
  mechanism may depend on the wording of a shell diagnostic.
* The framework must keep working while a test is sandboxed.
* Cost is paid only by runs that ask for it, but must not be absurd there.

## Considered Options

* Empty (or narrowed) `PATH`, the way shellspec does it
* A `command_not_found_handle` hook
* A shell function per blocked command
* A `DEBUG` trap inspecting `$BASH_COMMAND`

## Decision Outcome

Chosen: **a shell function per blocked command, plus a narrowed `PATH`** — the
two cover different halves of the problem.

1. **Function shims.** `prepare` walks `PATH` once in the main shell and
    defines, for every executable the run does not allow, a function that
    records the command in a per-test file, prints a message naming it, and
    returns 127. Bash resolves functions before `PATH`, so a direct call from
    a test body lands there. A mock is itself a function, so mocking a command
    simply replaces the shim, and `bashunit::unmock` puts the shim back rather
    than handing the test the real command.
2. **Narrowed `PATH`.** Inside the capture subshell, `PATH` becomes a directory
    of symlinks to the allowed commands. Functions do not survive into a child
    process, so `bash -c 'curl …'` would escape layer 1; the environment does
    not.

The verdict crosses the fork through the payload: `cleanup_on_exit` sets the
test's exit code to 127 when the violation file is non-empty, because a
`--parallel` worker's counters never reach the parent — only its encoded
result does.

### Positive Consequences

* The message names the command and is the framework's own text, so it is
  identical in every locale.
* A blocked call is caught even when the test swallows both the output and the
  status: the record is a file, written before either can be discarded.
* `--sandbox` composes with `--coverage`, which owns the `DEBUG` trap.
* Nothing changes for a run without the flag: `prepare` returns immediately.

### Negative Consequences

* A run with `--sandbox` pays one `PATH` walk (~1800 entries, ~50 ms on a
  developer machine, no fork) plus one symlink per allowed command.
* A command invoked by absolute path (`/usr/bin/curl`) is not blocked. Neither
  mechanism can see it; documented rather than pretended away.
* A command that appears in `PATH` only after the run started is not shimmed.
* The allowlist is a baseline of what bashunit itself needs, so a test using
  `sed` directly is not blocked. The goal is to constrain the test body's
  reach to *services*, not to sandbox coreutils away from it.

## Pros and Cons of the Options

### Empty PATH alone (shellspec's approach)

* Good, because it is two lines and follows a test into child processes.
* Good, because the framework's own pinned binaries (`$GREP`, `$MKTEMP`,
  `$CAT`) are absolute and unaffected.
* Bad, because the only signal is bash's own `command not found`, whose text is
  translated — the locale jobs would report nothing.
* Bad, because a test that redirects stderr and ignores the status hides the
  violation entirely.

### command_not_found_handle

* Good, because it names the command precisely and fires on every miss.
* Bad, because it does not exist before Bash 4.0, and the floor is 3.0 — the
  Bash 3.0 CI job is where it would silently do nothing.

### DEBUG trap on $BASH_COMMAND

* Good, because it sees a call before it happens, and can block builtins too.
* Bad, because `--coverage` already owns the `DEBUG` trap: the two features
  would become mutually exclusive.
* Bad, because it fires on every command of every test, not only on the misses.

### Function shims (chosen, with narrowed PATH)

* Good, because the failure is produced by our code: precise, translated
  nowhere, recorded in a file that redirection cannot reach.
* Good, because mocks and shims are the same kind of object, which is what
  makes the `unmock` semantics obvious.
* Bad, because ~1800 function definitions cost ~50 ms at startup and live in
  the shell for the rest of the run.
* Bad, because functions do not cross into child processes — hence layer 2.

## Links

* Implemented in `src/runner/sandbox.sh`
* Related: [ADR-009](adr-009-coverage-tracing-engine.md) — the other feature
  that would have wanted the `DEBUG` trap
