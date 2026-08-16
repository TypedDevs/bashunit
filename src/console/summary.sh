#!/usr/bin/env bash

# Run totals, execution time and hook completion.

##
# Explains an empty selection that `--tag` caused, by naming the tags the run
# actually saw.
#
# A tag is a user-defined string and nothing lists them, so a typo leaves the
# reader with no way to find the right one -- worse off than a bad `--filter`,
# where the test names are at least visible in a normal run (#1265).
##
function bashunit::console_results::print_tag_hint() {
  local tag_filter="${_BASHUNIT_ACTIVE_TAG_FILTER:-}"
  [ -n "$tag_filter" ] || return 0

  if [ -n "${_BASHUNIT_SEEN_TAGS:-}" ]; then
    printf "%sNo test matches tag '%s'. Tags in the selected files: %s.%s\n" \
      "${_BASHUNIT_COLOR_FAINT:-}" "$tag_filter" "$_BASHUNIT_SEEN_TAGS" \
      "${_BASHUNIT_COLOR_DEFAULT:-}"
    return 0
  fi

  printf "%sNo test matches tag '%s'. No test in the selected files carries a '# @tag'.%s\n" \
    "${_BASHUNIT_COLOR_FAINT:-}" "$tag_filter" "${_BASHUNIT_COLOR_DEFAULT:-}"
}

##
# Explains an empty selection that `--filter` caused.
#
# The report prints a humanized title -- `✓ Passed: Alpha` for `test_alpha` --
# while the flag matches the *function name*, case-sensitively. So the most
# natural guess, the name the user just read, selects nothing and the run ends
# on a bare "No tests found" with nowhere to go.
#
# Only the filter is lowercased, never the candidate list: test function names
# are lowercase by convention, so this catches the reported case without a fork
# per function on a path that has already decided to run nothing.
##
function bashunit::console_results::print_filter_hint() {
  local filter="${_BASHUNIT_ACTIVE_FILTER:-}"
  [ -n "$filter" ] || return 0

  local needle="${filter#test_}"
  local suggestion=""
  if [ -n "$needle" ]; then
    local lowered
    lowered="$(printf '%s' "$needle" | tr '[:upper:]' '[:lower:]')"
    # A humanized title is the function name with underscores shown as spaces,
    # so putting them back is what resolves the whole-title copy -- the case
    # the project's own agent rules warn about.
    local underscored="${lowered// /_}"
    local fn
    for fn in ${_BASHUNIT_CACHED_ALL_FUNCTIONS:-}; do
      case "$fn" in
      test_*"$lowered"* | test_*"$underscored"*)
        suggestion="$fn"
        break
        ;;
      esac
    done
  fi

  if [ -n "$suggestion" ]; then
    printf "%sNo test matches '%s'. Filters match the function name, not the title: did you mean '%s'?%s\n" \
      "${_BASHUNIT_COLOR_FAINT:-}" "$filter" "$suggestion" "${_BASHUNIT_COLOR_DEFAULT:-}"
    return 0
  fi

  printf "%sNo test matches '%s'. Filters match the function name (test_...), not the title in the report.%s\n" \
    "${_BASHUNIT_COLOR_FAINT:-}" "$filter" "${_BASHUNIT_COLOR_DEFAULT:-}"
}

