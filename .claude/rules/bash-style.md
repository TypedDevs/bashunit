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

## ShellCheck

All code must pass `make sa`. Use directives sparingly with reason:
```bash
# shellcheck disable=SC2034  # Variable used by caller
```
