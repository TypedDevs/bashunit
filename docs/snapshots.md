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
:::
