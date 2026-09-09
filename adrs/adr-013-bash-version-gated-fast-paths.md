# Bash version-gated fast paths

* Status: accepted
* Date: 2026-09-09

## Context and Problem Statement

bashunit supports Bash 3.0, so it forks where a newer shell has a builtin. Until now there was no way to ship a faster body for a newer shell: `tests/unit/project/bash_compatibility_test.sh` rejects a too-new construct anywhere in `src/`, including inside a branch that Bash 3.0 never takes. The rule is deliberately blunt, because the Bash 3.0 CI job only catches a too-new construct when a test happens to execute the line.

The cost of not having the mechanism is measured in forks. A fork is worth 1 to 3 ms; the whole per-test framework overhead is around 5 ms. So a single gated helper that removes a fork on the shell most users run is worth more than every micro-optimisation in the same file put together.

This ADR records the mechanism, and the rule a gate must obey. **The floor does not move: Bash 3.0 keeps working, and keeps being tested.**

## Decision Drivers

* A newer shell should use the fastest construct it offers; 3.0 must still run everything.
* The compatibility rules must stay blunt for ungated code. A gate is the only exception, and it has to be a structural fact rather than an author's claim.
* Selection must cost nothing per call.
* A gate may change speed. It may never change observable behaviour.
* The build must emit a gate intact, and the artifact must parse on every supported version.

## Considered Options

1. **Load-time `if/else` around two function definitions**, keyed on a flag file that declares one flag per version boundary in use.
2. **Runtime predicate per call**, the pattern the five existing version checks use.
3. **A per-file allow-list** in the compatibility test.
4. **A trailing pragma** such as `# bashunit: bash4` on the offending line.

## Decision Outcome

Chosen option: **Option 1**.

`src/system/bash.sh` declares one flag per boundary in use, named for its tier: `_BASHUNIT_BASH_GE_31`. A leaf module then picks between two bodies at load time:

```bash
if [ "$_BASHUNIT_BASH_GE_31" = 1 ]; then
  function bashunit::str::lpad_to_slot() {
    printf -v _BASHUNIT_STR_LPAD_OUT "%${1}s" "$2"
  }
else
  function bashunit::str::lpad_to_slot() {
    _BASHUNIT_STR_LPAD_OUT=$(printf "%${1}s" "$2")
  }
fi
```

Measured per-call overhead above a single ungated definition, best of 5 over 100k calls:

| Shape | 3.0 | 4.0 | 5.2 | 5.3 |
|---|---|---|---|---|
| Top-level `if/else`, definition picked once | +0.09 | -0.05 | 0.00 | -0.07 |
| `case` on a memoized impl, per call | +1.7 | +1.2 | +0.8 | +1.2 |
| Predicate function per call | +17.9 | +8.9 | +5.0 | +4.3 |

Selection is free; the pattern already in use is the slow one. Converting the five existing runtime predicates is not part of this decision — they are correct, and 0.1% of a test.

### What may sit behind a gate

Measured on a real Bash 3.00.22 and 3.2.57, with each construct placed both inside `if false; then … fi` and inside an uncalled function. Dead-code safety did not depend on the shape; the two behaved identically in every case.

**Parse-time. Can never sit behind a gate**, because they kill the file even where nothing reaches them: `&>>`, `|&`, `;;&`, `;&`, `arr+=(x)`. `arr+=(x)` is the trap, since it is a parse error on 3.0 only and parses fine on 3.2, so a green macOS run says nothing about it.

**Runtime-only. Safe inside an untaken branch**: `${v,,}`, `${v^^}`, `${v@Q}`, `mapfile`, `declare -A`, `declare -n`, `local -n`, `exec {fd}>`, `printf -v`, `x+=y`, `coproc`, `wait -n`, `BASHPID`, `SRANDOM`, `EPOCHREALTIME`, fractional `read -t`, `${arr[-1]}`, `${ cmd; }`.

### The rule a gate must obey

**A gate may change speed. It may never change observable behaviour.**

