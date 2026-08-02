---
description: "Overview of the bashunit project layout, source code, documentation and contributor workflow for the modern bash testing framework."
---

# Project overview

**bashunit** is a lightweight testing framework for Bash. It focuses on helping developers verify their shell scripts with minimal setup. The library bundles hundreds of assertions and helpers, including spies, mocks and data providers.

This repository hosts the bashunit source code, its documentation and many automated tests. New contributors can use this overview to understand the basic layout and workflow when working on the project.

## Repository layout

- `src` – library functions used by `bashunit`, organised as modules (below).
- `bin` – the executable entry points.
- `adrs` – internal architecture decisions records.
- `example` – example scripts and tests demonstrating usage.
- `tests` – automated tests for bashunit itself.
- `docs` – documentation built with [VitePress](https://vitepress.dev/).

## Source modules

`src/` contains module directories and no loose files. Each module has an `index.sh` entry
point holding **only `source` lines** — the code lives in the sibling files beside it.

| Module | What it owns |
|---|---|
| `system` | capability probing: OS detection, `command -v`, small I/O helpers |
| `util` | computation: strings, arithmetic, time |
| `api` | the surface your test file calls — `temp_file`, `skip`/`todo`, custom-assert helpers |
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
| `learn` | the interactive tutorial |
| `main` | flag parsing per subcommand and the run lifecycle |

There is also a `dev` module holding debug helpers, which is deliberately excluded from the
built binary.

The released `bashunit` is a **single file**: `build.sh` walks the `source` statements from the
entrypoint, inlines every module in dependency order, and strips the `source` lines.

For the full picture — load order, the build pipeline, the tests that enforce all of it, and
how to add a file, a module or a subcommand — see
[ADR-011](https://github.com/TypedDevs/bashunit/blob/main/adrs/adr-011-source-layout-and-build-pipeline.md).

## Running tests

The project uses bashunit to test itself. To execute the full suite, run:

::: code-group
```bash [Quick]
./bashunit -s -p tests # Regular tests
./bashunit -s -b tests # Benchmark tests
```
```bash [Complete]
./bashunit --simple --parallel tests # Regular tests
./bashunit --simple --bench    tests # Benchmark tests
```
:::


> See more command line options: [here](/command-line)

## Contributing

Pull requests are welcome! Please read the [contribution guide](https://github.com/TypedDevs/bashunit/blob/main/.github/CONTRIBUTING.md) before sending patches. All contributions are covered by the MIT license.

For documentation changes you can preview locally with:

```bash
cd docs
npm ci
npm run dev
```

Before submitting your pull request ensure that `npm run build` (run from `docs/`) succeeds and that the test suite passes.

## Further reading

For a step‑by‑step introduction check the [quickstart](/quickstart). Detailed usage of individual features is explained throughout the docs site.

## Related

- [Quickstart](/quickstart) - write and run your first test
- [Installation](/installation) - install bashunit
- [Command line](/command-line) - CLI flags and options
- [Examples](/examples) - sample tests and real-world projects
