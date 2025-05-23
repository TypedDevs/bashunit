# Title: Support custom test categories

* Status: proposed
* Authors: @CodexBot
* Date: 2024-10-30

Technical Story:
  - Issue: [TypedDevs/bashunit#357](https://github.com/TypedDevs/bashunit/issues/357)

## Context and Problem Statement

Currently bashunit only groups tests by file or by matching a filter in the test name. Users would like to run subsets such as "slow" tests without relying on file structure or naming conventions.

## Considered Options

* Parse category annotations in comments and filter via a command line option.
* Require categories in function names (e.g. `test_slow_example`).
* Keep relying on folder structure only.

## Decision Outcome

Using comment annotations is the most flexible approach while keeping backwards compatibility. Other testing frameworks (JUnit `@Tag`, pytest markers, NUnit `[Category]`, RSpec metadata) follow similar patterns where categories are declared near the test definition and selected by a flag. Parsing a simple `# @category` comment allows bashunit to mimic this behavior.

### Positive Consequences

* Enables running or excluding subsets like slow or integration tests.
* Does not impose naming conventions on test functions.

### Negative Consequences

* Slightly more complex parsing logic for test discovery.

## Links

* Refers to [Issue #357](https://github.com/TypedDevs/bashunit/issues/357)
