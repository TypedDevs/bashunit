# Skipping and incomplete tests

There may be various scenarios where the "passed" and "failed" outcomes for a test are not sufficient.
To address these situations, the following functions are available for your use.

## skip
> `skip "[reason]"`

Not all tests can be run in every environment; when such situations arise, you can mark a test as skipped.

It reports that the test has been skipped, including the `[reason]` if one was specified.

Skipping tests will not cause **bashunit** to exit with an error code;
however, it will indicate that some tests were skipped in the final output.

::: code-group
```bash [Example]
function test_skipped() {
  if [[ $OS != "GEOS" ]]; then
    skip && return
  fi

  assert_empty "not reached"
}

function test_skipped_with_reason() {
  if [[ $OS != "GEOS" ]]; then
    skip "Not running under Commodore" && return
  fi

  assert_empty "not reached"
}
```
```[Output]
↷ Skipped: Skipped
↷ Skipped: Skipped with reason
    Not running under Commodore

Tests:      2 skipped, 2 total
Assertions: 2 skipped, 2 total
Some tests skipped
```
:::

## todo
> `todo "[pending]"`

You may come up with a test that you'd like to implement later.
Instead of leaving the test implementation empty —which would mark the test as complete— you can flag it as incomplete.

Reports that the test is incomplete as it is under development, including any `[pending]` to do details if specified.

Incomplete tests will not cause **bashunit** to exit with an error code;
however, it will indicate that some tests were incomplete in the final output.

::: code-group
```bash [Example]
function test_incomplete() {
  todo
}

function test_incomplete_with_pending_details() {
  todo "Detailed description of what needs to be done"
}
```
```[Output]
✒ Incomplete: Incomplete
✒ Incomplete: Incomplete with pending details
    Detailed description of what needs to be done

Tests:      2 incomplete, 2 total
Assertions: 2 incomplete, 2 total
Some tests incomplete
```
:::
