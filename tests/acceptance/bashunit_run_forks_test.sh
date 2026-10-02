#!/usr/bin/env bash
set -euo pipefail

function test_parallel_runs_do_not_start_a_spinner_without_visible_progress() {
  local dir
  dir="$(bashunit::temp_dir)"
  local fixture="$dir/inactive_spinner_test.sh"
  printf 'function test_without_spinner() { assert_same 1 1; }\n' >"$fixture"

  local bootstrap="$dir/bootstrap.sh"
  cat >"$bootstrap" <<'BOOTSTRAP'
function bashunit::runner::spinner() {
  printf 'started\n' >"$BASHUNIT_SPINNER_MARKER"
}
# Bash 3.0 cannot target names containing :: with declare -f.
definition=$(declare -f | awk '
  /^bashunit::state::aggregate_parallel_results \(\)/ { copy = 1 }
  copy { print }
  copy && /^}$/ { copy = 0 }
')
definition=${definition/bashunit::state::aggregate_parallel_results/bashunit_probe_aggregate}
eval "$definition"
function bashunit::state::aggregate_parallel_results() {
  wait
  bashunit_probe_aggregate "$@"
}
BOOTSTRAP

  local mode output marker
  local flags
  for mode in normal no_progress json; do
    flags=()
    case "$mode" in
    no_progress) flags=(--no-progress) ;;
    json) flags=(--output json) ;;
    esac
    marker="$dir/$mode"
    output=$(BASHUNIT_BOOTSTRAP="$bootstrap" BASHUNIT_SPINNER_MARKER="$marker" \
      ./bashunit --parallel --simple --skip-env-file ${flags+"${flags[@]}"} "$fixture" 2>&1)
    assert_successful_code "$?"
    assert_file_not_exists "$marker"
    case "$mode" in
    json) assert_contains '"passed": 1' "$output" ;;
    *) assert_contains '1 passed' "$output" ;;
    esac
  done
}

# Regression guard for the per-file run path. Running a test file used to fork
# `grep` twice: once in the runner to scan sourcing stderr for "syntax error"/
# "unexpected EOF", and once in discovery to decide whether to also match the
# `.bash` variant of the test pattern. Both are shell `case` matches now, so a
# plain run forks `grep` zero times — this matters across the acceptance suite's
# ~258 nested runs, each of which sources at least one test file.
function test_running_a_test_file_does_not_fork_grep() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "process tracing is unreliable under Git Bash" && return
  fi

  local dir
  dir="$(bashunit::temp_dir)"
  local fixture="$dir/grep_forks_test.sh"
  printf 'function test_ok() { assert_true true; }\n' >"$fixture"

  local trace
  trace="$(PS4='+ ' bash -x ./bashunit --no-parallel "$fixture" 2>&1 >/dev/null)"

  # Count real `grep` process executions (resolved absolute path with args).
  local grep_forks
  grep_forks="$(printf '%s\n' "$trace" | grep -cE '^\++ +/[^ ]*grep ' || true)"

  assert_equals 0 "$grep_forks"
}

# Regression guard: exporting a test's subshell result must not fork `cat`. It
# used to emit the encoded result payload with a `cat <<EOF` heredoc — one fork
# per test — which `printf` (a builtin) does without forking. Four independent
# tests must therefore fork `cat` far fewer than four times.
function test_running_tests_does_not_fork_cat_per_test() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "process tracing is unreliable under Git Bash" && return
  fi

  local dir
  dir="$(bashunit::temp_dir)"
  local fixture="$dir/cat_forks_test.sh"
  {
    echo 'function test_a() { assert_true true; }'
    echo 'function test_b() { assert_true true; }'
    echo 'function test_c() { assert_true true; }'
    echo 'function test_d() { assert_true true; }'
  } >"$fixture"

  local trace
  trace="$(PS4='+ ' bash -x ./bashunit --no-parallel "$fixture" 2>&1 >/dev/null)"

  local cat_forks
  cat_forks="$(printf '%s\n' "$trace" | grep -cE '^\++ +/?[a-z/]*cat( |$)' || true)"

  assert_less_or_equal_than 1 "$cat_forks"
}

