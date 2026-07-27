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
You can update the snapshot by deleting it and running its test again.
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

## Placeholders

Snapshot files can contain placeholder tokens to ignore variable parts of the output.
By default the token `::ignore::` will match any text. You can override it with the
`BASHUNIT_SNAPSHOT_PLACEHOLDER` environment variable.

```bash [Example]
# snapshot file content
echo 'Run at ::ignore::' > snapshots/example.snapshot

# test
assert_match_snapshot "Run at $(date)"
```

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
