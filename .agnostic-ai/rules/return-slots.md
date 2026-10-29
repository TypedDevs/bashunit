---
scope: src
---

# Return values and dynamic scope

Bash `local` is dynamically scoped. A callee's local can hide a caller variable accessed by name through `${!name}`, `eval`, `printf -v` or `export`. Hot-path `$()` captures also fork.

Prefer one reserved global return slot per helper:

```bash
_BASHUNIT_PKG_THING_OUT=""

function bashunit::pkg::do_thing() {
  local input=$1
  _BASHUNIT_PKG_THING_OUT=${input%%]*}
}

bashunit::pkg::do_thing "$payload"
local thing=$_BASHUNIT_PKG_THING_OUT
```

Use natural local names and `_BASHUNIT_*` slots; distinct slots avoid nested-call clobbering. See `src/runner/payload.sh` and `src/coverage/branches.sh`.

For mock or spy state, namespace the constructed variable itself, for example `_BASHUNIT_SPY_${variable}_TIMES_FILE`. See `src/doubles/spy.sh`.

Only when a dedicated slot or namespaced state cannot fit, accept an output variable name and prefix every helper local with `__bu_`:

```bash
function bashunit::pkg::do_thing() {
  local __bu_out=$1
  local __bu_in=$2
  local __bu_val="${__bu_in%%]*}"
  eval "$__bu_out=\$__bu_val"
}
```

Test caller names that collide with helper locals. Do not introduce unprefixed callee locals in this pattern.

The `_branch_*` helpers in `src/coverage/branches.sh` deliberately mutate `extract_branches` locals. Keep them together (ADR-010); new intentional dynamic-scope mutation needs an explicit one-line constraint.
