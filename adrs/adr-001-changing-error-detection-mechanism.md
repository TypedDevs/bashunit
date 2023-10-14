# Title: Changing Error Detection Mechanism in Bashunit

* Status: accepted
* Authors: @Tito-Kati, with consensus from @khru and @Chemaclass
* Date: 2023-10-14

Technical Story:
    - Issue: [TypedDevs/bashunit#182](https://github.com/TypedDevs/bashunit/issues/182)
    - Pull Request: [TypedDevs/bashunit#189](https://github.com/TypedDevs/bashunit/pull/189)

## Context and Problem Statement

In the existing setup of bashunit, error detection within tests was based on return codes along with `set -e`.
This mechanism would interrupt a test script if any execution within the script returned an error code other than 0.
A specific scenario was identified where a non-existing function call within a test did not cause the test to fail as it should, as illustrated in issue [#182](https://github.com/TypedDevs/bashunit/issues/182).

## Considered Options
* Use stderr instead return codes and set -e.

## Decision Outcome

To rectify this, a new error detection mechanism was proposed in pull request [#189](https://github.com/TypedDevs/bashunit/pull/189).
The changes shifted error detection from relying on return codes to utilizing stderr.
Now, if any execution within a script writes something to stderr, it will be considered as failed.
This adjustment also changes the behavior of the test runner slightly as tests will now run to the end even if there’s a failure at the beginning, aligning the behavior across different scenarios.

### Positive Consequences

The consequences include:
- Enabling true Test Driven Development (TDD) in bashunit by ensuring that tests fail as expected when there's an error, providing a more accurate and reliable testing environment.
- Altering the runner's behavior to continue executing tests even after an initial failure, which may be viewed as strange but is consistent with the new error detection mechanism.
- Refining error reporting to align with standard practices, providing more descriptive insight into the errors.

### Negative Consequences

Unknown at the moment.
