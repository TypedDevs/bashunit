#!/usr/bin/env bash

function bashunit::runner::load_bench_files() {
  local filter=$1
  shift
  local IFS=$' \t\n'
  local -a files
  files=("$@")

  local bench_file
  for bench_file in "${files[@]+"${files[@]}"}"; do
    [ -f "$bench_file" ] || continue
    unset BASHUNIT_CURRENT_TEST_ID
    bashunit::helper::generate_id "${bench_file}"
    export BASHUNIT_CURRENT_SCRIPT_ID="$_BASHUNIT_HELPER_ID_OUT"
    # Sourcing status is checked, the same way the test loop checks it: a bench
    # file with a syntax error used to lose every function after the error and
    # leave the run green, reporting only whatever parsed.
    local source_err_file source_err source_status
    source_err_file="$_BASHUNIT_RUN_OUTPUT_DIR/bench_source_err"
    : >"$source_err_file" 2>/dev/null || source_err_file=/dev/null
    # shellcheck source=/dev/null
    source "$bench_file" 2>"$source_err_file"
    source_status=$?
    # Reset the loop's shell-mode invariant; a bench file may set -euo at top
    # level and sourcing runs that in this shell (see the test loop) (#836).
    set +euo pipefail

    source_err=""
    if [ -s "$source_err_file" ]; then
      source_err="$(cat "$source_err_file")"
    fi
    # A non-zero status, or a syntax-error line on stderr: bash reports a syntax
    # error and carries on, so the status alone does not catch it. `case`, not
    # grep, to stay fork-free -- same test the test loop makes.
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
        message="Failed to source '$bench_file' (exit $source_status)"
      fi
      bashunit::runner::record_file_hook_failure "source" "$bench_file" "$message" 1 true
      bashunit::runner::clean_set_up_and_tear_down_after_script
      bashunit::cleanup_script_temp_files
      bashunit::runner::restore_workdir
      continue
    fi
    # Update function cache after sourcing new bench file (compgen is a builtin)
    _BASHUNIT_CACHED_ALL_FUNCTIONS=$(compgen -A function)
    # Call hook directly (not with `if !`) to preserve errexit behavior inside the hook
    bashunit::runner::run_set_up_before_script "$bench_file"
    local setup_before_script_status=$?
    if [ $setup_before_script_status -ne 0 ]; then
      # Count the bench functions that couldn't run due to set_up_before_script failure
      # and add them as failed (minus 1 since the hook failure already counts as 1)
      local filtered_functions
      filtered_functions=$(bashunit::helper::get_functions_to_run "bench" "$filter" "$_BASHUNIT_CACHED_ALL_FUNCTIONS")
      if [ -n "$filtered_functions" ]; then
        # Bash 3.0 compatible: separate declaration and assignment for arrays
        local functions_to_run
        # shellcheck disable=SC2206
        functions_to_run=($filtered_functions)
        local additional_failures=$((${#functions_to_run[@]} - 1))
        local i
        for ((i = 0; i < additional_failures; i++)); do
          bashunit::state::add_tests_failed
        done
      fi
      bashunit::runner::clean_set_up_and_tear_down_after_script
      bashunit::cleanup_script_temp_files
      bashunit::runner::restore_workdir
      continue
    fi
    bashunit::runner::call_bench_functions "$bench_file" "$filter"
    bashunit::runner::run_tear_down_after_script "$bench_file"
    bashunit::runner::clean_set_up_and_tear_down_after_script
    bashunit::cleanup_script_temp_files
    bashunit::runner::restore_workdir
  done
}

function bashunit::runner::call_bench_functions() {
  local script="$1"
  local filter="$2"
  local IFS=$' \t\n'
  local prefix="bench"

  # Use cached function names for better performance
  local filtered_functions
  filtered_functions=$(bashunit::helper::get_functions_to_run \
    "$prefix" "$filter" "$_BASHUNIT_CACHED_ALL_FUNCTIONS")
  local -a functions_to_run=()
  local functions_to_run_count=0
  local _fn
  while IFS= read -r _fn; do
    [ -z "$_fn" ] && continue
    functions_to_run[functions_to_run_count]="$_fn"
    functions_to_run_count=$((functions_to_run_count + 1))
  done < <(bashunit::runner::functions_for_script "$script" "$filtered_functions")

  if [ "$functions_to_run_count" -le 0 ]; then
    return
  fi

  if bashunit::env::is_bench_mode_enabled; then
    bashunit::runner::render_running_file_header "$script"
  fi

  local fn_name
  for fn_name in "${functions_to_run[@]+"${functions_to_run[@]}"}"; do
    # Capture separately so a malformed annotation aborts the run: the exit
    # status of a $(...) inside `read <<<` is otherwise discarded (#884).
    local parsed_annotations
    parsed_annotations=$(bashunit::benchmark::parse_annotations "$fn_name" "$script") || exit 1
    read -r revs its max_ms <<<"$parsed_annotations"
    bashunit::benchmark::run_function "$fn_name" "$revs" "$its" "$max_ms" "$script"
    unset -v fn_name
  done

  if ! bashunit::env::is_simple_output_enabled; then
    echo ""
  fi
}
