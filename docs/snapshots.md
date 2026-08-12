---
description: "Snapshot testing in bashunit: capture and compare command or script output over time to catch unexpected changes in your bash programs."
---

# Snapshots

Snapshot testing is valuable for verifying the output of commands or scripts over time.
By capturing and comparing the "snapshot" of the output at different stages,
you can easily spot unintended changes or regressions.
This way, it helps maintain the expected behavior while modifications are being made,
making the verification process more efficient and reliable.

## assert_match_snapshot
> `assert_match_snapshot "actual" ["snapshot_file"]`

Reports an error if `actual` does not match the existing snapshot file associated with the current test function.
If no such file exists, a new one is created with the provided value.

Pass `snapshot_file` to point at a specific snapshot — useful to share one snapshot between tests.
By default each test gets its own, named after the test function.

::: tip
Update snapshots deliberately with `--snapshot-update`; combine it with `--filter` to
re-record a single test.
:::

::: code-group
```bash [Example]
function test_success() {
  assert_match_snapshot "$(ls)"
}

function test_failure() {
  assert_match_snapshot "$(date)"
}
```
```[First run]
Running snapshot_test.sh
✎ Snapshot: Success
✎ Snapshot: Failure

Tests:      2 snapshot, 2 total
Assertions: 2 snapshot, 2 total
Some snapshots created
```
```[Subsequent runs]
Running snapshot_test.sh
✓ Passed: Success
✗ Failed: Failure
    Expected to match the snapshot
    Mon Jul 27 [-13:37:46-]{+13:37:49+} UTC 1987

Tests:      1 passed, 1 failed, 2 total
Assertions: 1 passed, 1 failed, 2 total
Some tests failed
```
:::

::: warning
You need to run the tests for this example twice to see them work.
The first time you run them, the snapshots will be generated and the second time they will be asserted.
:::

## assert_match_snapshot_ignore_colors
> `assert_match_snapshot_ignore_colors "actual" ["snapshot_file"]`

Like `assert_match_snapshot` but ANSI escape codes in `actual` are ignored. This allows
verifying the output text while disregarding its style.

::: code-group
```bash [Example]
function test_success() {
  assert_match_snapshot_ignore_colors "$(printf '\e[31mHello\e[0m World!')"
}
function test_failure() {
  assert_match_snapshot_ignore_colors "World"
}
```
:::

## Named snapshots

Use named snapshots when one test needs to capture several independent values:

> `assert_match_named_snapshot "name" "actual"`

```bash
function test_render_modes() {
  assert_match_named_snapshot "compact" "$(./bin/render --compact)"
  assert_match_named_snapshot "verbose" "$(./bin/render --verbose)"
}
```

The name becomes a normalized filename suffix, so these resolve beside the default
snapshot as `test_render_modes.compact.snapshot` and
`test_render_modes.verbose.snapshot`. Spaces and punctuation are safe and cannot escape
the test's `snapshots/` directory.

Use `assert_match_named_snapshot_ignore_colors "name" "actual"` for the same behavior
with ANSI escape sequences removed.

## Placeholders

Output that changes between runs — a timestamp, a PID, a temp path, a duration — would
make a snapshot fail every time. A placeholder marks the part you have decided not to
pin, so the rest still is.

The default token is `::ignore::`; override it with `BASHUNIT_SNAPSHOT_PLACEHOLDER`.

```bash [Example]
# snapshot file content
echo 'Run at ::ignore::' > snapshots/example.snapshot

# test
assert_match_snapshot "Run at $(date)"
```

### What a placeholder does and does not relax

Everything outside the placeholder still has to match **exactly**. A placeholder is not
a wildcard for the whole snapshot: `a::ignore::b` matches `a123b`, and does *not* match
`XXX` or `aXXXc`.

| Snapshot | Matches | Does not match |
|---|---|---|
| `a::ignore::b` | `a123b`, `ab` (an empty region matches) | `XXX`, `aXXXc` |
| `::ignore::tail` | `anythingtail` | `anythingelse` |
| `a=::ignore:: b=::ignore::` | `a=1 b=2` | `a=1 c=2` |
| `::ignore::` alone | any value at all | — |

Text around a placeholder is compared literally, so regex metacharacters need no
escaping: a snapshot reading `cost $5.00 (x) ::ignore::` matches that exact prefix and
nothing else.

A placeholder may span several lines. Given this snapshot:

