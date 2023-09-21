# Test files

**bashunit** offers a range of features for test files.
In this section, you'll find information about these features along with some helpful tips.

## Test file names

**bashunit** is flexible about how you name your test files.
However, if you're using wildcards for scanning your tests, keep in mind that the initial search can slow down if you don't filter the test files in the wildcard.

To optimize this, we recommend adding a `test` prefix or suffix to your test file names, and include this identifier in your wildcard pattern too (e.g., `**/*test.sh`).
This approach not only speeds up the scanning process but also helps you keep your test files organized.

This is useful regardless of whether your test files are located near your production code or share directories with your mocks, stubs, or fixtures.

## Test function names

**bashunit** will search for and execute all test functions it finds within each test file.
To distinguish test functions from auxiliary functions, make sure to prefix them with the word `test`.
The casing doesn't matter.
Below are some example test function names that would work seamlessly:

```bash
function test_should_validate_an_ok_exit_code() { ... }
function testRenderAllTestsPassedWhenNotFailedTests() { ... }
function test_getFunctionsToRun_with_filter_should_return_matching_functions() { ... }
```

You're free to use any of Bash's syntax options to define these functions.
