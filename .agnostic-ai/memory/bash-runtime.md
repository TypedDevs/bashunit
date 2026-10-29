---
name: bash-runtime
description: Subshell identity and extdebug differ across supported Bash builds.
metadata:
  type: project
---

Subshells inherit `$$`; `RANDOM` reseeding varies by Bash version, platform, and nesting, so neither guarantees a worker identity. Disabling `extdebug` clears `errtrace` and `functrace` on Bash 5.2+, even if they were set before it was enabled; older tested versions leave them on.

**Why:** these differences caused incorrect performance and tracing assumptions in [#1354](https://github.com/TypedDevs/bashunit/issues/1354), corrected by [#1364](https://github.com/TypedDevs/bashunit/pull/1364).

**How to apply:** use dispatcher ordinals for identity. Keep `extdebug` probes in a capture subshell, or explicitly preserve tracing flags. Runtime version checks cannot guard Bash 3.0 parse errors.