That is not a slogan, and the textbook example breaks it: `${v,,}` and `tr '[:upper:]' '[:lower:]'` disagree on non-ASCII. BSD `tr` folds `ÑÜ`, GNU and busybox `tr` do not, and `${v,,}` folds under `C.UTF-8` but not under `C` (#1351). So a gated helper needs either an equivalence test over its real input domain, or a documented contract narrow enough to be portable.

The first gated helper was chosen to make this easy to hold: both bodies hand the same format and the same value to the same `printf`, so the output is identical by construction and the only difference is the fork.

A gated helper also needs a **branch-selection test**, asserting the running shell got the body its tier calls for. Without it a gate that silently always falls back passes every equivalence test while delivering none of the speed. Introspect with `type`, not `declare -f`: real Bash 3.0 refuses a `::` name there.

### Where a gate may live

In a **leaf module**, at column 0, per ADR-011. Not in an `index.sh`: `build::process_file` emits an aggregator's body before the files it sources, so a gate there works in dev mode and exits 127 from the built artifact on Bash 5.2 while passing on 3.2 — invisible on the reference platform.

Column 0 is also what the compatibility test recognises. An indented header is a runtime condition inside some other block, so its body is parsed on every shell and reached whenever that block runs; it gates nothing.

### How the compatibility test enforces it

Each rule declares the construct's minimum version as a tier: `printf -v` is 31, `declare -A` is 40, `${arr[-1]}` is 43. A construct is allowed only when the offending line sits in the then-branch of a column-0 `if [ "$_BASHUNIT_BASH_GE_NN" = 1 ]; then` whose `NN` is at least that tier, closed by a column-0 `else` or `fi`.

A tier of 0 means no gate is ever enough. That covers the parse-time constructs, and also the rules whose boundary is not established — `[[ =~ ]]` changed semantics between 3.0 and 3.2 rather than gaining a version, and the temporary-locale prefix is a Bash 5.3.9 segfault, not a feature.

The tier lives in the flag name so the comparison is textual, and a separate test asserts every flag a gate names is one the flags file declares — a typo would leave the flag empty, the fast body unreachable and the fallback in use everywhere: green, slower, and invisible in review.

### Positive Consequences

* A newer shell can skip a fork that the 3.0 floor requires, without moving the floor.
* Selection costs nothing per call, unlike the runtime-predicate pattern.
* The compatibility rules stay blunt for everything that is not gated, and now say what version each construct needs rather than only that it is banned.
* `test_every_src_file_parses_with_the_running_bash` makes the parse-time class explicit on the macOS 3.2 and real-3.0 jobs.

### Negative Consequences

* A gated helper is two bodies to keep in step, and only tests hold them together.
* The build embeds both, so a gated function is defined twice by design. `build_test.sh`'s column-0 duplicate guard cannot see either body, so a second guard caps every name at two definitions whatever the indentation.
* The recogniser accepts exactly one header spelling. A near-miss gates nothing, which fails closed but can read as a puzzling rejection.

## Pros and Cons of the Options

### Option 1: Load-time `if/else` on a declared flag (chosen)

* Good, because selection is free and the fast body can remove a fork.
* Good, because the gate is a structural fact the test can recognise, not a claim it has to trust.
* Good, because it survives the build byte-for-byte and the artifact parses on 3.0, 3.2, 4.4, 5.2 and 5.3.
* Bad, because it doubles the bodies of a gated helper.

### Option 2: Runtime predicate per call

* Good, because it needs no new mechanism; five already exist.
* Bad, because it costs +17.9 microseconds per call on Bash 3.0, the platform least able to spare it.
* Bad, because the too-new construct still sits in a body the compatibility test rejects, so it does not solve the problem this ADR is about.

### Option 3: Per-file allow-list

* Bad, because an ungated construct elsewhere in the same file then ships, which is exactly the gap the rules exist to close.

### Option 4: Trailing pragma

* Bad, because it is the author's claim rather than a structural fact, so honouring it is a smuggling path by construction.
