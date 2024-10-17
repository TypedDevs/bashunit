# Title: Parallel testing

* Status: accepted
* Authors: @Chemaclass
* Date: 2024-10-11

Technical Story:
- Pull Request: [TypedDevs/bashunit#358](https://github.com/TypedDevs/bashunit/pull/358)

## Context and Problem Statement

We aim to enhance testing performance by running tests in parallel processes while capturing and aggregating results effectively.

## Considered Options

- Implement parallel execution using subprocesses.
- Aggregate test results from temporary files.
- Use a spinner for user feedback during result aggregation.

## Decision Outcome

- Implemented parallel test execution using subprocesses.
- Each test creates a temporary directory to store results, later aggregated.

### Positive Consequences

- Reduced test execution time considerably.
- Clear feedback via a spinner during aggregation.

### Negative Consequences

- Potential complexity
    - with handling temporary files during interruptions.
    - in handling temporary files and managing subprocesses.

## Technical Details

When the `--parallel` flag is used, each test is run in its own subprocess by calling:

> runner::call_test_functions "$test_file" "$filter" 2>/dev/null &

Each test script creates a temporary directory and stores individual test results in temp files.
After all tests finish, the results are aggregated by traversing these directories and files.
This approach ensures isolation of test execution while improving performance by running tests concurrently.

The aggregation (which collects all test outcomes into a final result set) is handled by the function:

> parallel::aggregate_test_results "$TEMP_DIR_PARALLEL_TEST_SUITE"


