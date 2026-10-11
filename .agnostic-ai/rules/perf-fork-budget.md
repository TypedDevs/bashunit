---
scope: src
paths:
  - "tests/acceptance/**"
---

# Process budgets

Keep startup, per-file, and per-test process costs within the existing fork census budgets. Read and use {{$SKILL:fork-census}} before changing those paths, parallel workers, report serialization, or coverage classification.

- Measure the path that runs, including flags and lifecycle hooks. A sequential fixture cannot detect per-worker costs; parallel changes need a parallel census.
- Count binary invocations with PATH shims where reliable. Pinned binaries bypass shims, and shell-function command substitutions fork without executing a binary. Raw `bash -x` totals overcount captured output.
- Benchmark before replacing an external tool with pure Bash. Large shell loops and string substitutions can be slower, and behavior varies across supported Bash versions. Keep regex assertions and HTML escaping semantics portable.
- Preserve fork-free per-test hooks, worker result naming by dispatcher ordinal, and the shared clock implementation. Do not use inherited `$$` or platform-dependent `RANDOM` behavior as unique worker identifiers.
- Never pass process substitutions as external-command arguments in per-file or per-test loops. Compare real files; redirecting process substitution into stdin is a different case.
- Extend the matching cold-start, run, or coverage fork regression when removing a fork class. Prove comparison harnesses can fail before relying on them, and repeat noisy or anomalous measurements.
