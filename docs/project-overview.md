# Project overview

**bashunit** is a lightweight testing framework for Bash. It focuses on helping developers verify their shell scripts with minimal setup. The library bundles hundreds of assertions and helpers, including spies, mocks and data providers.

This repository hosts the bashunit source code, its documentation and many automated tests. New contributors can use this overview to understand the basic layout and workflow when working on the project.

## Repository layout

- `src` – library functions used by `bashunit`.
- `bin` – the executable entry points.
- `adrs` – internal architecture decisions records.
- `example` – example scripts and tests demonstrating usage.
- `tests` – automated tests for bashunit itself.
- `docs` – documentation built with [VitePress](https://vitepress.dev/).

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
npm ci
npm run docs:dev
```

Before submitting your pull request ensure that `npm run docs:build` succeeds and that the test suite passes.

## Further reading

For a step‑by‑step introduction check the [quickstart](/quickstart). Detailed usage of individual features is explained throughout the docs site.
