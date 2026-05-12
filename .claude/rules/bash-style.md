---
paths:
  - "src/**/*.sh"
  - "tests/**/*.sh"
---

# Bash Style & Compatibility Rules

## Bash 3.0+ Compatibility (Critical)

bashunit must work on **Bash 3.0+** (macOS default). These features are **prohibited**:

| Feature | Bash ver | Alternative |
|---------|----------|-------------|
| `declare -A` (associative arrays) | 4.0+ | Parallel indexed arrays |
| `[[ ]]` (test operator) | — | `[ ]` with `=` not `==` |
| `${var,,}` / `${var^^}` (case) | 4.0+ | `tr '[:upper:]' '[:lower:]'` |
| `${array[-1]}` (negative index) | 4.3+ | `${array[${#array[@]}-1]}` |
| `&>>` (append both) | 4.0+ | `>> file 2>&1` |

## Coding Conventions

- **2 spaces** indent, no tabs — enforced by `shfmt -w .`
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

## Outvar helpers (dynamic-scope safety)

Bash `local` is **dynamically scoped**, not lexically scoped. A `local` inside a callee
shadows the caller's same-named variable for the duration of the call. Any helper that
writes back to a caller-named variable (the **outvar pattern**) must defend against this
or it will silently corrupt callers that pick a "natural" name.

### Rule

Helpers that take a caller-named variable as an outvar (typically the first argument)
**MUST prefix every internal local with `__bu_`** so no caller-passed name can collide.

### Why

Without the prefix, this fails silently:

```bash
without_prefix() {
  local _out=$1
  local subshell_output=$2     # LOCAL shadows caller's same-named var
  local line="formatted"
  eval "$_out=\$line"          # assigns to the LOCAL, not the caller
}

main() {
  local subshell_output="raw"
  without_prefix subshell_output "$subshell_output"
  echo "$subshell_output"      # prints "raw" — the helper appeared to succeed
}
```

The caller's variable is untouched, no error is raised, and tests downstream silently
get stale data. This regression bit us in #662 (12 parallel test failures, fixed in
PR #672) before the prefix was applied.

### Pattern

```bash
# Writes <description> into the named outvar.
# Arguments: $1 outvar name, $2 input
function bashunit::pkg::do_thing() {
  local __bu_out=$1
  local __bu_in=$2
  local __bu_val="${__bu_in%%]*}"
  __bu_val="${__bu_val#[}"
  eval "$__bu_out=\$__bu_val"
}
```

- Use `eval "$__bu_out=\$__bu_val"` for the assignment. Quote the `$` of the value with
  a backslash so only the outvar name is expanded at eval time.
- Do **not** use `printf -v` (Bash 3.0 lacks it) or `declare -n` (Bash 4.3+).
- A regression test should pass the helper's own local names as outvar to catch any
  contributor who later drops the prefix.

### Where the convention applies in this repo

- All four hot-path outvar helpers in `src/runner.sh`: `extract_encoded_field`,
  `extract_subshell_type`, `format_subshell_output`, `compute_total_assertions`.
- All helpers in `src/test_doubles.sh` that touch caller-named or caller-constructed
  variables: `bashunit::mock`, `bashunit::spy`, `bashunit::unmock`, plus the
  `assert_have_been_called*` family. Each takes a command name and either `export`s
  derived globals or reads them via `${!file_var}`; both directions can collide with a
  caller local of the same constructed name, so internal locals are `__bu_`-prefixed.

### Intentional dynamic-scope mutation is a separate pattern

The coverage branch helpers in `src/coverage.sh` (`_branch_push_if` and friends) deliberately
mutate caller locals (`if_decision_line`, `if_arms`, `if_depth`, `if_arm_start`). That is
documented inline at `src/coverage.sh:818-821` and is **not** the outvar pattern — the
helper has no `$1`-named outvar argument; the caller agrees to share state by convention.
Don't introduce new instances of this pattern without an inline justification comment.

## ShellCheck

All code must pass `make sa`. Use directives sparingly with reason:
```bash
# shellcheck disable=SC2034  # Variable used by caller
```
