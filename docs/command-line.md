# Command line

**bashunit** command accepts options to control its behavior.

## Directory or file

> `bashunit "directory|file"`

Specifies the `directory` or `file` containing the tests to be run.

If a directory is specified, it will execute tests within files ending in `test.sh`.

If you use wildcards, **bashunit** will run any tests it finds.

*Example:*
```bash
# all tests inside the tests directory
./bashunit ./tests

# concrete test by full path
./bashunit ./tests/example_test.sh

# all test matching given wildcard
./bashunit ./tests/**/*_test.sh
```

## Filter

> `bashunit -f|--filter "test name"`

Filters the tests to be run based on the `test name`.

*Example:*
```bash
# run all test functions including "something" in it's name
./bashunit ./tests --filter "something"
```

## Output

> `bashunit -s|--simple`
>
> `bashunit -v|--verbose`

Enables simplified or verbose output to the console.

Verbose is the default output, but it can be overridden by the environment configuration.

This command flag will always take precedence over the environment configuration.

*Example:*
```bash
./bashunit ./tests --simple
```

*Output:*
```text
........
```

*Example:*
```bash
./bashunit ./tests --verbose
```

*Output:*
```text
Running tests/functional/logic_test.sh
✓ Passed: Other way of using the exit code
✓ Passed: Should validate a non ok exit code
✓ Passed: Should validate an ok exit code
✓ Passed: Text should be equal
✓ Passed: Text should contain
✓ Passed: Text should match a regular expression
✓ Passed: Text should not contain
✓ Passed: Text should not match a regular expression
```

## Version

> `bashunit --version`

Displays the current version of **bashunit**.

*Example:*
```bash
./bashunit --version
```

*Output:*
```text-vue
bashunit - {{ pkg.version }}
```

<script setup>
import pkg from '../package.json'
</script>
