# Quickstart

**bashunit** is a dedicated testing tool crafted specifically for Bash scripts. It empowers you with tests on your Bash codebase, ensuring that your scripts operate reliably and as intended.

With an intuitive API and documentation, it streamlines the process for developers to implement and manage tests. This is beneficial regardless of the project's size or intricacy in Bash.

Thanks to **bashunit**, verifying and validating your Bash code has never been so easy.

## Installation

There is a tool that will generate an executable with the whole library in a single file:

::: code-group
```bash [Linux/Mac]
curl -s https://bashunit.typeddevs.com/install.sh | bash
```

```bash [Windows]
# IMPORTANT: You need WSL (Windows Subsystem for Linux) to run bashunit
#
# Step 1: Install WSL if you haven't already
#   - Open PowerShell as Administrator
#   - Run: wsl --install
#   - Restart your computer
#
# Step 2: Open your WSL terminal and run:
curl -s https://bashunit.typeddevs.com/install.sh | bash
```
:::

This will create a file inside a lib folder, such as `lib/bashunit`.

See more about [installation](/installation).

## Usage

Once **bashunit** is installed, you're ready to get started.

You can bootstrap a ready to use test suite with the `--init` option:

```bash
./lib/bashunit --init tests
```

This will create a `tests` directory containing a sample test and bootstrap file.

Alternatively, create your tests manually:

1.  First, create a folder to place your tests:
    ```bash
    mkdir tests
    ```

2.  Next, create your first test file named `example_test.sh` within this folder:
    ::: code-group
    ```bash [tests/example_test.sh]
    #!/usr/bin/env bash

    function test_bashunit_is_working() {
      assert_same "bashunit is working" "bashunit is working"
    }
    ```
    :::

3.  Finally, run the **bashunit** executable:
    ```bash
    ./lib/bashunit ./tests
    ```

4.  If everything works correctly, you should see an output similar to the following:
    ```-vue
    bashunit - {{ pkg.version }} | Tests: 1
    Running tests/example_test.sh
    ✓ Passed: Bashunit is working                                         16 ms

    Tests:      1 passed, 1 total
    Assertions: 1 passed, 1 total

    All tests passed
    Time taken: 90 ms
    ```

5.  Now you can start testing the functionalities of your own Bash scripts.

## Learning bashunit interactively

If you prefer hands-on learning, bashunit includes an interactive tutorial:

```bash
./lib/bashunit --learn
```

This will guide you through 10 progressive lessons covering all major features with practical exercises and immediate feedback.

## Next steps

Dive deeper into the documentation:
- **[Common patterns](common-patterns)** - Real-world testing scenarios and best practices
- **[Assertions](assertions)** - Learn all available assertion functions
- **[Test doubles](test-doubles)** - Master mocks and spies for isolated testing
- **[Data providers](/data-providers)** - Write parameterized tests efficiently
- **[Snapshots](snapshots)** - Test complex output easily
- **[Test files](/test-files)** - Understand test file structure and lifecycle hooks

<script setup>
import pkg from '../package.json'
</script>
