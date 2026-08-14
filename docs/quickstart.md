---
description: "Get started with bashunit in minutes: install the bash testing framework, write your first test, and run it with a simple, intuitive API."
---

# Quickstart

**bashunit** is a dedicated testing tool crafted specifically for Bash scripts. It empowers you with tests on your Bash codebase, ensuring that your scripts operate reliably and as intended.

With an intuitive API and documentation, it streamlines the process for developers to implement and manage tests. This is beneficial regardless of the project's size or intricacy in Bash.

Thanks to **bashunit**, verifying and validating your Bash code has never been so easy.

## Installation

Pick whichever fits your project. See [installation](/installation) for the complete list (Brew, MacPorts, bashdep, GitHub Actions, etc.).

::: code-group
```bash [install.sh]
# Generates lib/bashunit (single-file executable)
curl -s https://bashunit.com/install.sh | bash
```

```bash [npm]
# Per-project (pinned in package.json), run via npx
npm install --save-dev bashunit
npx bashunit tests/

# Global install, run directly on PATH
npm install -g bashunit
bashunit tests/
```

:::

The `install.sh` route creates `lib/bashunit`; the npm route exposes `bashunit` via `npx` or your global `PATH`.

## Usage

Once **bashunit** is installed, you're ready to get started.

You can bootstrap a ready to use test suite with the `init` subcommand:

```bash
./lib/bashunit init tests
```

It creates, in the current directory:

- `tests/bootstrap.sh` — sourced before your tests; put shared setup here
- `tests/example_test.sh` — a sample test
- `.github/workflows/tests.yml` — a CI workflow using the official action
- `.env` — with `BASHUNIT_BOOTSTRAP=tests/bootstrap.sh`, which is what makes the bootstrap load

If `.env` already sets `BASHUNIT_BOOTSTRAP` to that same file, `init` leaves it alone and
says so, so re-running is safe. If it points somewhere else, the old line is commented out
and the new one appended — check the diff before committing.

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
    ./lib/bashunit tests
    ```

4.  If everything works correctly, you should see an output similar to the following:
    ```-vue
    bashunit - {{ pkg.version }} | Tests: 1
    Running tests/example_test.sh
    ✓ Passed: Bashunit is working

    Tests:      1 passed, 1 total
    Assertions: 1 passed, 1 total

    All tests passed
    Time taken: 90ms
    ```

    A per-test duration column appears when the platform has a cheap clock source;
    `BASHUNIT_SHOW_EXECUTION_TIME` controls it.

5.  Now you can start testing the functionalities of your own Bash scripts.

## Running your suite

With no path, bashunit runs `tests/` (`BASHUNIT_DEFAULT_PATH`):

```bash
./lib/bashunit                      # run tests/
./lib/bashunit --filter user        # only tests whose name matches
./lib/bashunit --parallel tests/    # run files concurrently
./lib/bashunit --changed            # only test files touched since origin/HEAD
```

## Learning bashunit interactively

If you prefer hands-on learning, bashunit includes an interactive tutorial:

```bash
./lib/bashunit learn
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
- **[Command line](/command-line)** - Every flag, from `--filter` to `--shard`
- **[Configuration](/configuration)** - `.env` and `BASHUNIT_*` variables

<script setup>
import pkg from '../package.json'
</script>
