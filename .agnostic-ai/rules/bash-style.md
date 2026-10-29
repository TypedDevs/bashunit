---
scope: src
paths:
  - "tests/**"
---

# Bash style and compatibility

Runtime code must parse and work on Bash 3.0+. `bashunit` checks both version components. Use `tests/unit/project/bash_compatibility_test.sh` and existing version gates; do not ban a newer construct when an established gate safely selects a supported body. A runtime gate cannot protect a parse error.

| Construct | Minimum Bash | Portable approach |
|-----------|--------------|-------------------|
| `printf -v`, string `+=` | 3.1 | Return slot; `var="$var$more"` |
| Array `+=(x)` | 3.1 (parse error on 3.0) | `arr[${#arr[@]}]=x` |
| `declare -A` | 4.0 | Indexed arrays |
| `${var,,}`, `${var^^}` | 4.0 | `tr` for case conversion |
| `&>>` | 4.0 | `>> file 2>&1` |
| `BASHPID` | 4.0 | Dispatcher ordinal or `mktemp` |
| `mapfile`, `readarray` | 4.0 | `while IFS= read -r` |
| `coproc` | 4.0 | Existing portable worker dispatch |
| Negative array indices | 4.3 | `${array[${#array[@]}-1]}` |
| `declare -n`, `local -n` | 4.3 | Return slot |
| `${var@Q}` | 4.4 | Existing argument transport helpers |

`[[ =~ ]]` exists on 3.0, but regex quoting changed in 3.2. Follow existing `grep -E` helpers and the process-budget rules rather than introducing version-dependent matching. Prefer `[ ]` over `[[ ]]` for ordinary tests; that is house style, not a compatibility requirement.

Use 2-space indentation, quoted variables, `$()` instead of backticks, and existing function namespaces. Public helpers use `bashunit::*`, private helpers `_name`, locals `lowercase_with_underscores`, and globals `UPPERCASE_WITH_UNDERSCORES`. Match sibling file structure and source dependencies relative to the script. `make lint` is the formatting authority; never run `shfmt -w`. Use a comment only for a constraint the code cannot express. ShellCheck suppressions need a specific reason.