# Regression guard: rendering the "Source:" assert-line context of a failing
# test must not fork `sed` once per line of the test function's body. The body
# is read in a single pass now, so the `sed` fork count does not grow with the
# function length (a 20-line body used to cost ~20 `sed` forks here).
function test_failure_source_context_does_not_fork_sed_per_line() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "process tracing is unreliable under Git Bash" && return
  fi

  local dir
  dir="$(bashunit::temp_dir)"
  local fixture="$dir/long_fail_test.sh"
  {
    echo 'function test_long_fail() {'
    local i
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
      echo "  assert_same \"$i\" \"$i\""
    done
    echo '  assert_same "expected" "actual"'
    echo '}'
  } >"$fixture"

  local trace
  trace="$(PS4='+ ' bash -x ./bashunit --no-parallel "$fixture" 2>&1 >/dev/null)" || true

  local sed_forks
  sed_forks="$(printf '%s\n' "$trace" | grep -cE '^\++ +/?[a-z/]*sed ' || true)"

  assert_less_than 10 "$sed_forks"
}

# Regression guard: ordering a file's test functions by definition line used to
# pipe `declare -F` through `awk | sort | awk` — and the pipeline ran twice per
# file. The ordering is pure bash now, so a plain run forks `sort` zero times.
# Counted with a PATH shim (a `bash -x` trace would also count re-echoed test
# output, inflating the numbers).
function test_running_a_test_file_does_not_fork_sort() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "PATH shims are unreliable under Git Bash" && return
  fi

  local real_sort
  real_sort="$(command -v sort)"
  local dir
  dir="$(bashunit::temp_dir)"
  local count_file="$dir/count"
  {
    echo '#!/usr/bin/env bash'
    echo "echo x >> \"$count_file\""
    echo "exec \"$real_sort\" \"\$@\""
  } >"$dir/sort"
  chmod +x "$dir/sort"

  local fixture="$dir/sort_forks_test.sh"
  {
    echo 'function test_zz_first() { assert_true true; }'
    echo 'function test_aa_second() { assert_true true; }'
  } >"$fixture"

  PATH="$dir:$PATH" ./bashunit --no-parallel "$fixture" >/dev/null 2>&1

  local sort_forks=0
  if [ -f "$count_file" ]; then
    sort_forks="$(grep -c . "$count_file" || true)"
  fi

  assert_equals 0 "$sort_forks"
}

# Regression guard: listing all defined functions must use the `compgen -A
# function` builtin, not a `declare -F | awk` fork. The remaining awk budget of
# a single-file run is one data-provider scan (built once in the main shell so
# the header-count subshell and the runner both hit the cache) plus the
# duplicate-name check.
function test_running_a_test_file_stays_within_the_awk_fork_budget() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "PATH shims are unreliable under Git Bash" && return
  fi

  local real_awk
  real_awk="$(command -v awk)"
  local dir
  dir="$(bashunit::temp_dir)"
  local count_file="$dir/count"
  {
    echo '#!/usr/bin/env bash'
    echo "echo x >> \"$count_file\""
    echo "exec \"$real_awk\" \"\$@\""
  } >"$dir/awk"
  chmod +x "$dir/awk"

  local fixture="$dir/awk_budget_test.sh"
  printf 'function test_ok() { assert_true true; }\n' >"$fixture"

  PATH="$dir:$PATH" ./bashunit --no-parallel "$fixture" >/dev/null 2>&1

  local awk_forks=0
  if [ -f "$count_file" ]; then
    awk_forks="$(grep -c . "$count_file" || true)"
  fi

  assert_less_or_equal_than 2 "$awk_forks"
}

# Each mode needs its own temp owner when the acceptance suite runs in parallel.
function _assert_multifile_metadata_scan_budget() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "PATH shims are unreliable under Git Bash" && return
  fi

  local mode=$1 expected=$2 dir real_awk count_file file
  dir="$(bashunit::temp_dir)"
  count_file="$dir/awk_count"
  : >"$count_file"
  real_awk="$(command -v awk)"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf 'printf "awk\\n" >>"%s"\n' "$count_file"
    printf 'exec "%s" "$@"\n' "$real_awk"
  } >"$dir/awk"
  chmod +x "$dir/awk"

  local -a fixtures=() flags=(--no-parallel --simple)
  for file in 1 2 3; do
    fixtures[${#fixtures[@]}]="$dir/metadata_${file}_test.sh"
    printf 'function test_metadata_case_%s() { assert_same same same; }\n' "$file" \
      >"$dir/metadata_${file}_test.sh"
  done

  local header=true
  case "$mode" in
  no_header) header=false ;;
  list) flags=(--no-parallel --list) ;;
  json) flags=(--no-parallel --output json) ;;
  parallel_simple) flags=(--parallel --simple) ;;
  parallel_header) flags=(--parallel) ;;
  esac

  local status=0
  PATH="$dir:$PATH" BASHUNIT_SHOW_HEADER="$header" ./bashunit --skip-env-file \
    "${flags[@]}" "${fixtures[@]}" >"$dir/output" 2>&1 || status=$?

  assert_same 0 "$status"
  assert_same "$expected" "$(wc -l <"$count_file" | tr -d ' ')"
}

