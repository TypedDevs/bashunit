<p align="center">
    <a href="https://github.com/TypedDevs/bashunit/actions/workflows/tests.yml">
        <img src="https://github.com/TypedDevs/bashunit/actions/workflows/tests.yml/badge.svg" alt="Tests">
    </a>
    <a href="https://github.com/TypedDevs/bashunit/actions/workflows/static_analysis.yml">
        <img src="https://github.com/TypedDevs/bashunit/actions/workflows/static_analysis.yml/badge.svg" alt="Static analysis">
    </a>
    <a href="https://github.com/TypedDevs/bashunit/actions/workflows/deploy-docs.yml">
        <img src="https://github.com/TypedDevs/bashunit/actions/workflows/deploy-docs.yml/badge.svg" alt="Docs deployment">
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
        <source media="(prefers-color-scheme: dark)" srcset="docs/public/logo_name_dark.svg">
        <img alt="bashunit" src="docs/public/logo_name.svg" width="400">
    </picture>
</p>

<h1 align="center">A simple testing library for bash scripts</h1>

<p align="center">
    Test your bash scripts in the fastest and simplest way, discover the most modern bash testing library.
</p>

## Usage

`./bashunit <test_script>`

### Example: Defining your own tests

```bash
# example/logic.sh

echo "expected $1"
```

```bash
# example/logic_test.sh

SCRIPT="./logic.sh"

function test_your_logic() {
    assertEquals "expected 123" "$($SCRIPT "123")"
}
```

Check out the [example](example/README.md) directory for more.

## Installation

Although there's no Bash script dependency manager like `npm` for JavaScript, `Maven` for Java, `pip` for Python, or `composer` for PHP; you can install this project in your repository according to your preferences. Here, I provide a Git submodule option that will work for you.

### Git submodule

You can use Git submodules to include external Git repositories within your project. This approach works well for including Bash scripts or other resources from remote repositories.

```bash
git submodule add git@github.com:TypedDevs/bashunit.git tools/bashunit
```

### Versioning and updates

To update a git-submodule:
1. keep the git-submodule under your git (committed)
2. go inside the git-submodule and:
    1. `git submodule update --remote` (preferred)
    2. or pull `main`
    3. or checkout a concrete release tag


## Contribute

You are welcome to contribute reporting issues, sharing ideas,
or [with your Pull Requests](.github/CONTRIBUTING.md).

## Contributors

<p align="center">
    <img src="https://contributors.nn.ci/api?repo=TypedDevs/bashunit" alt="Contributors list" />
</p>
