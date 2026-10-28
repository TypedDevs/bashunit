---
description: "Browse bashunit examples demonstrating assertions, test doubles, data providers, snapshots and more for testing real bash scripts."
---

# Examples

## Demo example

The [example directory](https://github.com/TypedDevs/bashunit/tree/main/example) contains a sample script and tests showing bashunit features.

## Real examples

These projects use **bashunit** to test their Bash scripts:

::: info
To add your project, submit a pull request.
:::

### [TypedDevs/bashunit](https://github.com/TypedDevs/bashunit/tree/main/tests)

**bashunit** uses itself to test its features.

### [phpstan/phpstan-src](https://github.com/phpstan/phpstan-src/blob/2.0.x/.github/workflows/e2e-tests.yml)

PHPStan checks PHP code for errors without running it. It uses **bashunit** [standalone assertions](/standalone) in its end-to-end tests in CI.

### [Chemaclass/create-pr](https://github.com/Chemaclass/create-pr)

A bash script to create a PR based on your branch name.

### [Chemaclass/conventional-commits](https://github.com/Chemaclass/conventional-commits)

A specification for adding human and machine-readable meaning to commit messages.

### [antonio-gg-dev/fizzbuzz-bashunit](https://github.com/antonio-gg-dev/fizzbuzz-bashunit)

A FizzBuzz exercise solved in Bash and tested with **bashunit**.

### [kndndrj/shload](https://github.com/kndndrj/shload)

Loading bar for your shell scripts.

### [phpctl](https://github.com/opencodeco/phpctl)

A PHP development environment using Docker containers.

### [SherpaCLI/sherpa](https://sherpa-cli.netlify.app/tools/unit-tests)

Sh:erpa helps users create shell scripts and integrates **bashunit** to test them.

### [sqlh](https://gitlab.com/prodigal.knight/sqlite-history.sh)

sqlh is a SQLite-backed shell history alternative with shared history features which works across multiple shells.

## Related

- [Quickstart](/quickstart) - write and run your first test
- [Common patterns](/common-patterns) - real-world testing patterns
- [Standalone](/standalone) - assertions outside test files
- [Assertions](/assertions) - assertion reference
