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
   └─ bashunit::runner::load_test_files     (runner/discovery.sh: the per-file loop)
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
   └─ [--parallel] wait; state::aggregate_parallel_results over *.result files
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
| `bashunit` | entry: version gate, early flag scan, sources every module, subcommand routing |
| `main/index.sh` | aggregator only — sources the `src/main/` module below |
| `main/validate.sh` | shared parser validation: unknown options, integer/path checks, shard parsing |
| `main/test.sh` / `main/bench.sh` / `main/subcommands.sh` | flag parsing per subcommand |
| `main/assert.sh` | the standalone `bashunit assert` path |
| `main/watch.sh` / `main/run.sh` | the `--watch` loop; the run lifecycle, exit codes and cleanup |
| `runner/index.sh` | aggregator only — sources the `src/runner/` module below |
| `runner/context.sh` | workdir restore, test identity/location exports, title interpolation, capability probes |
| `runner/payload.sh` | the `_BASHUNIT_RUNNER_*_OUT` return slots; encode/decode of the per-test result payload |
| `runner/diagnostics.sh` | runtime-error detection, kill-signal classification, profiling, verbose/file headers |
| `runner/result.sh` | `parse_result{,_sync,_parallel}`, failure source context, failed/skipped/incomplete/risky writers |
| `runner/parallel.sh` | job-slot waiting (`wait -n` or poll), running-job count, spinner |
| `runner/hooks.sh` | set_up/tear_down (test + script scope), hook failure records, mock clearing, EXIT cleanup |
| `runner/provider.sh` | `@data_provider` argument parsing |
| `runner/exec.sh` | `run_test`, the capture-subshell body, retry, timeout watchdog, per-file dispatch |
| `runner/discovery.sh` | `load_test_files` (the per-file loop), `functions_for_script` |
| `runner/bench.sh` | benchmark file loop and bench function dispatch |
| `helper/index.sh` | aggregator only — sources the `src/helper/` module below |
| `helper/naming.sh` | resolving and normalising test-function and variable names |
| `helper/discovery.sh` | `find_files_recursive`, `find_total_tests`, fn filtering, duplicate check, line lookup |
| `helper/provider.sh` / `helper/tags.sh` | `@data_provider` map; `@tag` extraction and matching |
| `helper/encoding.sh` / `helper/functions.sh` / `helper/git.sh` | base64 + ids; generic fn utilities; remote tag lookup for `upgrade` |
| `state/index.sh` | aggregator only — sources the `src/state/` module below |
| `state/counters.sh` | test and assertion tallies and their get/add accessors |
| `state/duplicates.sh` | duplicate test-function detection state |
| `state/context.sh` | per-test output buffer, exit code, title, hook failure, and the per-test reset |
| `state/payload.sh` | the encoded per-test result payload and the base64 capability probe |
| `state/parallel.sh` | aggregating per-test result files after a `--parallel` run |
| `config/index.sh` | aggregator only — sources the `src/config/` module below |
| `config/env.sh` | all `BASHUNIT_*` defaults/config files, scratch dirs (`_BASHUNIT_RUN_OUTPUT_DIR` + EXIT-trap cleanup); executes at source time |
| `config/rerun.sh` | the `.bashunit/last-failed` cache for `--rerun-failed` |
| `config/parallel.sh` | is this run parallel; worker temp tree and stop-on-failure flag file (not `runner/parallel.sh`, which waits on job slots) |
| `console/index.sh` | aggregator only — sources the `src/console/` module below |
| `console/colors.sh` | the `_BASHUNIT_COLOR_*` palette and `bashunit::sgr` |
| `console/header.sh` | the "Running N tests" header |
| `console/line.sh` | `print_line`, the primitive every result line goes through, and its TAP variant |
| `console/duration.sh` / `console/diff.sh` | duration formatting; unified and line-by-line diffs under a failure |
| `console/test_line.sh` | the per-test result lines (passed/failed/skipped/incomplete/snapshot/risky/error) |
| `console/deferred.sh` | end-of-run blocks buffered during the run (scratch files under the run dir) |
| `console/summary.sh` | run totals, execution time, hook completion |
| `assert/index.sh` | aggregator only — sources the `src/assert/` module below, plus `skip_todo.sh` and `test_doubles.sh` |
| `assert/core.sh` | `assert::should_skip`, `assert::fail_with`, `assert::join_to_slot` and the comparison assertions the other files build on |
| `assert/{arrays,assertions,dates,duration,files,folders,json,once,snapshot}.sh` | the per-topic assertions; the per-assertion path must stay fork-free |
| `util/index.sh` | aggregator only — sources the `src/util/` module below |
| `util/clock.sh` | time impl selection (EPOCHREALTIME > date > perl > …), return-slot reads |
| `util/str.sh` / `util/math.sh` | pure-bash string and arithmetic helpers |
| `api/index.sh` | aggregator only — sources the `src/api/` module below |
| `api/globals.sh` | `temp_file`/`temp_dir`/`current_dir`/`data_set`; repeats `set -euo pipefail` at file scope for anything sourcing it alone — the entrypoint already set it |
| `api/skip_todo.sh` / `api/test_title.sh` | `skip`/`todo` markers; `set_test_title` |
| `api/bashunit.sh` | the custom-assert facade (`assert_that`, `assertion_failed`/`passed`) |
| `doubles/index.sh` | aggregator only — sources the `src/doubles/` module below |
| `doubles/mock.sh` | `mock`/`unmock` and the `_BASHUNIT_MOCKED_FUNCTIONS` registry `runner/hooks.sh` unwinds per test |
| `doubles/spy.sh` | `spy` and its `_BASHUNIT_SPY_*` state slots + files |
| `doubles/assertions.sh` | the `assert_have_been_called*` family |
| `coverage/index.sh` | aggregator only — sources the `src/coverage/` modules below |
| `coverage/config.sh` | data-file locations, tracked-file roots, engine selection (`init` resets state owned by several modules) |
| `coverage/paths.sh` | `normalize_path`, `should_track` and the hot-path track/path caches |
| `coverage/engine.sh` | DEBUG-trap and xtrace capture, buffering, `finalize`/`cleanup`, parallel merge; only active under `--coverage` |
| `coverage/lines.sh` | executable-line classification (fork-free; the report phase's hot path) and hit-data reading |
| `coverage/stats.sh` | percentages, the precomputed per-file stats cache, threshold gate |
| `coverage/functions.sh` | function definitions and their line spans |
| `coverage/branches.sh` | branch extraction + hit computation; **one file on purpose** — the `_branch_*` helpers mutate `extract_branches`'s locals via dynamic scoping |
| `coverage/report_text.sh` / `report_lcov.sh` / `report_html.sh` | the three renderers |
| `coverage/html_index.sh` / `html_file.sh` | HTML page emitters; the only two files exempt from `max_line_length` |

| `reports.sh` | JUnit/HTML/TAP/JSON writers |
| `system/index.sh` | aggregator only — sources the `src/system/` module below |
| `system/check_os.sh` / `system/dependencies.sh` | one-fork OS detect; `command -v` probes (builtins, not forks) |
| `system/io.sh` | small I/O helpers |
| `cli/index.sh` | aggregator only — sources the `src/cli/` module below |
| `cli/{upgrade,watch,doc,init}.sh` | the non-`test` subcommand implementations; `main.sh` is their only caller |
| `learn/index.sh` `benchmark/index.sh` | the remaining non-`test` subcommands; benchmark is shared with `runner/bench.sh` |

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
- **The build flattens the source graph in DFS order** (`build.sh`
  `build::process_file`): a file's body is emitted, *then* its `source` lines are
  recursed into. That equals dev-mode order only if a module aggregator
  (`src/<module>/index.sh`, ADR-010) contains **nothing but `source`
  lines and comments** — any other top-level statement would run before its
  dependencies in the built artifact but after them in dev mode. Files are
  deduped by repo-relative path, so `src/` may hold module dirs and two files may
  share a basename. Every src file's **first line must be the shebang**:
  `tail -n +2` strips it when embedding.
