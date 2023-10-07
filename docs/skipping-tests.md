# Skipping tests

## skip
> `skip "[reason]"`

Not all tests can be run in every environment; when such situations arise, you can mark a test as skipped.

It reports that the test has been skipped, including the [reason] if one was specified.

Skipping tests will not cause **bashunit** to exit with an error code;
however, it will indicate that some tests were skipped in the final output.

*Example:*
```bash
function test_skipped() {
  if [[ $OS != "GEOS" ]]; then
    skip
    return
  fi

  assert_empty "not reached"
}

function test_skipped_with_reason() {
  if [[ $OS != "GEOS" ]]; then
    skip "Not running under Commodore."
    return
  fi

  assert_empty "not reached"
}
```

*Output:*
```text
↷ Skipped: Skipped
↷ Skipped: Skipped with reason
    Not running under Commodore.

Tests:      2 skipped, 2 total
Assertions: 2 skipped, 2 total
Some tests skipped
```
