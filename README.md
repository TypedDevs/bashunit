# bashunit

A minimalistic unit testing library for your bash scripts.

## Usage

`src/test_runner.sh tests/*`

#### Example: Defining your own tests

```bash
# src/your_logic.sh

echo "expected $1"
```

```bash
# tests/your_logic_test.sh

# load the assert functions
source "$(dirname "$0")/assert.sh" 

# define the script that you want to execute
readonly SCRIPT="$PWD/src/your_logic.sh"

function test_your_logic() {
  assertEquals "expected 123" "$("$SCRIPT" "123")"
}
```

## Installation

Despite there is no dependency manager for bash scripts like "composer", you can install this project in your repo as you pleased. Here, I define one that might be suitable for you using Git submodules.

### Git submodule

You can use Git submodules to include external Git repositories within your project. This approach works well for including Bash scripts or other resources from remote repositories.

```bash
git submodule add git@github.com:Chemaclass/bashunit.git tools/bashunit
```