<p align="center">
    <a href="https://github.com/TypedDevs/bashunit/actions/workflows/tests.yml">
        <img src="https://github.com/TypedDevs/bashunit/actions/workflows/tests.yml/badge.svg" alt="Tests">
    </a>
    <a href="https://github.com/TypedDevs/bashunit/actions/workflows/static_analysis.yml">
        <img src="https://github.com/TypedDevs/bashunit/actions/workflows/static_analysis.yml/badge.svg" alt="Static analysis">
    </a>
    <a href="https://github.com/TypedDevs/bashunit/actions/workflows/linter.yml">
        <img src="https://github.com/TypedDevs/bashunit/actions/workflows/linter.yml/badge.svg" alt="Editorconfig checker">
    </a>
    <a href="https://github.com/TypedDevs/bashunit/blob/main/LICENSE">
        <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="MIT Software License">
    </a>
    <a href="https://deepwiki.com/TypedDevs/bashunit">
        <img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki">
    </a>
</p>
<br>
<p align="center">
    <picture>
        <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/TypedDevs/bashunit/main/docs/public/logo-name-dark.svg">
        <img alt="bashunit" src="https://raw.githubusercontent.com/TypedDevs/bashunit/main/docs/public/logo-name.svg" width="400">
    </picture>
</p>

<h1 align="center">A simple testing framework for bash scripts</h1>

<p align="center">
    Test your bash scripts in the fastest and simplest way.
</p>

## Why bashunit

A lightweight, fast testing framework for **Bash 3.0+**, focused on developer experience.
It ships hundreds of assertions plus spies, mocks, data providers, snapshots and more.

## Quick start

Install the latest version into your project:

```bash
curl -s https://bashunit.com/install.sh | bash
```

Write a test in `tests/example_test.sh`:

```bash
#!/usr/bin/env bash

function test_bashunit_is_working() {
  assert_same "bashunit is working" "bashunit is working"
}
```

Run it:

```bash
./lib/bashunit tests/
```

Prefer learning by doing? Run `./lib/bashunit learn` for an interactive tutorial.

## Documentation

Full documentation, covering installation options, every feature and examples, lives at [bashunit.com](https://bashunit.com).

## Contribute

Issues, ideas and pull requests are welcome.
See the [contribution guide](https://github.com/TypedDevs/bashunit/blob/main/.github/CONTRIBUTING.md) to set up your environment.
