<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo_name_dark.svg">
  <img alt="bashunit" src="docs/assets/logo_name.svg" width="400">
</picture>

[![Tests](https://github.com/Chemaclass/bashunit/actions/workflows/tests.yml/badge.svg)](https://github.com/Chemaclass/bashunit/actions/workflows/tests.yml)
[![Static analysis](https://github.com/Chemaclass/bashunit/actions/workflows/static_analysis.yml/badge.svg)](https://github.com/Chemaclass/bashunit/actions/workflows/static_analysis.yml)
[![MIT Software License](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com/Chemaclass/bashunit/blob/main/LICENSE)

A minimalistic unit testing library for your bash scripts.

## Usage

`./bashunit <test_script>`

#### Example: Defining your own tests

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

For more, see the [example](example/README.md) directory.

## Installation

Despite there is no dependency manager for bash scripts like "composer", you can install this project in your repo as you pleased. Here, I define one that might be suitable for you using Git submodules.

### Git submodule

You can use Git submodules to include external Git repositories within your project. This approach works well for including Bash scripts or other resources from remote repositories.

```bash
git submodule add git@github.com:Chemaclass/bashunit.git tools/bashunit
```

#### Versioning and updates

To update a git-submodule:
1. keep the git-submodule under your git (committed)
2. go inside the git-submodule and:
   1. `git submodule update --remote` (preferred)
   2. or pull `main`
   3. or checkout a concrete release tag

## Contribute

You are welcome to contribute reporting issues, sharing ideas,
or [with your Pull Requests](.github/CONTRIBUTING.md).
