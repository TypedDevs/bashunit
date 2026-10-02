#!/usr/bin/env bash

# Machine-readable JSON report writer.

_BASHUNIT_REPORTS_JSON_ESCAPE_OUT=""
function bashunit::reports::__json_escape_to_slot() {
  local text="$1"
  case "$text" in
  *[[:cntrl:]]*) text=$(bashunit::reports::__strip_ansi "$text" | tr -d '\000-\010\013\014\016-\037') ;;
  esac
  # Backslash first so escapes added below are not doubled.
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  text="${text//$'\t'/\\t}"
  text="${text//$'\r'/\\r}"
  text="${text//$'\n'/\\n}"
  _BASHUNIT_REPORTS_JSON_ESCAPE_OUT="$text"
}

function bashunit::reports::__json_escape() {
  bashunit::reports::__json_escape_to_slot "$1"
  printf '%s' "$_BASHUNIT_REPORTS_JSON_ESCAPE_OUT"
}

##
# Writes the JSON report to the given file.
# Arguments: $1 - output file
##
function bashunit::reports::generate_report_json() {
  bashunit::reports::print_report_json >"$1"
}

##
# Renders the JSON report on stdout, for `--output json`.
##
function bashunit::reports::print_report_json() {
  local total="${#_BASHUNIT_REPORTS_TEST_NAMES[@]}"

  local passed=0 failed=0 skipped=0 incomplete=0 flaky=0 duration_total=0
  local i
  for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
    duration_total=$((duration_total + ${_BASHUNIT_REPORTS_TEST_DURATIONS[$i]:-0}))
    case "${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}" in
    failed) failed=$((failed + 1)) ;;
    skipped) skipped=$((skipped + 1)) ;;
    incomplete) incomplete=$((incomplete + 1)) ;;
    # Flaky is counted twice on purpose: it passed, so it belongs in passed, and
    # the separate tally is what makes it triageable.
    flaky)
      flaky=$((flaky + 1))
      passed=$((passed + 1))
      ;;
    # snapshot and risky ran without failing, so they count as passed here; the
    # per-test "status" field below preserves the exact category.
    *) passed=$((passed + 1)) ;;
    esac
  done

  {
    printf '{\n'
    printf '  "summary": { "total": %d, "passed": %d, "failed": %d,' \
      "$total" "$passed" "$failed"
    printf ' "skipped": %d, "incomplete": %d, "flaky": %d, "duration_ms": %d },\n' \
      "$skipped" "$incomplete" "$flaky" "$duration_total"
    printf '  "tests": [\n'
    local seq=0
    for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
      local file name status duration message sep
      bashunit::reports::__json_escape_to_slot "${_BASHUNIT_REPORTS_TEST_FILES[$i]:-}"
      file="$_BASHUNIT_REPORTS_JSON_ESCAPE_OUT"
      bashunit::reports::__json_escape_to_slot "${_BASHUNIT_REPORTS_TEST_NAMES[$i]:-}"
      name="$_BASHUNIT_REPORTS_JSON_ESCAPE_OUT"
      status="${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}"
      duration="${_BASHUNIT_REPORTS_TEST_DURATIONS[$i]:-0}"
      bashunit::reports::__json_escape_to_slot "${_BASHUNIT_REPORTS_TEST_FAILURES[$i]:-}"
      message="$_BASHUNIT_REPORTS_JSON_ESCAPE_OUT"
      sep=","
      [ "$seq" -eq "$((total - 1))" ] && sep=""
      printf '    { "file": "%s", "name": "%s", "status": "%s", "duration_ms": %d,' \
        "$file" "$name" "$status" "$duration"
      printf ' "retries": %d, "message": "%s" }%s\n' \
        "${_BASHUNIT_REPORTS_TEST_RETRIES[$i]:-0}" "$message" "$sep"
      seq=$((seq + 1))
    done
    printf '  ]\n'
    printf '}\n'
  }
}
