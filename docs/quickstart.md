---
description: "Install bashunit, write your first Bash test, and run your test suite."
---

# Quickstart

**bashunit** runs tests for Bash scripts. Install it, create a test file, and run the test below.

## Installation

Pick whichever fits your project. See [installation](/installation) for the complete list (Brew, MacPorts, bashdep, GitHub Actions, etc.).

::: code-group
```bash [install.sh]
# Generates lib/bashunit (single-file executable)
curl -s https://bashunit.com/install.sh | bash
```

```bash [npm project]
npm install --save-dev bashunit
```

```bash [npm global]
npm install -g bashunit
```

:::

The `install.sh` route creates `lib/bashunit`; the npm route exposes `bashunit` via `npx` or your global `PATH`.

## Usage

Create a test suite with the `init` subcommand:

::: code-group
```bash [install.sh]
./lib/bashunit init tests
```

```bash [npm project]
npx bashunit init tests
```

```bash [npm global]
bashunit init tests
```
:::

It creates, in the current directory:

- `tests/bootstrap.sh`: sourced before your tests; put shared setup here
- `tests/example_test.sh`: a sample test
- `.github/workflows/tests.yml`: a CI workflow using the official action
- `.env`: with `BASHUNIT_BOOTSTRAP=tests/bootstrap.sh`, which is what makes the bootstrap load

If `.env` already sets `BASHUNIT_BOOTSTRAP` to that file, `init` leaves it unchanged and reports this. If it points elsewhere, `init` comments out the old line and appends the new one. Check the diff before committing.

Alternatively, create your tests manually:

1.  Create a test directory:
    ```bash
    mkdir tests
    ```

2.  Create `tests/example_test.sh`:
    ::: code-group
    ```bash [tests/example_test.sh]
    #!/usr/bin/env bash

    function test_bashunit_is_working() {
      assert_same "bashunit is working" "bashunit is working"
    }
    ```
    :::

3.  Run the test:
    ::: code-group
    ```bash [install.sh]
    ./lib/bashunit tests/
    ```

    ```bash [npm project]
    npx bashunit tests/
    ```

    ```bash [npm global]
    bashunit tests/
    ```
    :::

4.  The output should look like this:
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

## Running your suite

With no path, bashunit runs `tests/` (`BASHUNIT_DEFAULT_PATH`). The examples below use the `install.sh` path; for an npm project, replace `./lib/bashunit` with `npx bashunit`, or with `bashunit` for a global install:

```bash
./lib/bashunit                      # run tests/
./lib/bashunit --filter user        # only tests whose name matches
./lib/bashunit --parallel tests/    # run files concurrently
./lib/bashunit --changed            # only test files touched since origin/HEAD
```

## Next steps

Choose a topic:

- **[Common patterns](common-patterns)** - Testing recipes
- **[Assertions](assertions)** - Available assertion functions
- **[Test doubles](test-doubles)** - Replace commands and record calls
- **[Data providers](/data-providers)** - Run a test with different arguments
- **[Snapshots](snapshots)** - Compare output against saved files
- **[Test files](/test-files)** - Test file structure and lifecycle hooks
- **[Command line](/command-line)** - Every flag, from `--filter` to `--shard`
- **[Configuration](/configuration)** - `.env` and `BASHUNIT_*` variables

<script setup>
import pkg from '../package.json'
</script>
