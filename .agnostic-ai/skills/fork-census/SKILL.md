---
name: fork-census
description: Measure process costs and fork budgets when changing startup, per-file, per-test, parallel workers, reporting, or coverage paths; use for fork census and performance comparisons.
allowed-tools: read, shell
---

# Fork census

Read [the fork-budget reference](references/fork-budget.md) before changing process costs. Its historical timings are evidence of earlier measurements, not current baselines. All repository paths below are relative to the repository root.

1. Identify the actual path: cold start, sequential run, parallel worker, lifecycle hook, report, or coverage. Read the matching existing fixture in `tests/acceptance/bashunit_coldstart_forks_test.sh`, `tests/acceptance/bashunit_run_forks_test.sh`, or `tests/acceptance/bashunit_coverage_forks_test.sh`. Include the options and hooks the change exercises.
2. For a timing claim, measure current main before editing and record its commit, Bash version, OS, fixture, options, and sampling method. Land any new benchmark harness before the PR that measures a delta. Alternate baseline and candidate rounds in the same location and repeat anomalous readings.
3. Use the reference's PATH-shim census for binary invocations. Resolve real binaries before adding shims; startup-pinned binaries bypass them. Account separately for shell-function subshells. Use traces to locate sites, not raw trace-line totals to count forks. Skip unreliable PATH-shim checks on Git Bash.
4. Add a failing budget regression using the existing fixture patterns, then make the smallest change. Measure parallel costs with a parallel fixture and compare supported Bash versions. Never replace a fork with pure Bash based only on a microbenchmark.
5. Run the matching acceptance file with `./bashunit --no-parallel tests/acceptance/<existing-file>`. These tests select their own internal sequential or parallel census. Preserve the checked budgets; report counts, timing samples, and limits. The main session runs the full quality gate after the complete change set.
