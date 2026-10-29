# ADR-016: Interruptible sequential test capture

* Status: accepted
* Date: 2026-10-29

Related: https://github.com/TypedDevs/bashunit/issues/1417

## Context and Problem Statement

Bash defers a trapped signal while waiting for a foreground command substitution. Sequential tests previously captured their body through command substitution, so a hanging body could prevent SIGTERM cleanup from running at all. Moving the body to a separate background process group would prevent it from reading its controlling terminal.

## Decision Outcome

Start each sequential body as an explicit background subshell with job control disabled and stdin inherited. It stays in the runner's foreground group and can read the controlling terminal. Wait using Bash's interruptible `wait` builtin. Capture output in a reusable file per loaded file, keyed by the existing dispatch ordinal, and read it through a retained descriptor using Bash's read builtin. Select a closed descriptor before opening it so inherited descriptors remain available; close it after capture. Keeping it open preserves output when a test removes the run scratch directory. Strip trailing newlines as command substitution did. This replaces the existing body subshell without adding per-test external commands or temporary-file creation.

Record each active body's PID and whether it owns a process group. Cancellation snapshots owned descendants using a real `ps` resolved before test setup, then signals only those PIDs when they share the terminal group. Existing timeout groups remain separate. Resolve the grace timer's `sleep` at startup too and use builtin signalling so test doubles cannot choose termination targets or skip the grace period.

Signal cleanup marks the run interrupted, sends TERM, and allows two seconds for per-test teardown before forcing remaining owned processes to stop. Refresh descendants at the grace deadline so teardown children are included. File workers use this same cleanup for their test workers, including nested timeout processes, before running file teardown. Wait for signalled file workers before removing the run's scratch directories.

Files that disable per-test parallelism use the interruptible capture inside their file worker. Ordinary parallel body capture remains unchanged. The timeout path records its existing body and watchdog for cancellation cleanup; its normal watchdog and result transport remain unchanged.

## Consequences

SIGINT, SIGTERM, and SIGHUP can reach cleanup while an ordinary sequential body is blocked. Test output, assertion state, and exit status still travel through the existing result payload. Each capture file is reused only after its body's completion and is removed with the run directory.

The EXIT trap records cleanup entry together with the exit status. During interruption or timeout, late SIGTERM delivery cannot abort a teardown that has already started; the active watchdog supplies the termination bound instead.

The file teardown remains user code and can itself block; resetting the handled signal dispositions allows a second signal to interrupt it.