function bashunit::console_results::render_result() {
  if [ "$(bashunit::state::is_duplicated_test_functions_found)" = true ]; then
    bashunit::console_results::print_execution_time
    printf "%s%s%s\n" "${_BASHUNIT_COLOR_RETURN_ERROR}" "Duplicate test functions found" "${_BASHUNIT_COLOR_DEFAULT}"
    printf "File with duplicate functions: %s\n" "$(bashunit::state::get_file_with_duplicated_function_names)"
    local _dup_detail
    _dup_detail="$(bashunit::state::get_duplicated_function_details)"
    if [ -z "$_dup_detail" ]; then
      _dup_detail="$(bashunit::state::get_duplicated_function_names)"
    fi
    printf "Duplicate functions: %s\n" "$_dup_detail"
    return 1
  fi

  if bashunit::env::is_tap_output_enabled; then
    printf "1..%d\n" "$_BASHUNIT_TOTAL_TESTS_COUNT"
    if [ "$_BASHUNIT_TESTS_FAILED" -gt 0 ]; then
      return 1
    fi
    return 0
  fi

  # json/junit: the totals live in the document the run prints at the end, so
  # this only resolves the exit code -- walking the same ladder as the console
  # renderer below, since the exit code may not depend on the output format.
  if bashunit::env::is_machine_output_enabled; then
    if [ "$_BASHUNIT_TESTS_FAILED" -gt 0 ]; then
      return 1
    fi
    if [ "$_BASHUNIT_TESTS_FLAKY" -gt 0 ] && bashunit::env::is_fail_on_flaky_enabled; then
      return 1
    fi
    local machine_total=$((_BASHUNIT_TESTS_PASSED + _BASHUNIT_TESTS_SKIPPED +
      _BASHUNIT_TESTS_INCOMPLETE + _BASHUNIT_TESTS_SNAPSHOT +
      _BASHUNIT_TESTS_FAILED + _BASHUNIT_TESTS_RISKY))
    if [ "$machine_total" -eq 0 ]; then
      return 1
    fi
    return 0
  fi

  if bashunit::env::is_simple_output_enabled; then
    printf "\n\n"
  fi

  # Cache state values to avoid repeated subshell invocations
  local tests_passed=$_BASHUNIT_TESTS_PASSED
  local tests_skipped=$_BASHUNIT_TESTS_SKIPPED
  local tests_incomplete=$_BASHUNIT_TESTS_INCOMPLETE
  local tests_snapshot=$_BASHUNIT_TESTS_SNAPSHOT
  local tests_failed=$_BASHUNIT_TESTS_FAILED
  local tests_risky=$_BASHUNIT_TESTS_RISKY
  local tests_flaky=$_BASHUNIT_TESTS_FLAKY
  local assertions_passed=$_BASHUNIT_ASSERTIONS_PASSED
  local assertions_skipped=$_BASHUNIT_ASSERTIONS_SKIPPED
  local assertions_incomplete=$_BASHUNIT_ASSERTIONS_INCOMPLETE
  local assertions_snapshot=$_BASHUNIT_ASSERTIONS_SNAPSHOT
  local assertions_failed=$_BASHUNIT_ASSERTIONS_FAILED

  local total_tests=0
  total_tests=$((total_tests + tests_passed))
  total_tests=$((total_tests + tests_skipped))
  total_tests=$((total_tests + tests_incomplete))
  total_tests=$((total_tests + tests_snapshot))
  total_tests=$((total_tests + tests_failed))
  total_tests=$((total_tests + tests_risky))

  local total_assertions=0
  total_assertions=$((total_assertions + assertions_passed))
  total_assertions=$((total_assertions + assertions_skipped))
  total_assertions=$((total_assertions + assertions_incomplete))
  total_assertions=$((total_assertions + assertions_snapshot))
  total_assertions=$((total_assertions + assertions_failed))

  printf "%sTests:     %s" "$_BASHUNIT_COLOR_FAINT" "$_BASHUNIT_COLOR_DEFAULT"
  if [ "$tests_passed" -gt 0 ] || [ "$assertions_passed" -gt 0 ]; then
    printf " %s%s passed%s," "$_BASHUNIT_COLOR_PASSED" "$tests_passed" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_skipped" -gt 0 ] || [ "$assertions_skipped" -gt 0 ]; then
    printf " %s%s skipped%s," "$_BASHUNIT_COLOR_SKIPPED" "$tests_skipped" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_incomplete" -gt 0 ] || [ "$assertions_incomplete" -gt 0 ]; then
    printf " %s%s incomplete%s," "$_BASHUNIT_COLOR_INCOMPLETE" "$tests_incomplete" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_snapshot" -gt 0 ] || [ "$assertions_snapshot" -gt 0 ]; then
    printf " %s%s snapshot%s," "$_BASHUNIT_COLOR_SNAPSHOT" "$tests_snapshot" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_failed" -gt 0 ] || [ "$assertions_failed" -gt 0 ]; then
    printf " %s%s failed%s," "$_BASHUNIT_COLOR_FAILED" "$tests_failed" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_risky" -gt 0 ]; then
    printf " %s%s risky%s," "$_BASHUNIT_COLOR_RISKY" "$tests_risky" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  # Deliberately absent from total_tests: these tests are already inside the
  # passed count, so adding them would make the total exceed the tests run.
  if [ "$tests_flaky" -gt 0 ]; then
    printf " %s%s flaky%s," "$_BASHUNIT_COLOR_INCOMPLETE" "$tests_flaky" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  printf " %s total\n" "$total_tests"

  printf "%sAssertions:%s" "$_BASHUNIT_COLOR_FAINT" "$_BASHUNIT_COLOR_DEFAULT"
  if [ "$tests_passed" -gt 0 ] || [ "$assertions_passed" -gt 0 ]; then
    printf " %s%s passed%s," "$_BASHUNIT_COLOR_PASSED" "$assertions_passed" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_skipped" -gt 0 ] || [ "$assertions_skipped" -gt 0 ]; then
    printf " %s%s skipped%s," "$_BASHUNIT_COLOR_SKIPPED" "$assertions_skipped" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_incomplete" -gt 0 ] || [ "$assertions_incomplete" -gt 0 ]; then
    printf " %s%s incomplete%s," "$_BASHUNIT_COLOR_INCOMPLETE" "$assertions_incomplete" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_snapshot" -gt 0 ] || [ "$assertions_snapshot" -gt 0 ]; then
    printf " %s%s snapshot%s," "$_BASHUNIT_COLOR_SNAPSHOT" "$assertions_snapshot" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_failed" -gt 0 ] || [ "$assertions_failed" -gt 0 ]; then
    printf " %s%s failed%s," "$_BASHUNIT_COLOR_FAILED" "$assertions_failed" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  printf " %s total\n" "$total_assertions"

  if [ "$tests_failed" -gt 0 ]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_ERROR" " Some tests failed " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 1
  fi

  # Ranked above risky so a run that is both reports the outcome that turns it
  # red. Without the flag flaky is a pass, so the ladder falls straight through.
  if [ "$tests_flaky" -gt 0 ] && bashunit::env::is_fail_on_flaky_enabled; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_ERROR" " Some tests flaky " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 1
  fi

  if [ "$tests_risky" -gt 0 ]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_RISKY" " Some tests risky (no assertions) " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 0
  fi

  if [ "$tests_incomplete" -gt 0 ]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_INCOMPLETE" " Some tests incomplete " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 0
  fi

  if [ "$tests_skipped" -gt 0 ]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_SKIPPED" " Some tests skipped " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 0
  fi

  if [ "$tests_snapshot" -gt 0 ]; then
    local snapshot_notice=" Some snapshots created "
    if bashunit::env::is_snapshot_update_enabled; then
      snapshot_notice=" Some snapshots updated "
    fi
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_SNAPSHOT" "$snapshot_notice" "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 0
  fi

  if [ "$total_tests" -eq 0 ]; then
    # --pass-with-no-tests changes the verdict, not the report: the run still
    # says it found nothing, because a shard that is empty by design and one
    # that is empty by accident look identical and the reader needs to see it.
    local empty_colour="$_BASHUNIT_COLOR_RETURN_ERROR"
    if bashunit::env::is_pass_with_no_tests_enabled; then
      empty_colour="$_BASHUNIT_COLOR_RETURN_SKIPPED"
    fi
    printf "\n%s%s%s\n" "$empty_colour" " No tests found " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_filter_hint
    bashunit::console_results::print_tag_hint
    bashunit::console_results::print_execution_time
    if bashunit::env::is_pass_with_no_tests_enabled; then
      return 0
    fi
    return 1
  fi

  printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_SUCCESS" " All tests passed " "$_BASHUNIT_COLOR_DEFAULT"
  bashunit::console_results::print_execution_time
  return 0
}