function test_multifile_metadata_scans_with_a_header() {
  _assert_multifile_metadata_scan_budget header 6
}

function test_multifile_metadata_scans_without_a_header() {
  _assert_multifile_metadata_scan_budget no_header 6
}

function test_multifile_metadata_listing_skips_scans() {
  _assert_multifile_metadata_scan_budget list 0
}

function test_multifile_metadata_machine_output_scans() {
  _assert_multifile_metadata_scan_budget json 6
}

function test_multifile_metadata_parallel_simple_scans() {
  _assert_multifile_metadata_scan_budget parallel_simple 6
}

function test_multifile_metadata_parallel_header_scans() {
  _assert_multifile_metadata_scan_budget parallel_header 8
}

function test_run_removes_its_run_output_dir() {
  local dir
  dir="$(bashunit::temp_dir)"
  local fixture="$dir/leak_probe_test.sh"
  printf 'function test_ok() { assert_true true; }\n' >"$fixture"

  TMPDIR="$dir" ./bashunit --no-parallel "$fixture" >/dev/null 2>&1
  # Early-exit paths (no test run) must clean up via the EXIT trap.
  TMPDIR="$dir" ./bashunit --version >/dev/null 2>&1

  local leftover=0
  if [ -d "$dir/bashunit/run" ]; then
    local entry
    for entry in "$dir/bashunit/run"/*/*; do
      [ -e "$entry" ] && leftover=$((leftover + 1))
    done
  fi

  assert_equals 0 "$leftover"
}

# Regression guard for the parallel per-test result path. Publishing each
# test's result file used to fork `basename` (suite dir name), `mkdir -p`
# (suite dir, per test), an `echo | tr | sed` pipeline (arg sanitizing, even
# with no args) and a final `mv` (adding the `.result` suffix to the mktemp
# name) — ~5 forks per test in the mode CI runs everything in. The dir name is
# parameter expansion now, mkdir is guarded by a `[ -d ]` builtin check, arg
# sanitizing is skipped when there are no provider args, and the result file is
# named by a per-suite ordinal (no mktemp, no mv).
function test_parallel_result_publishing_does_not_fork_per_test() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "PATH shims are unreliable under Git Bash" && return
  fi

  local dir
  dir="$(bashunit::temp_dir)"
  local count_file="$dir/count"
  local bin
  for bin in basename tr sed mv; do
    local real_bin
    real_bin="$(command -v "$bin")"
    {
      echo '#!/usr/bin/env bash'
      echo "echo $bin >> \"$count_file\""
      echo "exec \"$real_bin\" \"\$@\""
    } >"$dir/$bin"
    chmod +x "$dir/$bin"
  done

  local fixture="$dir/parallel_forks_test.sh"
  {
    echo 'function test_a() { assert_true true; }'
    echo 'function test_b() { assert_true true; }'
    echo 'function test_c() { assert_true true; }'
    echo 'function test_d() { assert_true true; }'
  } >"$fixture"

  PATH="$dir:$PATH" ./bashunit --parallel "$fixture" >/dev/null 2>&1

  # Assert on the shim log's content, not a count: a failure then names the
  # offending binary directly in the test output.
  local forked=""
  if [ -f "$count_file" ]; then
    forked="$(sort "$count_file" | uniq -c | tr -d '\n')"
  fi

  assert_equals "" "$forked"
}

# A PATH shim sees codec processes inside workers that the parent trace misses.
function test_reports_do_not_fork_base64_per_field() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "process tracing is unreliable under Git Bash" && return
  fi

  local dir
  dir="$(bashunit::temp_dir)"
  local count_file="$dir/base64_calls"
  local real_base64
  real_base64="$(command -v base64)"

  {
    echo '#!/usr/bin/env bash'
    # The load-time `base64 --help` capability probe is not a per-test cost.
    echo "case \"\$*\" in --help) ;; *) echo x >> \"$count_file\" ;; esac"
    echo "exec \"$real_base64\" \"\$@\""
  } >"$dir/base64"
  chmod +x "$dir/base64"

  local fixture="$dir/report_forks_test.sh"
  {
    echo 'function test_a() { assert_true true; }'
    echo 'function test_b() { assert_true true; }'
    echo 'function test_c() { assert_true true; }'
    echo 'function test_d() { assert_true true; }'
  } >"$fixture"

  PATH="$dir:$PATH" ./bashunit --parallel --log-junit "$dir/out.xml" "$fixture" \
    >/dev/null 2>&1

  local calls=0
  if [ -f "$count_file" ]; then
    calls="$(grep -c . "$count_file" || true)"
  fi

  assert_equals 0 "$calls"
}

function test_parallel_reports_keep_lifecycle_rows_and_remove_scratch_records() {
  local dir
  dir="$(bashunit::temp_dir)"
  mkdir "$dir/a" "$dir/b"
  printf '%s\n' 'function data_spool_values() { printf "%s\n" "a:b" "a/b"; }
# @data_provider data_spool_values
function test_spool_provider_rows() { assert_true true; }
# @skip intentional
function test_spool_skip() { assert_same never ran; }
# @retry 1
function test_spool_retry() {
  if [ -f "$REPORT_RETRY_MARKER" ]; then
    assert_true true
  else
    : >"$REPORT_RETRY_MARKER"
    assert_same first second
  fi
}
# @data_provider undefined_spool_provider
function test_spool_missing_provider() { assert_same never ran; }
function tear_down_after_script() { printf "worker teardown failure\n"; return 1; }' >"$dir/a/same_test.sh"
  printf '%s\n' 'function set_up_before_script() { printf "parent setup failure\n"; return 1; }
function test_spool_blocked_by_setup() { assert_same never ran; }
function tear_down_after_script() { printf "parent teardown failure\n"; return 1; }' >"$dir/b/same_test.sh"

  local exit_code=0
  TMPDIR="$dir" REPORT_RETRY_MARKER="$dir/retried" ./bashunit --skip-env-file --parallel --simple \
    --report-junit "$dir/out.xml" --report-json "$dir/out.json" --report-tap "$dir/out.tap" \
    --report-html "$dir/out.html" --report-md "$dir/out.md" --log-gha "$dir/out.gha" \
    "$dir/a/same_test.sh" "$dir/b/same_test.sh" >"$dir/console" 2>&1 || exit_code=$?

  assert_same 1 "$exit_code"
  assert_file_contains "$dir/out.json" '"total": 8, "passed": 3, "failed": 4, "skipped": 1'
  assert_file_contains "$dir/out.json" '"flaky": 1'
  assert_same 8 "$("$GREP" -c '"name":' "$dir/out.json")"
  assert_same 8 "$("$GREP" -c '<testcase ' "$dir/out.xml")"
  assert_file_contains "$dir/out.xml" 'tests="8" failures="4" skipped="1"'
  assert_file_contains "$dir/out.tap" '1..8'
  assert_file_contains "$dir/out.html" 'parent setup failure'
  assert_file_contains "$dir/out.md" '| Failed | 4 |'
  assert_same 4 "$("$GREP" -c '^::error ' "$dir/out.gha")"
  assert_same 1 "$("$GREP" -c '^::warning ' "$dir/out.gha")"

  local leftover=0
  local entry
  for entry in "$dir/bashunit/run"/*/*; do
    [ -e "$entry" ] && leftover=$((leftover + 1))
  done
  assert_same 0 "$leftover"
}

