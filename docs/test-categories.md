# Test categories

Testing frameworks often allow running subsets of the suite by grouping tests into categories. For example:

- **JUnit**: uses `@Tag("slow")` annotations so the runner can include or exclude tests by tag.
- **pytest**: provides markers such as `@pytest.mark.slow` that can be selected with `-m slow`.
- **NUnit**: supports categories via the `[Category("slow")]` attribute.
- **RSpec**: allows metadata like `:slow` for filtering.

These approaches share similar ideas:

1. A test declares one or more categories.
2. The runner filters tests according to a command line option or configuration.

## Proposal for bashunit

1. Allow test functions to declare categories in a comment immediately preceding the function.
2. Syntax example:

```bash
# @category slow integration
function test_process_big_data() {
  ...
}
```

3. Introduce a `--category <name>` option (and `BASHUNIT_CATEGORY` env variable) that filters test functions by the given category.
4. Internally parse the comments when discovering tests and keep a mapping of function -> categories.
5. Running without the option executes all tests; running with `--category slow` executes only those marked as `slow`.

This approach maintains backwards compatibility and mirrors the tagging mechanisms of other testing libraries while remaining simple to parse with grep/awk.
