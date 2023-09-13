# Assertions

When creating tests, you'll need to verify your commands and functions. We provide assertions for these checks.
Below is their documentation.

## assertEquals
> `assertEquals "expected" "actual"`

Reports an error if the two variables `expected` and `actual` are not equal.

[assertNotEquals](#assertnotequals) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assertEquals "foo" "foo"
}

function test_failure() {
  assertEquals "foo" "bar"
}
```

## assertContains
> `assertContains "needle" "haystack"`

Reports an error if `needle` is not a substring of `haystack`.

[assertNotContains](#assertnotcontains) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assertContains "foo" "foobar"
}

function test_failure() {
  assertContains "baz" "foobar"
}
```

## assertNotEquals
> `assertNotEquals "expected" "actual"`

Reports an error if the two variables `expected` and `actual` are equal.

[assertEquals](#assertequals) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assertNotEquals "foo" "bar"
}

function test_failure() {
  assertNotEquals "foo" "foo"
}
```

## assertNotContains
> `assertNotContains "needle" "haystack"`

Reports an error if `needle` is a substring of `haystack`.

[assertContains](#assertcontains) is the inverse of this assertion and takes the same arguments.

*Example:*
```bash
function test_success() {
  assertNotContains "baz" "foobar"
}

function test_failure() {
  assertNotContains "foo" "foobar"
}
```
