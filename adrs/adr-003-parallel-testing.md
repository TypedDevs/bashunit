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

When the `--parallel` flag is used, each **test function** is spawned as its own
background subshell from `bashunit::runner::call_test_functions`:

> bashunit::runner::run_test "$script" "$fn_name" &

Each test writes its result to one file under `$TEMP_DIR_PARALLEL_TEST_SUITE`.
After all tests finish, the results are aggregated by traversing that directory.
This keeps test execution isolated while running tests concurrently.

Aggregation is handled by:

> bashunit::state::aggregate_parallel_results "$TEMP_DIR_PARALLEL_TEST_SUITE"

> **Updated since this ADR was written.** The original text described spawning
> one subprocess *per file* via `runner::call_test_functions … &` and aggregating
> via `parallel::aggregate_test_results`. Both are out of date: the unit of
> parallelism is the individual test, the functions gained the `bashunit::`
> namespace (#538), aggregation moved to `state.sh`, and the runner now lives in
> the `src/runner/` module (ADR-010) with the spawn in `src/runner/exec.sh`.
> The result file is named from a per-suite ordinal assigned just before each
> `&` rather than from a `mktemp` per test (#851) — Bash 3 subshells inherit
> `$$` and the `RANDOM` state and `BASHPID` is 4.0+, so an ordinal is the only
> fork-free way to get a unique name. Job-slot limiting is in
> `src/runner/parallel.sh`.


