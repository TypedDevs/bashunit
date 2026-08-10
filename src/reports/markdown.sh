#!/usr/bin/env bash

# Markdown summary report writer. Aimed at humans on the pull-request page:
# GitHub renders anything appended to $GITHUB_STEP_SUMMARY, so the same
# document serves --report-md <file> and the automatic step-summary append.

# Escapes a string for Markdown prose and table cells: ANSI stripped first,
# then backslash before the others so the escapes added below are not doubled.
# Pipes must be escaped or a test name would end its table cell early.
function bashunit::reports::__md_escape() {
  local text
  text=$(bashunit::reports::__strip_ansi "$1")
  text="${text//\\/\\\\}"
  text="${text//\`/\\\`}"
  text="${text//\*/\\*}"
  text="${text//_/\\_}"
  text="${text//|/\\|}"
  printf '%s' "$text"
}

##
# Prints the whole Markdown summary to stdout. The file and step-summary
# entry points below only differ in redirection, so the document itself is
# rendered in exactly one place.
##
function bashunit::reports::print_report_md() {
  local passed failed skipped incomplete risky snapshot flaky
  passed=$(bashunit::state::get_tests_passed)
  failed=$(bashunit::state::get_tests_failed)
  skipped=$(bashunit::state::get_tests_skipped)
  incomplete=$(bashunit::state::get_tests_incomplete)
  risky=$(bashunit::state::get_tests_risky)
  snapshot=$(bashunit::state::get_tests_snapshot)
  flaky=$(bashunit::state::get_tests_flaky)

  local time_ms time_s
  time_ms=$(bashunit::clock::total_runtime_in_milliseconds)
  # `env` rather than a bare `LC_ALL=C` prefix: C keeps awk's radix a dot, and
  # that prefix form segfaults inside `$()` on Bash 5.3 macOS (#912).
  time_s=$(env LC_ALL=C awk -v ms="$time_ms" 'BEGIN {printf "%.3f", ms/1000}')

  if [ "$failed" -gt 0 ]; then
    printf '### ❌ %s failed, %s passed in %ss\n\n' "$failed" "$passed" "$time_s"
  else
    printf '### ✅ %s passed in %ss\n\n' "$passed" "$time_s"
  fi

  printf '| Passed | Failed | Skipped | Incomplete | Risky | Snapshot | Flaky |\n'
  printf '|---:|---:|---:|---:|---:|---:|---:|\n'
  printf '| %s | %s | %s | %s | %s | %s | %s |\n\n' \
    "$passed" "$failed" "$skipped" "$incomplete" "$risky" "$snapshot" "$flaky"

  if [ "$failed" -gt 0 ]; then
    bashunit::reports::__print_md_failures
  fi

  if bashunit::env::is_coverage_enabled; then
    printf '**Coverage:** %s%%\n\n' "$(bashunit::coverage::get_percentage)"
  fi

  if bashunit::env::is_profile_enabled; then
    bashunit::reports::__print_md_slowest
  fi
}

# The failures section: name, file:line and the message in a fenced block --
# the part that saves a click into the raw job log.
function bashunit::reports::__print_md_failures() {
  printf '#### Failures\n\n'

  local i
  for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
    [ "${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}" = "failed" ] || continue

    local name location message
    name=$(bashunit::reports::__md_escape "${_BASHUNIT_REPORTS_TEST_NAMES[$i]:-}")
    location="${_BASHUNIT_REPORTS_TEST_FILES[$i]:-}"
    if [ -n "${_BASHUNIT_REPORTS_TEST_LINES[$i]:-}" ]; then
      location="$location:${_BASHUNIT_REPORTS_TEST_LINES[$i]}"
    fi
    message=$(bashunit::reports::__strip_ansi "${_BASHUNIT_REPORTS_TEST_FAILURES[$i]:-}")

    printf -- '- **%s** — %s\n\n' "$name" "$location"
    printf '```\n%s\n```\n\n' "$message"
  done
}

# The slowest tests recorded in the report rows, duration descending, limited
# to BASHUNIT_PROFILE_COUNT. Reads the same rows every writer reads instead of
# PROFILE_OUTPUT_PATH, which print_profile_and_reset has already consumed.
function bashunit::reports::__print_md_slowest() {
  [ "${#_BASHUNIT_REPORTS_TEST_NAMES[@]}" -gt 0 ] || return 0

  printf '#### Slowest tests\n\n'
  printf '| Duration (ms) | Test | File |\n'
  printf '|---:|---|---|\n'

  local i
  local duration name file
  for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
    printf '%s\t%s\t%s\n' \
      "${_BASHUNIT_REPORTS_TEST_DURATIONS[$i]:-0}" \
      "${_BASHUNIT_REPORTS_TEST_NAMES[$i]:-}" \
      "${_BASHUNIT_REPORTS_TEST_FILES[$i]:-}"
  done \
    | sort -rn \
    | head -n "${BASHUNIT_PROFILE_COUNT:-10}" \
    | while IFS="$(printf '\t')" read -r duration name file; do
      printf '| %s | %s | %s |\n' \
        "$duration" "$(bashunit::reports::__md_escape "$name")" "$file"
    done

  printf '\n'
}

function bashunit::reports::generate_report_md() {
  local output_file="$1"

  bashunit::reports::print_report_md >"$output_file"
}

# $GITHUB_STEP_SUMMARY aggregates every step of a job, so the summary is
# appended -- truncating would erase what earlier steps wrote.
function bashunit::reports::append_github_step_summary() {
  local output_file="$1"

  bashunit::reports::print_report_md >>"$output_file"
}