function test_provider_arguments_do_not_fork_base64_per_value() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "PATH shims are unreliable under Git Bash" && return
  fi

  local dir
  dir="$(bashunit::temp_dir)"
  local count_file="$dir/base64_calls"
  local real_base64
  real_base64="$(command -v base64)"
  {
    echo '#!/usr/bin/env bash'
    echo "case \"\$*\" in --help) ;; *) echo x >> \"$count_file\" ;; esac"
    echo "exec \"$real_base64\" \"\$@\""
  } >"$dir/base64"
  chmod +x "$dir/base64"

  local fixture="$dir/provider_forks_test.sh"
  {
    echo 'function provide_rows() {'
    echo '  bashunit::data_set a b'
    echo '  bashunit::data_set c d'
    echo '  bashunit::data_set e f'
    echo '}'
    echo '# @data_provider provide_rows'
    echo 'function test_row() { assert_not_empty "$1"; assert_not_empty "$2"; }'
  } >"$fixture"

  local code=0
  PATH="$dir:$PATH" ./bashunit --no-parallel "$fixture" >/dev/null 2>&1 || code=$?
  assert_same 0 "$code"

  local calls=0
  if [ -f "$count_file" ]; then
    calls="$(grep -c . "$count_file" || true)"
  fi
  assert_equals 0 "$calls"
}

