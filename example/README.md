# bashunit example

An example using this **bashunit** testing library.

## Demo usage

1) Install the git submodule

```bash
git submodule update --init --recursive
```

2) Update to the latest version

```bash
git submodule update --remote
```

3) Run the tests

```bash
tools/bashunit/bashunit logic_test.sh
```

<img alt="Demo using the bashunit from different paths" src="demo.png" width="800" >

## Real example

Looking for a more "real" example? There you go:
- [Chemaclass/conventional-commits](https://github.com/Chemaclass/conventional-commits/blob/main/tests/prepare-commit-msg_test.sh)
