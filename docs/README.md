
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../docs/assets/logo_name_dark.svg">
    <img alt="bashunit" src="../docs/assets/logo_name.svg" width="400">
  </picture>
</p>

A simple testing library for bash scripts.

## Functions

### [Asserts](../src/assert.sh)

- `assertEquals` expected actual message
- `assertContains` expected actual message
- `assertNotContains` expected actual message
- `assertMatches` expected actual message
- `assertNotMatches` expected actual message
- `assertExitCode` expected actual message


## Example

Check out this [simple example](../example) using **bashunit**, or a more "real" example in the original repository where the idea grew up: [Chemaclass/conventional-commits](https://github.com/Chemaclass/conventional-commits/blob/main/tests/prepare-commit-msg_test.sh).
