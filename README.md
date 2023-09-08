# bashunit

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

To update a git-submodule is as simple as:
1. keep the git-submodule under your git (committed)
2. go inside the git-submodule and:
   1. checkout a concrete release tag
   2. or just pull `main` (preferred)

   
### Run test from the library
```bash
make test 
```