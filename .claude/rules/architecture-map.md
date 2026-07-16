---
paths:
  - "src/**/*.sh"
  - "bashunit"
---

# Architecture Map: modules and the life of a run

Orientation for working in `src/` — which file owns what, and the exact call
flow of a test run. Line numbers drift; function names are the stable anchors.

## The life of `./bashunit tests/`

```
bashunit (entry)          sources all src/*.sh; version gate; early flag scan
└─ bashunit::main::cmd_test                 (main.sh: flag parsing, env exports)
   └─ bashunit::runner::load_test_files     (runner.sh: the per-file loop)
      ├─ console_header::print_header       "Running N tests" — captures
      │    └─ helper::find_total_tests      $() SUBSHELL: sources each file in a
      │                                     nested subshell just to count tests
      ├─ source "$test_file"                in the MAIN shell (workers inherit)
      ├─ helper::check_duplicate_functions  one awk pass per file
      ├─ runner::functions_for_script       pure bash: filter + sort by def line
      ├─ helper::build_provider_map         one awk pass per file (cached by path,
      │                                     but the count subshell's build dies
      │                                     with it → runs twice per file)
      └─ runner::call_test_functions        per-fn loop
         └─ runner::run_test  [--parallel: spawned as a & worker per test]
            ├─ clock::now_to_slot           duration start (if needed)
            ├─ runner::execute_test_body    $() subshell: the actual test fn
            │    └─ state::export_subshell_context   printf payload "##K=V##…"
            ├─ runner::parse_result         sync: parse counts from payload
            │                               parallel: + write .result via mktemp
            └─ console_results::print_successful_test / _failed_ / …
                └─ str::rpad + strip_ansi   align per-test time (pure bash)
   └─ [--parallel] wait; parallel::aggregate_test_results over *.result files
   └─ console_results::render_result        totals; deferred failure/skip blocks
   └─ rerun::persist; env::cleanup_run_output_dir; exit code
```

Key inversion to remember: **tests run inside `$()` subshells; state comes back
as an encoded single-line payload** (`##ASSERTIONS_FAILED=…##TEST_OUTPUT=<b64>##`),
parsed by `runner::parse_result`/`state.sh`. Counters only exist in the main
shell (or, in parallel, in per-test `.result` files aggregated at the end).

## Module ownership

| Module | Owns |
|--------|------|
| `bashunit` + `main.sh` | entry, subcommand routing, flag parsing, run lifecycle, exit codes, cleanup calls |
| `runner.sh` | file loop, per-test execution, retry/timeout, result parsing, failure context |
| `helpers.sh` | discovery (`find_files_recursive`), fn filtering, provider map, duplicate check, ids |
| `state.sh` | counters, per-test payload encode/decode, TAP conversion |
| `env.sh` | all `BASHUNIT_*` defaults/config files, scratch dirs (`_BASHUNIT_RUN_OUTPUT_DIR` + EXIT-trap cleanup) |
| `parallel.sh` | worker temp tree, aggregation, stop-on-failure flag file |
| `console_header.sh` / `console_results.sh` | header/totals rendering, deferred failed/skipped/incomplete/risky blocks (scratch files under the run dir) |
| `assert*.sh` | assertions; `assertions.sh` re-exports; per-assertion path must stay fork-free |
| `clock.sh` | time impl selection (EPOCHREALTIME > date > perl > …), return-slot reads |
| `str.sh` / `math.sh` / `io.sh` / `globals.sh` | pure-bash utilities; `globals.sh` has `temp_file`/`temp_dir` (public test API) |
| `test_doubles.sh` | spy/mock state via `_BASHUNIT_SPY_*` globals + files |
| `coverage.sh` | DEBUG-trap line tracking; only active under `--coverage` |
| `rerun.sh` | `.bashunit/last-failed` cache for `--rerun-failed` |
| `reports.sh` | JUnit/HTML/TAP/JSON writers |
| `check_os.sh` / `dependencies.sh` | one-fork OS detect; `command -v` probes (builtins, not forks) |
| `doc.sh` `init.sh` `learn.sh` `upgrade.sh` `watch.sh` `benchmark.sh` | the non-`test` subcommands |

## Cross-cutting invariants

- **Bash 3.0 floor** (`.claude/rules/bash-style.md`): no `[[`, `declare -A`,
  `${var,,}`, `BASHPID`, negative indices. Subshells share `$$` and `RANDOM`
  state — you cannot make a per-worker unique token without a fork (`mktemp`).
- **Return-slot pattern** (`_BASHUNIT_<PKG>_<FN>_OUT` globals) instead of `$()`
  captures on hot paths — bash-style.md documents it; `local` is dynamically
  scoped, so helpers must not write caller-named variables.
- **Fork budget** (`.claude/rules/perf-fork-budget.md`): per-test paths are
  fork-free (sequential) or mktemp-only (parallel); budgets are enforced by
  `tests/acceptance/bashunit_*forks*_test.sh` on three platforms — a "harmless"
  `echo | sed` in a per-test path will fail CI.
- **Binaries pinned at startup** (`$GREP`, `$MKTEMP`, `$CAT` in env.sh) so test
  doubles/PATH games can't hijack the framework's own plumbing.
- **Snapshots assume 80-col non-tty width** (`tput cols` fallback); anything
  that changes rendering widths breaks `tests/acceptance/snapshots/`.
