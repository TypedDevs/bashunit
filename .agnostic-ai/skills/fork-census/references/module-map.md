# Module map

Module paths are under `src/` unless stated otherwise. Verify the current caller before relying on a row.

| Module | Owns |
|--------|------|
| `bashunit` | entry: version gate, early flag scan, sources every module, subcommand routing |
| `main/index.sh` | aggregator only, sources the `src/main/` module below |
| `main/validate.sh` | shared parser validation: unknown options, integer/path checks, shard parsing |
| `main/test.sh` / `main/bench.sh` / `main/subcommands.sh` | flag parsing per subcommand |
| `main/assert.sh` | the standalone `bashunit assert` path |
| `main/watch.sh` / `main/run.sh` | the `--watch` loop; the run lifecycle, exit codes and cleanup |
| `runner/index.sh` | aggregator only, sources the `src/runner/` module below |
| `runner/context.sh` | workdir restore, test identity/location exports, title interpolation, capability probes |
| `runner/payload.sh` | the `_BASHUNIT_RUNNER_*_OUT` return slots; encode/decode of the per-test result payload |
| `runner/diagnostics.sh` | runtime-error detection, kill-signal classification, profiling, verbose/file headers |
| `runner/result.sh` | `parse_result{,_sync,_parallel}`, failure source context, failed/skipped/incomplete/risky writers |
| `runner/parallel.sh` | job-slot waiting (`wait -n` or poll), running-job count, spinner |
| `runner/hooks.sh` | set_up/tear_down (test + script scope), hook failure records, mock clearing, EXIT cleanup |
| `runner/provider.sh` | `@data_provider` argument parsing |
| `runner/exec.sh` | `run_test`, the capture-subshell body, retry, timeout watchdog, per-file dispatch, `order_functions_for_script` (the run order a seed produces) |
| `runner/list.sh` | `--list`/`--dry-run`: emits selected tests instead of running them; hooks in after all filtering, before any hook |
| `runner/sandbox.sh` | `--sandbox`: fails a test that reaches an unmocked external command (ADR-012) |
| `runner/discovery.sh` | `load_test_files` (the per-file loop), `functions_for_script` |
| `runner/bench.sh` | benchmark file loop and bench function dispatch |
| `helper/index.sh` | aggregator only, sources the `src/helper/` module below |
| `helper/naming.sh` | resolving and normalising test-function and variable names |
| `helper/discovery.sh` | `find_files_recursive`, `find_total_tests`, fn filtering, duplicate check, line lookup |
| `helper/provider.sh` / `helper/tags.sh` | `@data_provider` map; `@tag` extraction and matching |
| `helper/annotations.sh` | per-test `@timeout`, `@retry` and `@skip` records; the scan lives in `build_provider_map` |
| `helper/metadata.sh` | the indexed metadata map lookups |
| `helper/encoding.sh` / `helper/functions.sh` / `helper/git.sh` | base64 + ids; generic fn utilities; remote tag lookup for `upgrade` |
| `state/index.sh` | aggregator only, sources the `src/state/` module below |
| `state/counters.sh` | test and assertion tallies and their get/add accessors |
| `state/duplicates.sh` | duplicate test-function detection state |
| `state/context.sh` | per-test output buffer, exit code, title, hook failure, and the per-test reset |
| `state/payload.sh` | the encoded per-test result payload and the base64 capability probe |
| `state/parallel.sh` | aggregating per-test result files after a `--parallel` run |
| `config/index.sh` | aggregator only, sources the `src/config/` module below |
| `config/env.sh` | all `BASHUNIT_*` defaults/config files, scratch dirs (`_BASHUNIT_RUN_OUTPUT_DIR` + EXIT-trap cleanup); executes at source time |
| `config/rerun.sh` | the `.bashunit/last-failed` cache for `--rerun-failed` |
| `config/suites.sh` | named `[suite:<name>]` sections in `.bashunitrc` |
| `config/parallel.sh` | is this run parallel; worker temp tree and stop-on-failure flag file (not `runner/parallel.sh`, which waits on job slots) |
| `console/index.sh` | aggregator only, sources the `src/console/` module below |
| `console/colors.sh` | the `_BASHUNIT_COLOR_*` palette and `bashunit::sgr` |
| `console/header.sh` | the "Running N tests" header |
| `console/line.sh` | `print_line`, the primitive every result line goes through, and its TAP variant |
| `console/duration.sh` / `console/diff.sh` | duration formatting; unified and line-by-line diffs under a failure |
| `console/test_line.sh` | the per-test result lines (passed/failed/skipped/incomplete/snapshot/risky/error) |
| `console/deferred.sh` | end-of-run blocks buffered during the run (scratch files under the run dir) |
| `console/summary.sh` | run totals, execution time, hook completion |
| `assert/index.sh` | aggregator only, sources the `src/assert/` module below, plus `skip_todo.sh` and `test_doubles.sh` |
| `assert/core.sh` | `assert::should_skip`, `assert::fail_with`, `assert::join_to_slot` and the comparison assertions the other files build on |
| `assert/{arrays,assertions,dates,duration,files,folders,json,once,snapshot}.sh` | the per-topic assertions; the per-assertion path must stay fork-free |
| `util/index.sh` | aggregator only, sources the `src/util/` module below |
| `util/clock.sh` | time impl selection (EPOCHREALTIME > date > perl > …), return-slot reads |
| `util/str.sh` / `util/math.sh` | pure-bash string and arithmetic helpers |
| `api/index.sh` | aggregator only, sources the `src/api/` module below |
| `api/globals.sh` | `temp_file`/`temp_dir`/`current_dir`/`data_set`; repeats `set -euo pipefail` at file scope for anything sourcing it alone, the entrypoint already set it |
| `api/skip_todo.sh` / `api/test_title.sh` | `skip`/`todo` markers; `set_test_title` |
| `api/bashunit.sh` | the custom-assert facade (`assert_that`, `assertion_failed`/`passed`) |
| `doubles/index.sh` | aggregator only, sources the `src/doubles/` module below |
| `doubles/mock.sh` | `mock`/`unmock` and the `_BASHUNIT_MOCKED_FUNCTIONS` registry `runner/hooks.sh` unwinds per test |
| `doubles/spy.sh` | `spy` and its `_BASHUNIT_SPY_*` state slots + files |
| `doubles/assertions.sh` | the `assert_have_been_called*` family |
| `coverage/index.sh` | aggregator only, sources the `src/coverage/` modules below |
| `coverage/config.sh` | data-file locations, tracked-file roots, engine selection (`init` resets state owned by several modules) |
| `coverage/paths.sh` | `normalize_path`, `should_track` and the hot-path track/path caches |
| `coverage/engine.sh` | DEBUG-trap and xtrace capture, buffering, `finalize`/`cleanup`, parallel merge; only active under `--coverage` |
| `coverage/lines.sh` | executable-line classification (fork-free; the report phase's hot path) and hit-data reading |
| `coverage/stats.sh` | percentages, the precomputed per-file stats cache, threshold gate |
| `coverage/functions.sh` | function definitions and their line spans |
| `coverage/branches.sh` | branch extraction + hit computation; one file, the `_branch_*` helpers mutate `extract_branches`'s locals via dynamic scoping |
| `coverage/report_text.sh` / `report_lcov.sh` / `report_html.sh` | the three renderers |
| `coverage/report_cobertura.sh` | the Cobertura XML renderer |
| `coverage/rules_awk.sh` | the line classifier as awk source; `coverage/lines.sh` stays the reference implementation |
| `coverage/diff.sh` | diff coverage: restricts the report to lines changed against a base ref |
| `coverage/html_index.sh` / `html_file.sh` | HTML page emitters; the only two files exempt from `max_line_length` |
| `reports/index.sh` | aggregator only, sources the `src/reports/` module below |
| `reports/collect.sh` | the shared per-test result arrays every writer reads, and the API the runner fills them through |
| `reports/{junit,html,tap,json,markdown,gha}.sh` | the report writers: JUnit, HTML, TAP, JSON, the Markdown run summary, GitHub Actions annotations |
| `system/index.sh` | aggregator only, sources the `src/system/` module below |
| `system/check_os.sh` / `system/dependencies.sh` | one-fork OS detect; `command -v` probes (builtins, not forks) |
| `system/io.sh` | small I/O helpers |
| `system/bash.sh` | what the running Bash can do, decided once at load time |
| `cli/index.sh` | aggregator only, sources the `src/cli/` module below |
| `cli/{upgrade,watch,doc,init}.sh` | the non-`test` subcommand implementations; main subcommand routing calls them |
| `benchmark/index.sh` | aggregator only, sources the `src/benchmark/` module below; shared with `runner/bench.sh` |
| `benchmark/{annotations,run,results,baseline,reports}.sh` | `@revs`/`@its`/`@max_ms` parsing, running one bench function, the results table, baseline comparison, JSON and JUnit writers |
| `dev/debug.sh` | `bashunit::dump` and `bashunit::dd` for local debugging, not used by the runner |