```
Report
::ignore::
Done
```

`Report\nany\nnumber\nof lines\nDone` matches, and unrelated output does not.

### Placeholders and `--snapshot-update`

`--snapshot-update` **skips** any snapshot containing a placeholder and says so. The
placeholder is a deliberate decision about what not to pin, and re-recording would
silently replace it with whatever this run happened to produce. Remove the placeholder
first if you really want the literal value.

### Requirements

Matching a placeholder needs `perl` or `awk`; one of them is present on essentially any
system that runs bash. If neither is, the assertion **fails** with a message saying so
rather than reporting a pass it could not verify. Snapshots without a placeholder are a
plain string comparison and need neither.

## Finding unused snapshots

A snapshot file is named after its test file and test function, so renaming or deleting a
test orphans its snapshot: nothing reads it, nothing reports it, and it stays on disk.

`--snapshot-report-unused` lists the snapshot files no test resolved during the run:

```bash
./bashunit --snapshot-report-unused tests/
```
```
Unused snapshots (1), no test resolved them:
  tests/snapshots/header_test_sh.test_old_name.snapshot
Nothing was deleted. Run with --snapshot-prune to remove them.
```

It never deletes anything — a snapshot removed by mistake is re-recorded on the next run
and never fails again, so an automatic cleanup could quietly turn a real assertion into a
rubber stamp. Only snapshots belonging to the test files of the run are considered, and
the flag is refused with `--filter`, `--tag`, `--exclude-tag`, `--shard` and
`--rerun-failed`, whose partial runs would report live files as unused.

### Deleting them

`--snapshot-prune` deletes exactly the files the report lists, printing each
path as it goes:

```bash
./bashunit --snapshot-prune tests/
```
```
Deleted 1 unused snapshot(s):
  tests/snapshots/header_test_sh.test_old_name.snapshot
```

Two guards, both about the same risk — deleting a snapshot that was merely not
reached:

- **Full runs only.** `--filter`, `--tag`, `--exclude-tag`, `--shard`,
  `--rerun-failed` and `--changed` run a subset, so the snapshots of the tests
  they skipped would look unused. Combining them exits non-zero **before**
  running anything.
- **Not on a failing run.** A test that stopped at an earlier assertion never
  resolved its snapshot either, so "unused" there can mean "not run". Pruning
  says so and deletes nothing.

`--snapshot-update` and `--snapshot-prune` compose: update rewrites what the
tests resolved, prune removes what nothing resolved, and the two sets are
disjoint by construction.

## Snapshots in CI

Recommended CI setting: `--no-snapshot-create` (or `BASHUNIT_SNAPSHOT_CREATE=false`).

By default the first run of a snapshot test writes the snapshot and passes. That is what
you want locally, and exactly what you do not want in CI: a snapshot that was never
committed, is gitignored, or was lost gets re-created on the fly, and the run is green
while asserting nothing. With the flag, a missing snapshot fails and the message names
the file to commit:

```
✗ Failed: Renders the header
    Expected './tests/snapshots/header_test_sh.test_renders_the_header.snapshot'
    does not exist; record it with a run without '--no-snapshot-create'
```

So: record locally, commit the snapshot, run CI with `--no-snapshot-create`.

## Re-recording snapshots

When an output change is intentional, run with `--snapshot-update` (or
`BASHUNIT_SNAPSHOT_UPDATE=true`) and the existing snapshots are rewritten with the value
of that run, reported as recorded snapshots rather than passes:

```bash
./bashunit --snapshot-update tests/                            # all of them
./bashunit --snapshot-update --filter "renders header" tests/  # just one test
```

Snapshots holding a [placeholder](#placeholders) are **not** rewritten: the placeholder
marks output that was deliberately left unpinned, and overwriting it would replace that
with one run's concrete value. bashunit reports those on stderr and compares as usual.

Prefer this to deleting snapshot files. The snapshot path is derived from the test file
and function name, and a missing snapshot is silently re-recorded and passes — so a `rm`
of the wrong file turns a real assertion into one that asserts nothing. Either way, read
`git diff` before committing the re-recorded files.

## Related

- [Assertions](/assertions) — the built-in assertion reference
- [Configuration](/configuration) — env vars like `BASHUNIT_SNAPSHOT_PLACEHOLDER`
- [Test doubles](/test-doubles) — mocks and spies for isolated tests
