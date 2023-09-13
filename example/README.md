# bashunit example

An example using this **bashunit** testing library.

## Demo usage

This demo uses **bashunit** itself as [git-submodule](https://git-scm.com/book/de/v2/Git-Tools-Submodule) inside the `tools/bashunit` directory.

1) Install the git submodule
    ```bash
    git submodule add git@github.com:TypedDevs/bashunit.git tools/bashunit
    # (Optional) Update to the latest version
    git submodule update --remote
    ```
2) Run the tests
    ```bash
    tools/bashunit/bashunit logic_test.sh
    ```
   <img alt="Demo using the bashunit from different paths" src="demo.png" width="800" >

   or use from the root directory use the `make` command
    ```bash
    make test/example
    ```
   <img alt="Demo using the bashunit from different paths" src="demo_make.png" width="800" >

    If you want to run the test with the watcher you'll need to have installed [fswatch](https://github.com/emcrisostomo/fswatch)
    and run the following command:
    ```bash
    make test/watch/example
    ```

## Real example

Looking for a more "real" example? There you go:
- [Chemaclass/conventional-commits](https://github.com/Chemaclass/conventional-commits/blob/main/tests/prepare-commit-msg_test.sh)
