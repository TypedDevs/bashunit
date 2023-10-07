# Usage

Once **bashunit** is installed, you're ready to get started.

1.  First, create a folder to place your tests:
    ```bash
    mkdir tests
    ```

2.  Next, create your first test file named `example_test.sh` within this folder with the following content:
    ```bash
    #!/bin/bash

    function test_bashunit_is_working() {
      assert_equals "bashunit is working" "bashunit is working"
    }
    ```
    ::: tip
    You can add as many test functions to a test file as you want.
    Just ensure they're prefixed with `test`; otherwise, **bashunit** won't execute them.
    :::

3.  Finally, run the **bashunit** executable, passing your test file as argument.
    If you use wildcards, **bashunit** will run any tests it finds.

    You can copy and execute the following command from the root of your project if you installed **bashunit** as a Git submodule:
    ```bash
    # all tests inside the tests directory
    ./bashunit tests

    # or a concrete test by full path
    ./bashunit tests/example_test.sh
    ```

4.  If everything works correctly, you should see an output similar to the following:
    ```text
    Running tests/example_test.sh
    ✓ Passed: Bashunit is working

    Tests:      1 passed, 1 total
    Assertions: 1 passed, 1 total
    All tests passed
    Time taken: 100 ms
    ```

5.  Now you can start testing the functionalities of your own Bash scripts.

<script setup>
import pkg from '../package.json'
</script>
