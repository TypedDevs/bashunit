# Changelog

Older releases are in the [changelog archive](docs/CHANGELOG-archive.md).

## Unreleased

### Added

- A `bashunit` hook for the pre-commit framework: a failing test blocks the commit (#1467)

### Changed

- The globals guide shows how to load files and run tests relative to the test file's own directory (#1468)
- `assert_true` and `assert_false` suggest the `eval ` prefix when a quoted argument with spaces is not a command (#1469)
- Mock text that escaped `\"`, `\$` or `\\` to get around #1470 now prints the backslashes; remove them. Text that relied on expanding `$1` or variables when the mock is called needs the `bashunit::mock <command> <implementation>` form (#1470)

### Fixed

- `bashunit::mock` with a here-string or here-document returns the text literally instead of running its `$`, backticks and quotes as shell code (#1470)
- Without `TMPDIR`, scratch files go to a private per-user `/tmp/bashunit-<uid>` instead of a shared `/tmp/bashunit`, so a second user can run bashunit and nobody can redirect another user's files; a scratch directory that is a link, is owned by someone else, or is writable by another user stops the run, also under a shared `TMPDIR` (#1471)
- `assert_matches` and `assert_not_matches` treat an empty value as one empty line, so `^$` and `.*` match it (#1474)
- `assert_less_than`, `assert_greater_than` and their `_or_equal_` forms compare decimals, and report a non-numeric value once as a usage error instead of a raw bash error and a second failure. `assert_array_length` and `assert_line_count` reject a non-numeric expected value the same way (#1473)
- `upgrade` verifies the download against the release checksum before replacing the installed binary, following the `BASHUNIT_VERIFY_CHECKSUM` rules of `install.sh` (#1472)
- A report or coverage flag that names an existing shell script, usually because its value was left out, stops the run instead of overwriting the test file (#1475)
- The `at <file>:<line>` line under a failure names the failing line in the test body instead of the test definition, and adds `in <helper> at <file>:<line>` when the assertion sits in a helper (#1466)

## [0.53.0](https://github.com/TypedDevs/bashunit/compare/0.52.0...0.53.0) - 2026-11-08

### Added

- Homepage example covering a Bash function, test, run command and passing output
- Release posts for 0.43.0 through 0.52.0, including the 0.50.1 cleanup patch

### Changed

- Faster indexed lookups for large provider and annotation maps on Bash 3.0 and newer (#1392)
- Common patterns moved under Writing Tests; Quickstart links to function and script testing recipes
- Shorter guides, reference pages and release posts
- Faster project test suite: fewer repeated bashunit runs, and contributor docs use `make test/parallel`

### Fixed

- Release preflight checks the repository API through the authenticated GitHub CLI instead of requiring access to the GitHub homepage

#### Assertions and doubles

- Date assertions reject trailing text on macOS and handle colon-separated timezone offsets consistently across platforms (#1404)
- `assert_string_not_starts_with` joins all haystack arguments and labels failures with the test name, matching its siblings (#1403)
- `assert_matches` and `assert_not_matches` accept patterns starting with `-` and fail when grep rejects a pattern (#1398)
- `assert_files_equals` and `assert_files_not_equals` name missing paths and fail when either file is absent (#1397)
- Snapshots record and update `-n`, `-e`, `-E` and combined echo flags literally (#1402)
- Spies keep multiline arguments in one call, including comparisons and failure logs (#1399)
- Call argument assertions reject uncalled spies and missing call indices (#1400)
- `bashunit::unmock` restores functions replaced by spies, mocks or mock sequences (#1401)

#### Setup and selection

- `install.sh` and `upgrade` preserve installed binaries after failed or empty downloads; installation also preserves them after checksum failures (#1406, #1407)
- `install.sh` resolves relative destinations from the caller's directory and reports the resolved path (#1408)
- `install.sh` rejects prefixed or incomplete versions instead of treating them as directories (#1409)
- `init` quotes bootstrap and test paths containing spaces in `.env`. Generated workflows preserve whitespace in test paths without a committed `.env` (#1411, #1425)
- `.bashunitrc` suite options are not exported; global settings before and after suite sections still apply (#1410)
- Include, inline and exclusion filters preserve `test_` within names such as `latest_version` (#1414)
- `--debug` preserves existing test files and directories instead of treating them as trace files (#1405)

#### Test discovery and execution

- Annotations, tags, header counts and duplicate checks support functions without parentheses (#1422)
- Duplicate checks catch definitions with next-line opening braces instead of losing the first definition (#1421)
- Echo providers preserve `#` and parentheses, report malformed rows and keep later rows. Quoted values preserve carriage returns on Windows (#1419)
- SIGTERM and SIGHUP run teardown hooks, stop parallel workers, remove scratch files and exit with status 1 (#1417)
- Parallel results and hook output stay separate for paths differing by slashes and underscores (#1416)
- Relative hidden paths are counted and keep separate results from matching visible paths (#1393)
- Passing many test files by name no longer leaks two open files per path, which crashed macOS Bash 3.2 at about 126 files (#1461)

#### Reports and reruns

- Sequential `--stop-on-failure` writes requested reports and updates the rerun cache for executed tests (#1415)
- Passing file or filtered runs preserve failure-cache entries for unexecuted tests (#1418)
- Coverage paths are checked before tests run; failed LCOV or HTML writes fail the run (#1412)
- TAP keeps titles containing line breaks on one result line (#1413)
- Failure source context stays within a one-line test instead of listing the next function's assertions (#1420)

#### Documentation

- Homepage logo respects reduced motion and stops tracking the pointer after navigation
- Primary buttons use dark text in both themes, including hover and active states
- Quickstart commands match `install.sh` and project or global npm installs

## [0.52.0](https://github.com/TypedDevs/bashunit/compare/0.51.0...0.52.0) - 2026-10-11

### Changed

- Sequential multi-file runs reuse provider and annotation metadata for unchanged test files up to 512 bytes (#1372)
- Parallel reports avoid per-row base64 processes while preserving values and completion order (#1371)
- Data providers avoid per-argument base64 processes while preserving quoting, empty values and parser isolation (#1370)
- JSON reports avoid per-field processes for ordinary filenames, test names and empty messages while preserving escaping (#1369)
- Contributor instructions share task-specific context and model tiers for Claude Code and Codex through a pinned agnostic-ai npm development dependency; shorter workflows align review and release checks with the current code (#1387)

### Fixed

- Releases update and commit project versions in both npm lockfiles and restore them on rollback
- Concurrent provider rows own separate temporary files, even with identical arguments (#1379)
- Synchronous provider rows retain separate results in parallel runs, so later passing rows cannot hide failures (#1377)
- Late timeout signals no longer interrupt `tear_down`; the watchdog still bounds hanging cleanup (#1376)
- Piped parallel output no longer waits for an inactive spinner's sleep process (#1368)
- Cancellation regression checks distinguish exited test bodies awaiting reaping from running cleanup (#1385)
- Bash compatibility checks scan only shell source files, excluding generated contributor instructions (#1387)
- Skipped macOS and Windows acceptance CI jobs have readable names, with shard labels in test steps
- Linux CI installs the standalone build optimizer required by beta installer acceptance tests (#1383)

## [0.51.0](https://github.com/TypedDevs/bashunit/compare/0.50.1...0.51.0) - 2026-09-18

### Changed
- Performance: a `--parallel` run on a shell without `EPOCHREALTIME` no longer forks `perl` once per test. The clock probe resolved inside a command substitution, so the resolved value died with it and every worker re-probed: 502 `perl` execs for a 500-test file, now 2. It happened even with per-test timing off, since deciding that timing is off is what asks whether the clock is expensive. Fixed by #1358; this adds the guards that keep it fixed (#1353)
- A helper can ship a faster body for a newer Bash and keep the Bash 3.0 one as a fallback, chosen once at load time. The floor does not move: 3.0 keeps working and keeps being tested. The compatibility rules now record each construct's minimum version instead of only banning it, and allow one inside a matching version gate, never for a construct that is a parse error on the floor. See `adrs/adr-013-bash-version-gated-fast-paths.md` (#1352)
- Performance: a file defining `set_up_before_script` or `tear_down_after_script` costs about 5.6ms less on Bash 3.2, and a test rendered with `--show-execution-time` about 0.74ms less. Four clock reads per file and the per-test padding no longer go through a capture subshell (#1348)
- Performance: startup is faster on suites of plain test files. Printing "Running N tests" sourced every file a second time and re-ran every data provider before the run began. A file whose functions the provider scan can already see is counted from that scan instead: over this repo's 241 files the counting pass went from 1.72s to 1.51s, and 124 of them no longer source or run a provider twice. Files with a data provider, a heredoc, a multi-line string, an `eval`, a nested `source` or a conditional definition keep the old path, so the count can never disagree with the run (#1347)
- Performance: a sequential run is about 0.7ms faster per test, taking a 500-test file from 2.75s to 2.40s on macOS arm64, bash 3.2. A test's `<file>:<line>` is resolved on demand instead of forking a subshell per test to read it (#1346)
- A standalone `bashunit assert <fn> ...` no longer reports a source location belonging to another process. Launched from inside a test, it inherited that test's exported location and printed it as its own (#1346)
- Performance: a test in a file that defines `set_up` or `tear_down` is about 2.6x faster, 14.1ms to 5.4ms per test on macOS arm64, bash 3.2, which brings it level with a hookless test. Each hook minted its output file with `mktemp` and removed it with `rm`, and the ownership marker that left behind made the runner sweep the test's temp files at exit: five forks per test, even for a test that created no temp file (#1345)

### Fixed
- The deprecation warning for the old `--assert` option names the invocation you typed: `bashunit -a`, `bashunit --assert` or `bashunit test --assert`. It always said `bashunit test --assert`, because `bashunit -a` reaches that path through the inferred `test` subcommand, so it read like a warning about a command you never ran (#1366)
- `assert_contains_ignore_case` documents what it actually guarantees: ASCII case folding. Whether `ñ` matches `Ñ` depends on the shell version, the locale and which `tr` the system ships. Behaviour is unchanged (#1351)
- A test function whose name another selected name starts with is no longer rejected as a duplicate. `test_a` alongside `test_ab` read as one name twice, which made the whole file select nothing (#1347)
- Coverage counts every line of a multiline statement: array literals, quoted strings, heredocs, backslash continuations. An array written one element per line cost one uncovered line per element, and on Bash 3.x the whole array read as uncovered. A parent statement's hits no longer mark commands inside command or process substitutions as covered (#1338)
- `--exclude-filter` keeps a comma as part of the test function name. The value was split at the comma, so `--exclude-filter 'test_a,{b}'` also excluded `test_a`. Repeat the flag to exclude several names. `BASHUNIT_EXCLUDE_FILTER` stays comma-separated (#1340)
- A `--parallel` run no longer replays bash's `child setpgid` warning as the stderr of a file that wrote nothing. The child sets its process group first, so only the message was ever wrong (#1344)
- A timed-out test finishes its `tear_down`. The watchdog allowed a flat 0.3s between SIGTERM and SIGKILL, which a loaded machine missed in about one parallel full-suite run in three. It now polls for the body to exit, capped at 2s (#1344)

## [0.50.1](https://github.com/TypedDevs/bashunit/compare/0.50.0...0.50.1) - 2026-08-22

### Fixed
- `tear_down_after_script` runs when `set_up_before_script` fails, so it can release file-scoped resources acquired before the failure (#1318)
- Under `--parallel`, `tear_down_after_script` runs after the file's own tests instead of alongside them, so a fixture it releases stays alive for the tests that read it. The same file no longer passed sequentially and failed in parallel (#1320)
- `--stop-on-failure` runs `tear_down_after_script` for the file it halts in, so a sequential run releases what `set_up_before_script` acquired before the halt (#1321)
- `bashunit bench` runs `tear_down_after_script` before it aborts on a malformed annotation, so the file releases what `set_up_before_script` acquired (#1322)
- Ctrl-C runs `tear_down_after_script` for the file it interrupts in a sequential run, so a file-scoped resource is released. A second Ctrl-C now ends the run even if that hook never returns (#1323)
- A test killed by `--test-timeout` runs its `tear_down`, so a per-test resource is released. Best effort within the watchdog's grace before it sends SIGKILL, so a hook cannot outlive the timeout it cleans up after (#1324)
- A test file that fails to source sweeps its script temp files, so a `bashunit::temp_file` it created at top level no longer survives the run. `bashunit bench` already did this (#1325)
- A malformed `@timeout` or `@retry` runs `tear_down_after_script` before it aborts the run, so the file releases what `set_up_before_script` acquired. Sequential and `--parallel` both leaked it (#1329)
- Ctrl-C releases what an interrupted `--parallel` run acquired: the file's `tear_down_after_script` and the `tear_down` of a test in flight. The worker that owns the file's hook now handles the signal and reaches its test bodies, which a kill from the parent could not (#1331)
- A malformed `@timeout` or `@retry` fails a `--parallel` run alongside a passing file. The abort happened inside the file's worker and never reached the parent, so the run printed the error and still exited 0, which kept it out of CI (#1335)

## [0.50.0](https://github.com/TypedDevs/bashunit/compare/0.49.0...0.50.0) - 2026-08-18

### Added
- `-u` as the short form of `--snapshot-update`, the spelling jest and vitest both use (#1293)

### Changed
- `--seed <n>` now implies `--random-order`. Replaying a failure with the seed the header printed used to select nothing, so the run came back in defined order and green. An order named explicitly still wins, as in RSpec (#1287)
- Performance: cold start is about 9ms faster, roughly 15%. The colour palette cost one subshell fork per colour, and every invocation paid it — `--version` included (#1285)
- Performance: a `--parallel` run writing a report is about 1.9x faster and uses 1.8x less CPU. Each result row cost fourteen `base64` forks per test, so `--log-junit` cost several times more than running the tests (#1289)

### Fixed
- `--output json` and `--output junit` are no longer corrupted by console text on stdout, which left the document unparseable. Four sources: an empty `--parallel` selection (#1295), the blank line after a `tear_down_after_script` (#1297), the duplicate-function abort, and a `--parallel` worker's stderr replay (#1299)
- `--parallel` reports no longer count a file-level hook failure twice. JSON, JUnit, HTML and Markdown listed it as two failed tests while the console summary of the same run said one (#1301)
- `bashunit bench` exits non-zero when a benchmark file fails to source or its `set_up_before_script` fails. It printed the error and exited 0, so the failure never reached CI, and a syntax error silently dropped every `bench_` function after it (#1303)
- `--output tap` escapes `#` in a test description, as `--report-tap` already did. A failing test titled `... # SKIP ...` reached the consumer as a skip and left CI silently (#1309)
- `bashunit watch` no longer takes an option's value as the path it polls: `watch --tag slow tests/` polled a directory named `slow`. Options may now appear in any position (#1291)
- The JUnit report escapes the file path; a name holding `"`, `&` or `<` closed the attribute early and the document stopped parsing (#1313)
- The Cobertura report escapes XML metacharacters in a path, so GitLab, Azure and Jenkins render coverage instead of silently showing nothing (#1311)
- GitHub Actions annotations encode `:` and `,` in their property values; a comma in a test title ended the title there and invented a property (#1307)
- A ``` fence in a failure message no longer truncates the `--report-md` summary, which is appended to `$GITHUB_STEP_SUMMARY` (#1305)

### Security
- A test file's path is no longer evaluated as shell. The per-test EXIT trap interpolated the path into the trap string, and a trap body is re-evaluated when it fires, so a filename holding a command substitution executed it — reachable by any run over a tree whose filenames someone else controls, which is what CI does with a checked-out branch. The same mangling meant such a file's assertions never ran and it was reported `risky` instead of failing (#1315)

### Removed
- `bashunit learn`, the interactive tutorial. Nobody used it, and it was broken for most of the nine months it shipped without anyone reporting it. Learning bashunit belongs in the docs at https://bashunit.com, not in a subsystem inside the runner — which is also 6% of the distributable. Calling it now says it was removed and points there (#1256, #1258)
