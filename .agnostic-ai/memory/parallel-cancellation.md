---
name: parallel-cancellation
description: An unreaped child can make kill -0 look like running cleanup.
metadata:
  type: project
---

`kill -0` can succeed for an exited child that has not been reaped. The parallel cancellation regression must inspect process state before treating that PID as cleanup still running.

**Why:** [#1385](https://github.com/TypedDevs/bashunit/issues/1385) recorded an intermittent forced-cleanup failure; merged [#1382](https://github.com/TypedDevs/bashunit/pull/1382) reproduced the exited-child case and corrected the check without extending the deadline.

**How to apply:** inspect the process-state helper in `tests/acceptance/bashunit_timeout_test.sh` before changing cancellation assertions. Preserve live-body failures and the bounded timeout grace; do not increase polling or skip a failing regression without evidence.