# Regression guard for the per-test hook path. A test in a file that defines
# `set_up` or `tear_down` used to cost five process forks: each hook minted its
# output file with `mktemp` and removed it with `rm -f`, and the temp-owner
# marker `mktemp` left behind made the EXIT trap `rm -rf` the test's temp files
# even when the test itself created none. That is 3.3x the cost of a hookless
# test (28.3ms vs 8.5ms). The hook output file is named arithmetically inside
# the run directory now, and the `>` redirect truncates it, so a hooked test
# forks neither binary — only the run's own single `rm` of its scratch dir
# remains.
function test_test_hooks_do_not_fork_mktemp_or_rm_per_test() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "PATH shims are unreliable under Git Bash" && return
  fi

  local dir
  dir="$(bashunit::temp_dir)"
  local count_file="$dir/count"
  local bin
  for bin in mktemp rm; do
    local real_bin
    real_bin="$(command -v "$bin")"
    {
      echo '#!/usr/bin/env bash'
      echo "echo $bin >> \"$count_file\""
      echo "exec \"$real_bin\" \"\$@\""
    } >"$dir/$bin"
    chmod +x "$dir/$bin"
  done

  local fixture="$dir/hook_forks_test.sh"
  {
    echo 'function set_up() { :; }'
    echo 'function tear_down() { :; }'
    echo 'function test_a() { assert_true true; }'
    echo 'function test_b() { assert_true true; }'
    echo 'function test_c() { assert_true true; }'
    echo 'function test_d() { assert_true true; }'
  } >"$fixture"

  PATH="$dir:$PATH" ./bashunit --no-parallel "$fixture" >/dev/null 2>&1

  local mktemp_forks=0
  local rm_forks=0
  if [ -f "$count_file" ]; then
    mktemp_forks="$(grep -c '^mktemp$' "$count_file" || true)"
    rm_forks="$(grep -c '^rm$' "$count_file" || true)"
  fi

  assert_equals 0 "$mktemp_forks"
  # The run's own scratch-dir cleanup, and nothing per test.
  assert_less_or_equal_than 1 "$rm_forks"
}

# Regression guard for the parallel clock probe. Resolving the clock
# implementation used to happen inside a `$( )`, so the resolved value died
# with that subshell and every --parallel worker re-probed. On a shell without
# EPOCHREALTIME the probe forks `perl`, so the count scaled one-for-one with
# the tests: 502 execs for a 500-test file against 2 (#1353). It fired even
# with per-test timing off, because deciding that timing is off is what asks
# whether the clock is expensive, which resolves the impl.
#
# Asserted as a differential rather than a budget: on a platform whose clock is
# `EPOCHREALTIME` or `date` this forks no `perl` at all, and comparing two sizes
# still fails loudly if the count ever starts tracking the test count.
function test_parallel_clock_probes_do_not_scale_with_the_test_count() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "PATH shims are unreliable under Git Bash" && return
  fi

  local dir
  dir="$(bashunit::temp_dir)"
  local count_file="$dir/perl_calls"
  local real_perl
  real_perl="$(command -v perl)"
  if [ -z "$real_perl" ]; then
    bashunit::skip "no perl on this machine to shim" && return
  fi

  {
    echo '#!/usr/bin/env bash'
    echo "echo x >>\"$count_file\""
    echo "exec \"$real_perl\" \"\$@\""
  } >"$dir/perl"
  chmod +x "$dir/perl"

  local few="$dir/few_test.sh"
  local many="$dir/many_test.sh"
  local i=0
  : >"$few"
  while [ $i -lt 5 ]; do
    echo "function test_f$i() { assert_true true; }" >>"$few"
    i=$((i + 1))
  done
  i=0
  : >"$many"
  while [ $i -lt 40 ]; do
    echo "function test_m$i() { assert_true true; }" >>"$many"
    i=$((i + 1))
  done

  : >"$count_file"
  PATH="$dir:$PATH" ./bashunit --parallel "$few" >/dev/null 2>&1
  local few_calls
  few_calls="$(grep -c . "$count_file" || true)"

  : >"$count_file"
  PATH="$dir:$PATH" ./bashunit --parallel "$many" >/dev/null 2>&1
  local many_calls
  many_calls="$(grep -c . "$count_file" || true)"

  # Eight times the tests must not cost more probes. Equality, not a budget:
  # the run resolves the clock once whatever the size.
  assert_same "$few_calls" "$many_calls"
}
