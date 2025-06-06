# Snapshots

Snapshot testing is valuable for verifying the output of commands or scripts over time.
By capturing and comparing the "snapshot" of the output at different stages,
you can easily spot unintended changes or regressions.
This way, it helps maintain the expected behavior while modifications are being made,
making the verification process more efficient and reliable.

## assert_match_snapshot
> `assert_match_snapshot "actual"`

Reports an error if `actual` does not match the existing snapshot file associated with the current test function.
If no such file exists, a new one is created with the provided value.

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
> `assert_match_snapshot_ignore_colors "actual"`

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
