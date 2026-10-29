---
name: hidden-parallel-results
description: Relative hidden test paths must contribute results and keep their own identity.
metadata:
  type: project
---

A relative hidden test directory can execute successfully while a `*` glob omits its result directory. Visible and hidden paths must also stay distinct rather than fixing enumeration by deleting leading dots.

**Why:** [#1393](https://github.com/TypedDevs/bashunit/issues/1393), fixed by [#1394](https://github.com/TypedDevs/bashunit/pull/1394), exposed missing parallel totals.

**How to apply:** when changing result keys or aggregation, run the relative-hidden and visible/hidden cases in `tests/acceptance/bashunit_parallel_consistency_test.sh`; require matching sequential/parallel totals and exit status for passing and failing tests.
