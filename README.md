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

## Assertions at a glance

bashunit ships ~60 assertions across many families. One representative example per family
(full catalog and signatures at [bashunit.com/assertions](https://bashunit.com/assertions)):

| Family | Example |
|---|---|
| Equality & truth | [`assert_equals "foo" "$actual"`](https://bashunit.com/assertions#assert-equals) |
| Strings | [`assert_string_starts_with "Hello" "$greeting"`](https://bashunit.com/assertions#assert-string-starts-with) |
| Exit codes | [`assert_exit_code "1"`](https://bashunit.com/assertions#assert-exit-code) (checks `$?` of the previous command) |
| Numeric | [`assert_greater_than "1" "$count"`](https://bashunit.com/assertions#assert-greater-than) |
| Arrays | [`assert_array_length 3 "${my_array[@]}"`](https://bashunit.com/assertions#assert-array-length) |
| Files & dirs | [`assert_file_permissions 644 "$file"`](https://bashunit.com/assertions#assert-file-permissions) |
| JSON (needs `jq`) | [`assert_json_contains ".name" "bashunit" "$json"`](https://bashunit.com/assertions#assert-json-contains) |
| Dates | [`assert_date_before "2026-01-01" "$date"`](https://bashunit.com/assertions#assert-date-before) |
| Duration | [`assert_duration_less_than "echo hello" 500`](https://bashunit.com/assertions#assert-duration-less-than) |
| Snapshots | [`assert_match_snapshot "$(my_cmd)"`](https://bashunit.com/assertions#assert-match-snapshot) |
| Test doubles | [`assert_have_been_called_times 2 my_fn`](https://bashunit.com/assertions#assert-have-been-called-times) |

## Documentation

Full documentation, covering installation options, every feature and examples, lives at [bashunit.com](https://bashunit.com).

Shell tab-completion for bash and zsh is available under [`completions/`](completions/) — see the [installation docs](https://bashunit.com/installation#shell-completion).

## Contribute

Issues, ideas and pull requests are welcome.
See the [contribution guide](https://github.com/TypedDevs/bashunit/blob/main/.github/CONTRIBUTING.md) to set up your environment.
