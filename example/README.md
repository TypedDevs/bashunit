# bashunit example

An example using this **bashunit** testing library.

## Demo usage

This demo uses **bashunit** itself as [git-submodule](https://git-scm.com/book/de/v2/Git-Tools-Submodule) inside the `tools/bashunit` directory.

1) Install the git submodule
    ```bash
    git submodule add git@github.com:Chemaclass/bashunit.git tools/bashunit
    # (Optional) Update to the latest version
    git submodule update --remote
    ```
2) Run the tests
    ```bash
    tools/bashunit/bashunit logic_test.sh
    ```
   <img alt="Demo using the bashunit from different paths" src="demo.png" width="800" >

   or use from the root directory use the `make` command
    ```bash
    make test/example
    ```
   <img alt="Demo using the bashunit from different paths" src="demo_make.png" width="800" >

## Documentation

### assertEquals
```bash
assertEquals "expected" "actual"
```

**Example:**
```bash
function test_text_should_be_equal() {
  assertEquals "expected 123" "expected 123")"
}
```

### assertContains
```bash
assertEquals "expected" "actual"
```

**Example:**
```bash
function test_text_should_contain() {
  assertContains "expect" "expected 123")"
}
```

### assertNotContains
```bash
assertNotContains "expected" "actual"
```

**Example:**
```bash
function test_text_should_not_contain() {
  assertNotContains "expecs" "expected 123")"
}
```

### assertMatches
```bash
assertMatches "expected" "actual"
```

**Example:**
```bash
function test_text_should_not_contain() {
  assertMatches ".*xpec*" "expected 123"
}
```

### assertNotMatches
```bash
assertNotMatches "expected" "actual"
```

**Example:**
```bash
function test_text_should_not_contain() {
  assertNotMatches ".*xpes.*" "expected 123"
}
```

### assertNotMatches
```bash
assertExitCode "expected" [execution of the function to test]
```

**Examples:**
```bash
function test_should_validate_a_non_ok_exit_code() {
  function fake_function() {
    return 1
  }
  fake_function
  assertExitCode "1"
}
```
```bash
function test_other_way_of_using_the_exit_code() {
  function fake_function() {
    return 1
  }
  assertExitCode "1" "$(fake_function)"
}
```

## Real example

Looking for a more "real" example? There you go:
- [Chemaclass/conventional-commits](https://github.com/Chemaclass/conventional-commits/blob/main/tests/prepare-commit-msg_test.sh)
