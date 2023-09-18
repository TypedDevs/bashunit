# Getting Started

## Installation

Despite there is no dependency manager for bash scripts like "composer", you can install this project in your repo as you pleased. Here, I define one that might be suitable for you using Git submodules.

### Git submodule

You can use Git submodules to include external Git repositories within your project. This approach works well for including Bash scripts or other resources from remote repositories.

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
