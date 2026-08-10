#!/usr/bin/env bash

# Markdown run summary, for the one surface aimed at a human rather than a
# machine: the pull request page. GitHub Actions renders anything appended to
# $GITHUB_STEP_SUMMARY as Markdown on the job page; GitLab and Azure have
# equivalents that consume the same file.

##
# Escapes the Markdown metacharacters that would otherwise change the rendering
# of a value taken from a test name. The backslash goes first, or it would
# escape the escapes added after it.
##
function bashunit::reports::__md_escape() {
  local text="$1"
  text=$(bashunit::reports::__strip_ansi "$text")
  text="${text//\\/\\\\}"
  text="${text//|/\\|}"
  text="${text//\`/\\\`}"
  text="${text//\*/\\*}"
  text="${text//_/\\_}"
  printf '%s' "$text"
}

##
# Emits one `| Label | N |` row, but only when the count is non-zero. Passed and
# failed are always printed by the caller: a run with neither is the interesting
# case, not a row worth hiding.
##
function bashunit::reports::__md_count_row() {
  local label=$1
  local count=$2
  if [ "${count:-0}" -gt 0 ]; then
    printf '| %s | %s |\n' "$label" "$count"
  fi
}

##
# Writes the whole summary to stdout. Callers redirect: `>` for an explicit
# --report-md path, `>>` for the step summary, which belongs to the whole job.
##
function bashunit::reports::print_report_md() {
  local passed failed skipped incomplete snapshot risky flaky duration_ms
  passed=$(bashunit::state::get_tests_passed)
  failed=$(bashunit::state::get_tests_failed)
  skipped=$(bashunit::state::get_tests_skipped)
  incomplete=$(bashunit::state::get_tests_incomplete)
  snapshot=$(bashunit::state::get_tests_snapshot)
  risky=$(bashunit::state::get_tests_risky)
  flaky=$(bashunit::state::get_tests_flaky)
  duration_ms=$(bashunit::clock::total_runtime_in_milliseconds)

  local duration
  duration=$(bashunit::console_results::format_duration "$duration_ms")

  echo "## bashunit"
  echo ""
  if [ "${failed:-0}" -gt 0 ]; then
    printf '❌ **%s failed**, %s passed in %s\n' "$failed" "$passed" "$duration"
  else
    printf '✅ **%s passed** in %s\n' "$passed" "$duration"
  fi
  echo ""

  echo "| Result | Count |"
  echo "|--------|-------|"
  printf '| Passed | %s |\n' "$passed"
  printf '| Failed | %s |\n' "$failed"
  bashunit::reports::__md_count_row "Skipped" "$skipped"
  bashunit::reports::__md_count_row "Incomplete" "$incomplete"
  bashunit::reports::__md_count_row "Snapshot" "$snapshot"
  bashunit::reports::__md_count_row "Risky" "$risky"
  bashunit::reports::__md_count_row "Flaky" "$flaky"
  echo ""

  bashunit::reports::__md_failures
  bashunit::reports::__md_coverage
  bashunit::reports::__md_profile
}

##
# The section that saves a click into the raw log: name, location and the
# failure message verbatim inside a fence.
##
function bashunit::reports::__md_failures() {
  local i any=false
  for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
    case "${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}" in
    failed) ;;
    *) continue ;;
    esac

    if [ "$any" = false ]; then
      echo "## Failures"
      echo ""
      any=true
    fi

    local name file line message
    name=$(bashunit::reports::__md_escape "${_BASHUNIT_REPORTS_TEST_NAMES[$i]:-}")
    file="${_BASHUNIT_REPORTS_TEST_FILES[$i]:-}"
    line="${_BASHUNIT_REPORTS_TEST_LINES[$i]:-}"
    message=$(bashunit::reports::__strip_ansi "${_BASHUNIT_REPORTS_TEST_FAILURES[$i]:-}")

    printf '### %s\n\n' "$name"
    if [ -n "$line" ]; then
      printf '`%s:%s`\n\n' "$file" "$line"
    else
      printf '`%s`\n\n' "$file"
    fi
    # Not escaped: a fence renders its contents literally, which is the point.
    echo '```'
    printf '%s\n' "$message"
    echo '```'
    echo ""
  done
}

function bashunit::reports::__md_coverage() {
  if [ "${_BASHUNIT_COVERAGE_ON:-0}" != 1 ]; then
    return 0
  fi

  local pct
  pct=$(bashunit::coverage::get_percentage 2>/dev/null) || return 0
  [ -n "$pct" ] || return 0

  echo "## Coverage"
  echo ""
  printf '%s%% of tracked lines\n' "$pct"
  echo ""
}

##
# Reads the same tab-separated records the console profile renders. Must run
# before print_profile_and_reset, which removes the file.
##
function bashunit::reports::__md_profile() {
  if ! bashunit::env::is_profile_enabled; then
    return 0
  fi
  [ -s "${PROFILE_OUTPUT_PATH:-}" ] || return 0

  echo "## Slowest tests"
  echo ""
  echo "| Duration | Test | File |"
  echo "|----------|------|------|"

  local duration name file formatted
  while IFS=$'\t' read -r duration name file; do
    formatted=$(bashunit::console_results::format_duration "$duration")
    printf '| %s | %s | %s |\n' \
      "$formatted" \
      "$(bashunit::reports::__md_escape "$name")" \
      "$(bashunit::reports::__md_escape "$file")"
  done < <(sort -t"$(printf '\t')" -k1 -rn "$PROFILE_OUTPUT_PATH" | head -n "${BASHUNIT_PROFILE_COUNT:-10}")
  echo ""
}

function bashunit::reports::generate_report_md() {
  local output_file="$1"

  bashunit::reports::print_report_md >"$output_file"
}

##
# Appends to $GITHUB_STEP_SUMMARY. Appending, never writing: the file is shared
# with every other step in the job, so truncating it would discard their output.
##
function bashunit::reports::append_step_summary() {
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] || return 0

  bashunit::reports::print_report_md >>"$GITHUB_STEP_SUMMARY"
}
