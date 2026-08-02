#!/usr/bin/env bash

# Machine-readable JSON report writer.

# Escapes a string for embedding in a JSON string literal (pure Bash, no jq).
# Strips ANSI/control chars that cannot appear inline, keeps \t\r\n as escapes.
function bashunit::reports::__json_escape() {
  local text="$1"
  text=$(bashunit::reports::__strip_ansi "$text" | tr -d '\000-\010\013\014\016-\037')
  # Backslash first so escapes added below are not doubled.
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  text="${text//$'\t'/\\t}"
  text="${text//$'\r'/\\r}"
  text="${text//$'\n'/\\n}"
  printf '%s' "$text"
}

function bashunit::reports::generate_report_json() {
  local output_file="$1"
  local total="${#_BASHUNIT_REPORTS_TEST_NAMES[@]}"

  local passed=0 failed=0 skipped=0 incomplete=0 duration_total=0
  local i
  for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
    duration_total=$((duration_total + ${_BASHUNIT_REPORTS_TEST_DURATIONS[$i]:-0}))
    case "${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}" in
    failed) failed=$((failed + 1)) ;;
    skipped) skipped=$((skipped + 1)) ;;
    incomplete) incomplete=$((incomplete + 1)) ;;
    # snapshot and risky ran without failing, so they count as passed here; the
    # per-test "status" field below preserves the exact category.
    *) passed=$((passed + 1)) ;;
    esac
  done

  {
    printf '{\n'
    printf '  "summary": { "total": %d, "passed": %d, "failed": %d,' \
      "$total" "$passed" "$failed"
    printf ' "skipped": %d, "incomplete": %d, "duration_ms": %d },\n' \
      "$skipped" "$incomplete" "$duration_total"
    printf '  "tests": [\n'
    local seq=0
    for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
      local file name status duration message sep
      file=$(bashunit::reports::__json_escape "${_BASHUNIT_REPORTS_TEST_FILES[$i]:-}")
      name=$(bashunit::reports::__json_escape "${_BASHUNIT_REPORTS_TEST_NAMES[$i]:-}")
      status="${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}"
      duration="${_BASHUNIT_REPORTS_TEST_DURATIONS[$i]:-0}"
      message=$(bashunit::reports::__json_escape "${_BASHUNIT_REPORTS_TEST_FAILURES[$i]:-}")
      sep=","
      [ "$seq" -eq "$((total - 1))" ] && sep=""
      printf '    { "file": "%s", "name": "%s", "status": "%s", "duration_ms": %d, "message": "%s" }%s\n' \
        "$file" "$name" "$status" "$duration" "$message" "$sep"
      seq=$((seq + 1))
    done
    printf '  ]\n'
    printf '}\n'
  } >"$output_file"
}
