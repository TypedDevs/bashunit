---
paths:
  - "src/**/*.sh"
  - "tests/**/*.sh"
---

# Bash Style & Compatibility Rules

## Bash 3.0+ Compatibility (Critical)

bashunit must work on **Bash 3.0+**. The floor was deliberately lowered from 3.2
to 3.0 in 0.33 to reach older systems; macOS's 3.2 is the common case, not the
floor. The runtime gate in `./bashunit` compares major **and** minor against
`BASHUNIT_MIN_BASH_VERSION`, so the declared floor is the enforced one.

These are **version-breaking** above the floor and are prohibited. They are
enforced mechanically by `tests/unit/bash_compatibility_test.sh`, which greps
`src/` regardless of test coverage:

| Feature | Bash ver | Alternative |
|---------|----------|-------------|
| `printf -v` | 3.1+ | Return-slot pattern (below) |
| `+=` (append assign) | 3.1+ | `var="$var$more"`, `arr[${#arr[@]}]=x` |
| `declare -A` (associative arrays) | 4.0+ | Parallel indexed arrays |
| `${var,,}` / `${var^^}` (case) | 4.0+ | `tr '[:upper:]' '[:lower:]'` |
| `${array[-1]}` (negative index) | 4.3+ | `${array[${#array[@]}-1]}` |
| `&>>` (append both) | 4.0+ | `>> file 2>&1` |
| `BASHPID` | 4.0+ | fork (`mktemp`) or an assigned ordinal |
| `mapfile` / `readarray` | 4.0+ | `while IFS= read -r` |
| `declare -n` / `local -n` (nameref) | 4.3+ | Return-slot pattern (below) |
| `coproc` | 4.0+ | — |
| `${var@Q}` (transformations) | 4.4+ | — |

`[[ =~ ]]` is a subtler case: it **exists** on 3.0 (verified against a real
build), but 3.2 changed whether a quoted right-hand side is a regex or a
literal. At a 3.0 floor the same match therefore behaves differently across
supported versions, so regex matching goes through `grep -E` — a real
constraint, not a style preference. See `.claude/rules/perf-fork-budget.md`.

### Style, not compatibility

Prefer `[ ]` over `[[ ]]` for ordinary tests. This is **house style**: `[[ ]]`
itself works on every supported bash, including 3.0. Do not justify it as a
Bash 3 requirement, and do not add it to the compatibility gate.

## Coding Conventions

- **2 spaces** indent, no tabs — enforced by `make lint` (EditorConfig). Do **not**
  run `shfmt -w`: it wants tabs for `tests/acceptance/**` and collapses
  `\`-continued strings past the 120-char limit, breaking `make lint`
- **120 chars** max line length (soft)
- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Always quote variables unless explicit word splitting is needed
- Use `$()` for command substitution, never backticks

### Naming

- **Public functions:** `bashunit::function_name`
- **Private functions:** `_function_name` (leading underscore)
- **Local variables:** `lowercase_with_underscores`
- **Globals/exports:** `UPPERCASE_WITH_UNDERSCORES`

### Function Docs (public functions)

```bash
##
# Brief description
# Arguments: $1 - desc, $2 - desc (optional, default: "x")
# Returns: 0 success, 1 failure
##
```

### File Structure

Constants -> Globals -> Private functions -> Public functions

Source deps relative to script: `"$(dirname "${BASH_SOURCE[0]}")/dep.sh"`

## Returning values from a helper (dynamic-scope safety)

Bash `local` is **dynamically scoped**, not lexically scoped. A `local` inside a callee
shadows the caller's same-named variable for the duration of the call. Same trap fires
with `${!name}` reads and `eval "$name=..."`/`printf -v "$name"`/`export "$name"=...`
writes — they all resolve against the dynamic scope.

We need **all three** properties on the hot path:

1. **No subshell fork.** Returning via stdout and capturing with `$(...)` costs a fork
  per call, which dominates per-test cost.
2. **No collision with caller locals.** A helper that silently overwrites or reads
  the wrong variable is the worst kind of bug — no error, just stale data.
3. **Bash 3.0+ portable.** Rules out `declare -n` (4.3+) and `printf -v` (3.1+, and
  it has the same dynamic-scope shadowing as `eval "$name=..."` anyway).

### Preferred: dedicated global return slot

```bash
_BASHUNIT_PKG_THING_OUT=""

# Writes the result into _BASHUNIT_PKG_THING_OUT.
# Arguments: $1 input
function bashunit::pkg::do_thing() {
  local input=$1                       # natural name, no prefix needed
  local val="${input%%]*}"
  val="${val#[}"
  _BASHUNIT_PKG_THING_OUT=$val
}

# Caller
bashunit::pkg::do_thing "$payload"
local thing=$_BASHUNIT_PKG_THING_OUT
```

- Zero forks per call.
- Helper has natural local names; no `__bu_` noise.
- Caller cannot accidentally shadow the slot because the `_BASHUNIT_*` namespace
  is reserved for the framework.
- A dedicated slot per helper (rather than one shared `_BASHUNIT_OUT`) means
  adjacent or nested calls can't clobber each other. Cheap: globals are free.

Examples in tree: `src/runner/payload.sh` (`_BASHUNIT_RUNNER_FIELD_OUT`,
`_BASHUNIT_RUNNER_TOTAL_OUT`, `_BASHUNIT_RUNNER_TYPE_OUT`, `_BASHUNIT_RUNNER_OUTPUT_OUT`),
`src/coverage/branches.sh` (`_BASHUNIT_BRANCH_ARMS_OUT`).

### When the helper builds dynamic variable names (mock/spy state)

Use a clear namespace prefix on the **constructed** name, not on the helper's locals:

```bash
# Spy state lives in _BASHUNIT_SPY_${variable}_TIMES_FILE, not ${variable}_times_file.
# A caller doing `local foo_times_file=...` is therefore harmless: the helper
# resolves a different global.
export "_BASHUNIT_SPY_${variable}_TIMES_FILE"="$times_file"
```

Example in tree: `src/test_doubles.sh` (`_BASHUNIT_SPY_*`).

### Last-resort fallback: outvar by name + `__bu_` prefix on locals

Only use this when neither a fixed return slot nor a namespaced constructed name is
practical (e.g. a generic helper called from many call sites with different output
variables and no shared global is appropriate):

```bash
function bashunit::pkg::do_thing() {
  local __bu_out=$1
  local __bu_in=$2
  local __bu_val="${__bu_in%%]*}"
  eval "$__bu_out=\$__bu_val"
}
```

- All internal locals MUST be `__bu_`-prefixed; otherwise dynamic-scope shadowing
  silently breaks the caller's outvar (see PR #672 — that exact bug caused 12 parallel
  test failures in #662).
- Include a regression test that calls the helper with one of its own documented
  internal names as the outvar.

### Intentional dynamic-scope mutation is a separate pattern

The coverage branch helpers in `src/coverage/branches.sh` (`_branch_push_if` and friends)
deliberately mutate caller locals (`if_decision_line`, `if_arms`, `if_depth`, `if_arm_start`).
That is documented inline above the helpers in that file and is **not** the outvar pattern —
the helper has no `$1`-named outvar argument; the caller agrees to share state by convention.
It is also why those helpers and `extract_branches` must stay in one file (ADR-010).
Don't introduce new instances of this pattern without an inline justification comment.

## ShellCheck

All code must pass `make sa`. Use directives sparingly with reason:
```bash
# shellcheck disable=SC2034  # Variable used by caller
```
