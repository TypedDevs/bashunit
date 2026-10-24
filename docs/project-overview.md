---
description: "Overview of the bashunit project layout, source code, documentation and contributor workflow."
---

# Project overview

This repository contains the bashunit source code, documentation, and automated tests. This page describes the layout, source modules, and contributor workflow.

## Repository layout

- `src`: library functions used by `bashunit`, organised as modules (below).
- `bin`: the executable entry points.
- `adrs`: internal architecture decisions records.
- `example`: example scripts and tests demonstrating usage.
- `tests`: automated tests for bashunit itself.
- `docs`: documentation built with [VitePress](https://vitepress.dev/).

## Source modules

`src/` contains module directories and no loose files. Each module has an `index.sh` entry
point containing **only `source` lines**. The code lives in sibling files.

| Module | What it owns |
|---|---|
| `system` | capability probing: OS detection, `command -v`, small I/O helpers |
| `util` | computation: strings, arithmetic, time |
| `api` | functions your test file calls: `temp_file`, `skip`/`todo`, custom-assert helpers |
| `config` | `BASHUNIT_*` defaults, scratch dirs, parallel mode, the rerun cache |
| `coverage` | line and branch tracking, and the coverage reports |
| `state` | counters, per-test context, the result payload |
| `console` | everything printed: palette, header, per-test lines, totals |
| `helper` | naming, test discovery, data providers, tags, encoding |
| `cli` | the `doc`, `init`, `upgrade` and `watch` subcommands |
| `assert` | every assertion |
| `doubles` | spies and mocks |
| `reports` | JUnit, TAP, JSON, GitHub Actions and HTML writers |
| `runner` | the file loop, per-test execution, retry, result parsing |
| `benchmark` | the bench implementation |
| `main` | flag parsing per subcommand and the run lifecycle |

The `dev` module contains debug helpers and is excluded from the built binary.

The released `bashunit` is a **single file**: `build.sh` walks the `source` statements from the
entrypoint, inlines every module in dependency order, and strips the `source` lines.

See [ADR-011](https://github.com/TypedDevs/bashunit/blob/main/adrs/adr-011-source-layout-and-build-pipeline.md) for load order, the build pipeline, layout tests, and instructions for adding files, modules, or subcommands.

## Running tests

The project uses bashunit to test itself. To execute the full suite, run:

::: code-group
```bash [Quick]
./bashunit -s -p tests      # Regular tests
./bashunit bench -s tests   # Benchmark tests
```
```bash [Complete]
./bashunit --simple --parallel tests # Regular tests
./bashunit bench --simple      tests # Benchmark tests
```
:::

Benchmarks are a subcommand, not a flag on the test run: `bashunit bench [path]`.


See the [command line reference](/command-line) for more options.

## Contributing

Read the [contribution guide](https://github.com/TypedDevs/bashunit/blob/main/.github/CONTRIBUTING.md) before sending patches. All contributions are covered by the MIT license.

For documentation changes you can preview locally with:

```bash
cd docs
npm ci
npm run dev
```

Before submitting your pull request ensure that `npm run build` (run from `docs/`) succeeds and that the test suite passes.

## Further reading

Start with the [quickstart](/quickstart) to write and run your first test.

## Related

- [Quickstart](/quickstart) - write and run your first test
- [Installation](/installation) - install bashunit
- [Command line](/command-line) - CLI flags and options
- [Examples](/examples) - sample tests and real-world projects
