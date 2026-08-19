#!/usr/bin/env bash

function bashunit::runner::load_test_files() {
  local filter=$1
  local tag_filter="${2:-}"
  local exclude_tag_filter="${3:-}"
  # Carried to the summary so an empty selection can explain itself: the filter
  # is a local here, and the report renders long after this returns.
  _BASHUNIT_ACTIVE_FILTER="$filter"
  _BASHUNIT_ACTIVE_TAG_FILTER="$tag_filter"
  shift 3
  local IFS=$' \t\n'
  local -a files
  files=("$@")
  local -a scripts_ids=()
  local scripts_ids_count=0
  local -a worker_stderr_paths=()
  local -a worker_stderr_owners=()
  local worker_stderr_count=0

  # --order-by defects: files holding last run's failures go first. The cache is
  # only read here, never used to drop a file, so the full suite still runs.
  if bashunit::env::is_defects_order_enabled; then
    bashunit::rerun::load
    local -a _defect_files=()
    local _defect_file
    while IFS= read -r _defect_file; do
      [ -n "$_defect_file" ] && _defect_files[${#_defect_files[@]}]=$_defect_file
    done < <(bashunit::rerun::order_files "${files[@]+"${files[@]}"}")
    files=("${_defect_files[@]+"${_defect_files[@]}"}")
  fi

  # Randomize file execution order (deterministic for the resolved seed).
  if bashunit::env::is_random_order_enabled; then
    local -a _shuffled_files=()
    local _sf
    while IFS= read -r _sf; do
      [ -n "$_sf" ] && _shuffled_files[${#_shuffled_files[@]}]=$_sf
    done < <(printf '%s\n' "${files[@]+"${files[@]}"}" | bashunit::math::shuffle "$(bashunit::env::seed)")
    files=("${_shuffled_files[@]+"${_shuffled_files[@]}"}")
  fi

  bashunit::runner::sync_coverage_flag

  # Initialize coverage tracking if enabled
  if [ "$_BASHUNIT_COVERAGE_ON" = 1 ]; then
    # Auto-discover coverage paths if not explicitly set
    if [ -z "$BASHUNIT_COVERAGE_PATHS" ]; then
      BASHUNIT_COVERAGE_PATHS=$(bashunit::coverage::auto_discover_paths "${files[@]}")
      # Fallback: if auto-discovery yields no paths, track the src/ folder
      if [ -z "$BASHUNIT_COVERAGE_PATHS" ]; then
        BASHUNIT_COVERAGE_PATHS="src/"
      fi
    fi
    bashunit::coverage::init
  fi

  local test_file
  for test_file in "${files[@]+"${files[@]}"}"; do
    if [ ! -f "$test_file" ]; then
      continue
    fi
    unset BASHUNIT_CURRENT_TEST_ID
    bashunit::helper::generate_id "${test_file}"
    export BASHUNIT_CURRENT_SCRIPT_ID="$_BASHUNIT_HELPER_ID_OUT"
    scripts_ids[scripts_ids_count]="${BASHUNIT_CURRENT_SCRIPT_ID}"
    scripts_ids_count=$((scripts_ids_count + 1))
    bashunit::internal_log "Loading file" "$test_file"
    # Files are sourced sequentially in this loop (parallel workers fork after),
    # so a fixed path in the run dir is safe: `2>` truncates it per file and the
    # run-dir cleanup removes it, saving a mktemp and an rm fork per file.
    local source_err_file source_err source_status
    source_err_file="$_BASHUNIT_RUN_OUTPUT_DIR/source_err"
    # A missing scratch dir makes the redirect below fail, and bash reports that
    # as the *command* failing: exit 1 with nothing written to the capture file,
    # which read as "this test file failed to source" against a file that was
    # complete and valid (#1137). Restore the directory, and fall back to
    # /dev/null if even that is refused -- losing a file's stderr capture is
    # worth far less than failing the file for a reason that is not its own.
    #
    # Say so when it happens, once per run: #1137 is open precisely because a
    # scratch directory goes missing on CI and nobody can say what removed it.
    # Surviving it silently would keep it that way.
    if [ ! -d "$_BASHUNIT_RUN_OUTPUT_DIR" ]; then
      if [ "${_BASHUNIT_RUN_DIR_VANISHED:-false}" = false ]; then
        _BASHUNIT_RUN_DIR_VANISHED=true
        printf 'bashunit: the run scratch directory disappeared mid-run: %s\n' \
          "$_BASHUNIT_RUN_OUTPUT_DIR" >&2
        printf 'bashunit: recreating it; please report this with the run log (#1137).\n' >&2
      fi
      if ! mkdir -p "$_BASHUNIT_RUN_OUTPUT_DIR" 2>/dev/null; then
        source_err_file=/dev/null
      fi
    fi
    # shellcheck source=/dev/null
    source "$test_file" 2>"$source_err_file"
    source_status=$?
    # A test file may enable `set -euo pipefail` at its top level; sourcing
    # runs that in THIS shell, so a later non-zero status in the loop (e.g. a
    # failing set_up_before_script) would kill the whole run mid-suite with no
    # summary. Strictness is applied per-test in execute_test_body — reset the
    # runner loop to its set +euo invariant (see main.sh exec_tests) (#836).
    set +euo pipefail
    source_err=""
    if [ -s "$source_err_file" ]; then
      source_err="$(cat "$source_err_file")"
    fi
    # A non-zero source status, or a syntax-error line on stderr, means the file
    # failed to load. Match the captured stderr with `case` (no grep fork).
    local source_failed=false
    if [ "$source_status" -ne 0 ]; then
      source_failed=true
    else
      case "$source_err" in
      *"syntax error"* | *"unexpected EOF"*) source_failed=true ;;
      esac
    fi
    if [ "$source_failed" = true ]; then
      local message="$source_err"
      if [ -z "$message" ]; then
        # Non-zero with nothing on stderr is the puzzling case: the file exists
        # and parsed, so the size distinguishes a truncated or empty file from
        # one whose last command simply returned non-zero. #1137 is exactly
        # this, seen only on loaded CI, and the message as it stood carried no
        # way to tell those apart.
        local source_bytes="unknown"
        if [ -f "$test_file" ]; then
          source_bytes=$(bashunit::io::file_size "$test_file")
        fi
        message="Failed to source '$test_file' (exit $source_status, $source_bytes bytes, no stderr)"
      fi
      bashunit::runner::record_file_hook_failure \
        "source" "$test_file" "$message" 1 true
      bashunit::runner::clean_set_up_and_tear_down_after_script
      bashunit::runner::restore_workdir
      continue
    fi
    # Update function cache after sourcing new test file (compgen is a builtin)
    _BASHUNIT_CACHED_ALL_FUNCTIONS=$(compgen -A function)
    # Check if any tests match the filter before rendering header or running hooks
    local filtered_functions
    filtered_functions=$(bashunit::helper::get_functions_to_run "test" "$filter" "$_BASHUNIT_CACHED_ALL_FUNCTIONS")
    local functions_for_script
    functions_for_script=$(bashunit::runner::functions_for_script "$test_file" "$filtered_functions")
    # Full pre-tag/rerun list: these are unset once the file has been
    # processed, whatever subset actually runs (#829).
    local _script_fns_to_clean="$functions_for_script"
    # Apply tag filtering to the early check as well
    if [ -n "$tag_filter" ] || [ -n "$exclude_tag_filter" ]; then
      bashunit::helper::build_tags_map "$test_file"
      local _early_filtered=""
      local _early_fn
      for _early_fn in $functions_for_script; do
        bashunit::helper::tags_for_function "$_early_fn"
        if bashunit::helper::function_matches_tags "$_BASHUNIT_TAGS_OUT" "$tag_filter" "$exclude_tag_filter"; then
          _early_filtered="$_early_filtered $_early_fn"
        fi
      done
      functions_for_script="${_early_filtered# }"
    fi
    # Replay filtering: keep only the functions recorded as failing last run.
    if bashunit::rerun::is_enabled && bashunit::rerun::has_entries; then
      functions_for_script=$(bashunit::rerun::filter_functions "$test_file" "$functions_for_script")
    fi
    if [ -z "$functions_for_script" ]; then
      bashunit::runner::clean_script_test_functions "$_script_fns_to_clean"
      bashunit::runner::clean_set_up_and_tear_down_after_script
      bashunit::runner::restore_workdir
      continue
    fi
    # --list stops here: every selection step has been applied, and nothing
    # below this point can run without producing side effects (#1007).
    if bashunit::env::is_list_enabled; then
      bashunit::runner::list_functions "$test_file" "$functions_for_script"
      bashunit::runner::clean_script_test_functions "$_script_fns_to_clean"
      bashunit::runner::clean_set_up_and_tear_down_after_script
      bashunit::runner::restore_workdir
      continue
    fi
    # Render header BEFORE set_up_before_script so user sees activity immediately
    bashunit::runner::render_running_file_header "$test_file"
    # Call hook directly (not with `if !`) to preserve errexit behavior inside the hook
    bashunit::runner::run_set_up_before_script "$test_file"
    local setup_before_script_status=$?
    if [ $setup_before_script_status -ne 0 ]; then
      # Count the test functions that couldn't run due to set_up_before_script
      # failure and add them as failed (minus 1 since the hook failure already
      # counts as 1). Use this file's own function list — scanning the cached
      # ALL-functions set would also count fns left over from earlier files
      # and inflate the totals (#836).
      if [ -n "$functions_for_script" ]; then
        # Bash 3.0 compatible: separate declaration and assignment for arrays
        local functions_to_run
        # shellcheck disable=SC2206
        functions_to_run=($functions_for_script)
        local additional_failures=$((${#functions_to_run[@]} - 1))
        local i
        for ((i = 0; i < additional_failures; i++)); do
          bashunit::state::add_tests_failed
        done
      fi
      # Setup may have acquired resources before it failed. Pair every setup
      # invocation with teardown, as the per-test lifecycle already does.
      bashunit::runner::run_tear_down_after_script "$test_file"
      # Same cleanup as the success path: without it the file's test functions
      # leak into the next iteration's counts and the main shell (#829, #836).
      bashunit::runner::clean_script_test_functions "$_script_fns_to_clean"
      bashunit::runner::clean_set_up_and_tear_down_after_script
      if ! bashunit::parallel::is_enabled; then
        bashunit::cleanup_script_temp_files
      fi
      bashunit::runner::restore_workdir
      continue
    fi
    local _cached_fns="$functions_for_script"
    # In the parent, before dispatch: under --parallel call_test_functions is a
    # background subshell, so a check run inside it sets state that dies with
    # the subshell and the run reports "All tests passed" over a file where one
    # of two same-named tests never ran (#1147).
    bashunit::helper::check_duplicate_functions "$test_file" || true
    if bashunit::parallel::is_enabled; then
      bashunit::runner::wait_for_job_slot
      # Capture rather than discard: a worker's stderr cannot be written
      # straight to the terminal without shredding the progress line, but
      # dropping it made the same run report differently under --parallel
      # (#358 added the discard, #864 replaced it with this capture).
      local _worker_stderr="${WORKER_STDERR_OUTPUT_PREFIX}.${worker_stderr_count}"
      worker_stderr_paths[worker_stderr_count]="$_worker_stderr"
      worker_stderr_owners[worker_stderr_count]="$test_file"
      worker_stderr_count=$((worker_stderr_count + 1))
      # The file's teardown belongs inside the worker. Run from this shell it
      # released the fixture while the worker's tests were still reading it, so
      # the same file passed sequentially and failed under --parallel (#1320).
      # call_test_functions waits for its own per-test workers before it
      # returns, which is what makes this ordering hold.
      {
        bashunit::runner::call_test_functions "$test_file" "$_cached_fns"
        bashunit::runner::run_tear_down_after_script "$test_file"
        # A hook failure recorded in here dies with the subshell (#1147), so
        # publish it the way a test publishes its result.
        bashunit::runner::publish_file_hook_failure "$?" "$test_file"
      } 2>"$_worker_stderr" &
    else
      bashunit::runner::call_test_functions "$test_file" "$_cached_fns"
      bashunit::runner::run_tear_down_after_script "$test_file"
    fi
    bashunit::runner::clean_script_test_functions "$_script_fns_to_clean"
    bashunit::runner::clean_set_up_and_tear_down_after_script
    if ! bashunit::parallel::is_enabled; then
      bashunit::cleanup_script_temp_files
    fi
    bashunit::internal_log "Finished file" "$test_file"
    bashunit::runner::restore_workdir
  done

  # A listing dispatched no worker, so there is nothing to wait for and no
  # result file to aggregate -- and aggregating an empty per-script dir prints
  # "No tests found" into what must be a clean list of ids (#1007).
  if bashunit::parallel::is_enabled && ! bashunit::env::is_list_enabled; then
    wait
    bashunit::runner::spinner &
    local spinner_pid=$!
    bashunit::state::aggregate_parallel_results "$TEMP_DIR_PARALLEL_TEST_SUITE"
    # Kill the spinner once the aggregation finishes
    disown "$spinner_pid" 2>/dev/null || true
    kill "$spinner_pid" 2>/dev/null || true
    # Clear the spinner output, but only where it was drawn. The spinner draws
    # nothing when stdout is not a terminal, under --no-progress, or under a
    # machine --output format; erasing regardless emitted a literal "\r  \r"
    # into every piped run, which is every CI log -- and under a machine format
    # those bytes landed in front of the report, where an XML declaration must
    # start the document. The conditions have to match the ones the spinner
    # itself checks, or the two drift apart again.
    if [ -t 1 ] &&
      ! bashunit::env::is_no_progress_enabled &&
      ! bashunit::env::is_machine_output_enabled; then
      printf "\r  \r"
    fi

    local _stderr_idx=0
    while [ "$_stderr_idx" -lt "$worker_stderr_count" ]; do
      if [ -s "${worker_stderr_paths[_stderr_idx]:-}" ]; then
        bashunit::console_results::print_worker_stderr \
          "${worker_stderr_owners[_stderr_idx]:-}" "${worker_stderr_paths[_stderr_idx]:-}"
      fi
      _stderr_idx=$((_stderr_idx + 1))
    done

    local script_id
    for script_id in "${scripts_ids[@]+"${scripts_ids[@]}"}"; do
      export BASHUNIT_CURRENT_SCRIPT_ID="${script_id}"
      bashunit::cleanup_script_temp_files
    done
  fi
}

function bashunit::runner::functions_for_script() {
  local script="$1"
  local all_fn_names="$2"

  # Resolve "<name> <line> <file>" for the given names, enabling extdebug only
  # inside the capture subshell so the caller's setting is untouched.
  local declarations
  # shellcheck disable=SC2086
  declarations=$(
    shopt -s extdebug
    declare -F $all_fn_names 2>/dev/null
  )

  # Keep the functions defined in this script, insertion-sorted by definition
  # line. Pure bash: the old `awk | sort | awk` pipeline cost three forks and
  # ran twice per file, while a file's function list is small (tens of names).
  local -a fns=()
  local -a fn_lines=()
  local count=0
  local name line file i
  while read -r name line file; do
    [ "$file" = "$script" ] || continue
    i=$count
    while [ "$i" -gt 0 ] && [ "${fn_lines[i - 1]}" -gt "$line" ]; do
      fns[i]=${fns[i - 1]}
      fn_lines[i]=${fn_lines[i - 1]}
      i=$((i - 1))
    done
    fns[i]=$name
    fn_lines[i]=$line
    count=$((count + 1))
  done <<EOF
$declarations
EOF

  i=0
  while [ "$i" -lt "$count" ]; do
    echo "${fns[i]}"
    i=$((i + 1))
  done
}
