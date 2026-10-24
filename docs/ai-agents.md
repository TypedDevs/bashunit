---
description: "Use bashunit with AI coding agents: structured results, focused test runs, a reusable skill, and common test-writing mistakes."
---

# Agentic coding

Use bashunit to check agent-written Bash scripts for quoting, exit-code, and portability errors. It runs on Bash and emits machine-readable test results that an agent can parse.

## Point your agent at the docs

Two files are published for machine consumption:

| URL | What it is |
|-----|------------|
| [`bashunit.com/llms.txt`](https://bashunit.com/llms.txt) | Short index of every docs page, following the [llms.txt](https://llmstxt.org) convention |
| [`bashunit.com/llms-full.txt`](https://bashunit.com/llms-full.txt) | The entire documentation as one plain-text file |

Give the agent the full reference so it can look up assertion names:

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

`--output json` prints that same document on stdout instead, so an agent can pipe a run
straight into a parser without a temp file:

```bash
bashunit tests/ --output json | jq '.tests[] | select(.status == "failed")'
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

The exit code is non-zero when a test **failed**. It is `0` for a run that was entirely
skipped, incomplete, risky, or that only recorded new snapshots, so `$?` alone does not
mean "everything passed" — read `summary.total` against `summary.passed`, or add
`--fail-on-risky` and `--no-snapshot-create` (the latter turns a first-time snapshot
recording into a failure, so a snapshot that was never committed cannot pass silently).

## Keep the loop tight

Use focused runs while fixing tests, then run the full suite:

```bash
bashunit --filter parses_the_header tests/     # one test — matches the FUNCTION name
bashunit --rerun-failed tests/                 # only what failed last run
bashunit --failures-only --no-progress tests/  # drop the noise from the transcript
bashunit --parallel tests/                     # full suite, concurrently
bashunit --test-timeout 10 tests/              # stop an agent-written infinite loop
```

`--rerun-failed` reads `.bashunit/last-failed`, so the red-green cycle is: run once,
then loop on `--rerun-failed` until it is empty. Add `.bashunit/` to your `.gitignore`.

Use `--test-timeout` to stop a test with a non-terminating loop before it reaches the agent's own timeout.

## Drop-in rules for your repo

Add these API rules to your `AGENTS.md`, `CLAUDE.md`, or equivalent:

```markdown
## Testing with bashunit

- Test files end in `_test.sh`; test functions start with `test_`.
- Run one test: `bashunit --filter <function_name> tests/` — it matches the function
  name (`test_parses_the_header`), not the humanized title shown in the report, so a
  filter with spaces silently matches nothing. Run everything: `bashunit tests/`.
- Prefer `assert_same` (exact) over `assert_equals`, which strips ANSI colour codes,
  tabs and newlines before comparing — useful for asserting on coloured CLI output,
  misleading everywhere else. Neither trims spaces: `assert_equals "a" " a "` fails.
- **Exit-code assertions take the code as the THIRD argument**, not the first:
  `assert_general_error "" "" "$exit_code"`. With no arguments at all they read `$?`.
- Capture an exit code before asserting, or `set -e` will kill the test first:
  `local ec=0; my_command || ec=$?`
- **Helpers are namespaced, assertions are not.** `assert_*` is bare; every helper needs
  the prefix: `bashunit::temp_dir`, `bashunit::temp_file`, `bashunit::mock`,
  `bashunit::spy`. The unprefixed form is `command not found`, not an alias.
- Use `$(bashunit::temp_file)` / `$(bashunit::temp_dir)` for scratch files — they are
  cleaned up automatically and are safe under `--parallel`. Only paths these hand out
  are cleaned; a path you build yourself is yours to remove.
- Never call the network in a test. Use `bashunit::mock` / `bashunit::spy` instead.
- Doubles are torn down after every test — do not add `bashunit::unmock` to `tear_down`.
  Use it inside a test to get the real command back, or to suspend a
  `set_up_before_script` double for that one test (it cannot undo it for the others,
  since each test runs in its own subshell).
- Spy assertion argument order is inconsistent — check, don't guess:
  `assert_have_been_called_times <count> <spy>` but
  `assert_have_been_called_with <spy> <expected> [call_index]`.
- `assert_have_been_called_with <spy> <expected> [call_index]` compares a single call (the
  last one by default; the failure names which). `assert_have_been_called_with_any <spy>
  <expected>` matches any recorded call — prefer it unless the position is the requirement.
- A failed call assertion prints the spy's recorded calls under the diff — read that block
  before guessing why it failed, it is usually enough to fix the test in one pass.
- A call assertion on a name that was never passed to `bashunit::spy` fails with
  `was never registered as a spy`. Spies do not survive across tests, so register the
  spy inside the test that asserts on it.
- `assert_have_been_called_with` joins the expected arguments with spaces, so it cannot
  tell `cmd "a b"` from `cmd a b` — a quoting bug passes it. Use
  `assert_have_been_called_with_args <spy> <arg>...` (no `call_index`) to compare
  argument by argument whenever an argument may contain a space.
- Re-record snapshots with `--snapshot-update`, scoped by `--filter`; do not delete
  snapshot files. A missing snapshot is written silently and never fails, so a wrong
  `rm` turns a real assertion into a rubber stamp. Read `git diff` afterwards either way.
  Snapshots containing the placeholder are not rewritten — bashunit says so on stderr.
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

Check for tests that pass without verifying the intended behavior:

```bash
bashunit --fail-on-risky tests/   # a test with no assertions is a failure, not a pass
bashunit --random-order tests/    # catches tests that depend on execution order
bashunit --strict tests/          # set -euo pipefail; catches unset vars and silent failures
```

`--fail-on-risky` is the highest-value of the three. A test that calls the function under
test and asserts nothing looks green in every report, and it is one of the most common
things a generating model produces.

Pair `--random-order` with `--seed <n>` to reproduce the order of a failing run.

## Coverage as a review signal

```bash
bashunit --coverage --coverage-report coverage/lcov.info tests/
```

Use it to answer "did the agent test the branch it just changed", not as a target to
optimize — see [Coverage](/coverage). `--coverage-min <n>` fails the run below a
threshold if you want it enforced.

On Bash 4.1+ this is cheaper than it used to be: `BASHUNIT_COVERAGE_ENGINE` defaults to
an `xtrace` tracer that costs roughly a quarter of the old `DEBUG`-trap engine per
executed line, so a coverage run is affordable inside an agent loop rather than only in
a nightly job.

## Related

- [Command line](/command-line) — every flag referenced above
- [Assertions](/assertions) — the catalogue agents should pick names from
- [Test doubles](/test-doubles) — mocking the network and other side effects
- [Configuration](/configuration) — set these flags once via `.bashunitrc`