function bashunit::console_results::print_execution_time() {
  if ! bashunit::env::is_total_execution_time_enabled; then
    return
  fi

  local time
  time=$(bashunit::clock::total_runtime_in_milliseconds)
  # Strip decimal portion (integer truncation, Bash 3.0 compatible)
  time="${time%%.*}"

  # No measurement is not a measurement of zero. Defaulting to 0 here rendered
  # "Time taken: 0ms", which reads as a real instant run: #1271 had a broken
  # pipe in the calculation report 0ms for a 3.4s suite while the run still
  # exited 0, and the footer was the only thing that could have said otherwise.
  # The clock can also be genuinely unavailable, and that deserves the same
  # answer rather than a fabricated number.
  local formatted="unknown"
  case "$time" in
  '' | *[!0-9-]*) ;;
  *)
    # Reuse the shared ms formatter (Xm Ys / X.XXs / Xms) instead of re-deriving
    # it; this runs once per run, so the command-substitution fork is negligible.
    formatted=$(bashunit::console_results::format_duration "$time")
    ;;
  esac

  printf "${_BASHUNIT_COLOR_BOLD}%s${_BASHUNIT_COLOR_DEFAULT}\n" \
    "Time taken: ${formatted}"
}

_BASHUNIT_CONSOLE_DURATION_OUT=""


function bashunit::console_results::print_hook_completed() {
  local hook_name="$1"
  local duration_ms="$2"

  if bashunit::env::is_simple_output_enabled; then
    return
  fi

  if bashunit::env::is_failures_only_enabled; then
    return
  fi

  if bashunit::env::is_no_progress_enabled; then
    return
  fi

  if bashunit::env::is_machine_output_enabled; then
    return
  fi

  if bashunit::parallel::is_enabled; then
    return
  fi

  local line
  line=$(printf "%s● %s%s" \
    "$_BASHUNIT_COLOR_PASSED" "$hook_name" "$_BASHUNIT_COLOR_DEFAULT")

  local time_display
  time_display=$(bashunit::console_results::format_duration "$duration_ms")

  printf "%s\n" "$(bashunit::str::rpad "$line" "$time_display")"
}

