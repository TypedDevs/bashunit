---
description: Use bashunit with AI coding agents — machine-readable results, tight feedback loops, a ready-made skill, and the mistakes agents make writing bash tests.
---

# Agentic coding

Coding agents write bash, and bash is the language they get wrong most often: quoting,
exit codes and portability all fail quietly. A test suite is the only thing that turns
"the agent says it works" into evidence.

bashunit is well suited to that loop — it starts in tens of milliseconds, needs no
runtime, and emits machine-readable results an agent can parse instead of eyeballing.

## Point your agent at the docs

Two files are published for machine consumption:

| URL | What it is |
|-----|------------|
| [`bashunit.com/llms.txt`](https://bashunit.com/llms.txt) | Short index of every docs page, following the [llms.txt](https://llmstxt.org) convention |
| [`bashunit.com/llms-full.txt`](https://bashunit.com/llms-full.txt) | The entire documentation as one plain-text file |

Give an agent the second one and it stops inventing assertion names:

```bash
curl -s https://bashunit.com/llms-full.txt -o .agent/bashunit-docs.txt
```

## Machine-readable results

Agents should read structured output, not scrape the terminal.

`--report-json <file>` writes a summary plus one entry per test, including the failure
message and the exact source line:

```json
{
  "summary": { "total": 2, "passed": 1, "failed": 1, "skipped": 0, "incomplete": 0, "duration_ms": 24 },
  "tests": [
    { "file": "tests/math_test.sh", "name": "Passes", "status": "passed", "duration_ms": 9, "message": "" },
    { "file": "tests/math_test.sh", "name": "Fails", "status": "failed", "duration_ms": 15,
      "message": "✗ Failed: Fails\n    Expected 'a'\n    but got  'b'\n    at tests/math_test.sh:7" }
  ]
}
```

`--output tap` prints [TAP version 13](https://testanything.org) on stdout, which most
harnesses already understand:

```
TAP version 13
# tests/math_test.sh
ok 1 - Passes
not ok 2 - Fails
  ---
  Expected 'a'
  but got  'b'
  at tests/math_test.sh:7
  ...

1..2
```

`--report-tap <file>` and `--log-junit <file>` write the same information to disk.

The exit code is `0` when everything passed and non-zero otherwise, so an agent can
branch on `$?` before parsing anything.

## Keep the loop tight

An agent that re-runs the whole suite after every edit wastes most of its turn. These
flags exist to avoid that:

```bash
bashunit --filter "parses the header" tests/   # one test by name
bashunit --rerun-failed tests/                 # only what failed last run
bashunit --failures-only --no-progress tests/  # drop the noise from the transcript
bashunit --parallel tests/                     # full suite, concurrently
bashunit --test-timeout 10 tests/              # stop an agent-written infinite loop
```

`--rerun-failed` reads `.bashunit/last-failed`, so the red-green cycle is: run once,
then loop on `--rerun-failed` until it is empty. Add `.bashunit/` to your `.gitignore`.

For a long agent session, `--test-timeout` matters more than it looks. A generated test
with a `while` loop that never terminates will otherwise hang the run until the agent's
own timeout fires, and the transcript will show nothing useful.

## Drop-in rules for your repo

Put this in your `AGENTS.md`, `CLAUDE.md`, or equivalent. It covers the mistakes agents
actually make against this API:

```markdown
## Testing with bashunit

- Test files end in `_test.sh`; test functions start with `test_`.
- Run one test: `bashunit --filter "<name>" tests/`. Run everything: `bashunit tests/`.
- Prefer `assert_same` (exact) over `assert_equals` (which trims/normalizes).
- **Exit-code assertions take the code as the THIRD argument**, not the first:
  `assert_general_error "" "" "$exit_code"`. With no arguments at all they read `$?`.
- Capture an exit code before asserting, or `set -e` will kill the test first:
  `local ec=0; my_command || ec=$?`
- **Helpers are namespaced, assertions are not.** `assert_*` is bare; every helper needs
  the prefix: `bashunit::temp_dir`, `bashunit::temp_file`, `bashunit::mock`,
  `bashunit::spy`. The unprefixed form is `command not found`, not an alias.
- Use `$(bashunit::temp_file)` / `$(bashunit::temp_dir)` for scratch files — they are
  cleaned up automatically and are safe under `--parallel`.
- Never call the network in a test. Use `bashunit::mock` / `bashunit::spy` instead.
- Spy assertion argument order is inconsistent — check, don't guess:
  `assert_have_been_called_times <count> <spy>` but
  `assert_have_been_called_with <spy> <expected> [call_index]`.
- Do not delete a shared fixture in `tear_down_after_script`: under `--parallel` the
  file's tests may still be running, and they will vanish from the totals silently.
- Assertions are listed at https://bashunit.com/assertions — do not invent names.
  `bashunit doc <filter>` prints them locally.
```

## A ready-made skill

For agents that support loadable skills (Claude Code, and anything else reading a
`SKILL.md`), install the bashunit skill:

```bash
mkdir -p .claude/skills/bashunit
curl -sL https://bashunit.com/bashunit-skill.md -o .claude/skills/bashunit/SKILL.md
```

It teaches the write-run-fix cycle, the assertion catalogue, and the traps listed above.
Invoke it with `/bashunit`, or let the agent pick it up when it starts writing tests.

The file is plain markdown — read it before installing, and edit it to match your
project's conventions.

## Verifying what an agent wrote

Agents write tests that pass for the wrong reason. Three cheap checks:

```bash
bashunit --fail-on-risky tests/   # a test with no assertions is a failure, not a pass
bashunit --random-order tests/    # catches tests that depend on execution order
bashunit --strict tests/          # set -euo pipefail; catches unset vars and silent failures
```

`--fail-on-risky` is the highest-value of the three. A test that calls the function under
test and asserts nothing looks green in every report, and it is one of the most common
things a generating model produces.

Pair `--random-order` with `--seed <n>` to reproduce a specific shuffle once it finds
something.

## Coverage as a review signal

```bash
bashunit --coverage --coverage-report coverage/lcov.info tests/
```

Use it to answer "did the agent test the branch it just changed", not as a target to
optimize — see [Coverage](/coverage). `--coverage-min <n>` fails the run below a
threshold if you want it enforced.
