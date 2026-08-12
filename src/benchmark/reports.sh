#!/usr/bin/env bash

# JSON and JUnit writers for a bench run.
#
# The console table is the only thing a benchmark run used to leave behind, so
# nothing could be stored as a CI artifact, charted over time, or compared by a
# later run. These two writers exist for that, and for the regression gate
# built on top of them.
#
# They do not reuse src/reports/: those writers are shaped around a test's
# pass/fail/skip verdict and its assertion counts, while a benchmark row is
# timings. What is shared is the JUnit and JSON escaping.

_BASHUNIT_BENCH_STATS_MIN_OUT=""
_BASHUNIT_BENCH_STATS_MAX_OUT=""
_BASHUNIT_BENCH_STATS_MEDIAN_OUT=""

##
# Min, max and median of a space-separated list of decimal milliseconds, into
# the slots above.
#
# One awk pass under LC_ALL=C: the decimal separator is a comma in several of
# the locales CI runs, and a report that says "1,5" is not JSON (#912).
# Arguments: $1 - space-separated durations
##
function bashunit::benchmark::stats_to_slots() {
  local durations=$1
  _BASHUNIT_BENCH_STATS_MIN_OUT=""
  _BASHUNIT_BENCH_STATS_MAX_OUT=""
  _BASHUNIT_BENCH_STATS_MEDIAN_OUT=""

  [ -n "$durations" ] || return 0

  local stats
  stats=$(printf '%s\n' "$durations" | env LC_ALL=C awk '
    {
      n = 0
      for (i = 1; i <= NF; i++) { values[++n] = $i + 0 }
      if (n == 0) { exit }
      for (i = 2; i <= n; i++) {
        v = values[i]
        j = i - 1
        while (j >= 1 && values[j] > v) { values[j + 1] = values[j]; j-- }
        values[j + 1] = v
      }
      if (n % 2) {
        median = values[(n + 1) / 2]
      } else {
        median = (values[n / 2] + values[n / 2 + 1]) / 2
      }
      printf "%.3f %.3f %.3f\n", values[1], values[n], median
    }
  ')

  local min max median
  read -r min max median <<EOF
$stats
EOF
  _BASHUNIT_BENCH_STATS_MIN_OUT=$min
  _BASHUNIT_BENCH_STATS_MAX_OUT=$max
  _BASHUNIT_BENCH_STATS_MEDIAN_OUT=$median
}

##
# Whether the benchmark at index $1 stayed within its @max_ms. Prints "true",
# "false", or nothing when the annotation is absent.
##
function bashunit::benchmark::_verdict() {
  local index=$1
  local threshold="${_BASHUNIT_BENCH_MAX_MILLIS[$index]:-}"
  [ -n "$threshold" ] || return 0

  if bashunit::math::is_le "${_BASHUNIT_BENCH_AVERAGES[$index]:-0}" "$threshold"; then
    printf 'true'
  else
    printf 'false'
  fi
}

##
# The durations of one benchmark as a JSON array body.
##
function bashunit::benchmark::_iterations_json() {
  local durations=$1
  local out=""
  local value
  local IFS=' '
  for value in $durations; do
    if [ -z "$out" ]; then
      out="$value"
    else
      out="$out, $value"
    fi
  done
  printf '%s' "$out"
}

function bashunit::benchmark::report_json() {
  local output_file=$1

  local timestamp
  timestamp=$(date '+%Y-%m-%dT%H:%M:%S')
  local os
  os=$(uname -s 2>/dev/null || printf 'unknown')

  {
    printf '{\n'
    printf '  "run": {\n'
    printf '    "timestamp": "%s",\n' "$timestamp"
    printf '    "duration_ms": %s,\n' "$(bashunit::benchmark::_run_duration_ms)"
    printf '    "bashunit_version": "%s",\n' "$(bashunit::reports::__json_escape "${BASHUNIT_VERSION:-unknown}")"
    printf '    "bash_version": "%s",\n' "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}"
    printf '    "os": "%s"\n' "$(bashunit::reports::__json_escape "$os")"
    printf '  },\n'
    printf '  "benchmarks": [\n'

    local total=${#_BASHUNIT_BENCH_NAMES[@]}
    local i sep name label file durations threshold verdict
    for i in $(bashunit::benchmark::_indexes); do
      name="${_BASHUNIT_BENCH_NAMES[$i]:-}"
      bashunit::helper::normalize_test_function_name_to_slot "$name"
      label=$_BASHUNIT_HELPER_NORMALIZED_OUT
      file="${_BASHUNIT_BENCH_FILES[$i]:-}"
      durations="${_BASHUNIT_BENCH_DURATIONS[$i]:-}"
      bashunit::benchmark::stats_to_slots "$durations"
      threshold="${_BASHUNIT_BENCH_MAX_MILLIS[$i]:-}"
      verdict=$(bashunit::benchmark::_verdict "$i")
      sep=","
      [ "$i" -eq "$((total - 1))" ] && sep=""

      printf '    {\n'
      printf '      "file": "%s",\n' "$(bashunit::reports::__json_escape "$file")"
      printf '      "function": "%s",\n' "$(bashunit::reports::__json_escape "$name")"
      printf '      "name": "%s",\n' "$(bashunit::reports::__json_escape "$label")"
      printf '      "revs": %s,\n' "${_BASHUNIT_BENCH_REVS[$i]:-0}"
      printf '      "its": %s,\n' "${_BASHUNIT_BENCH_ITS[$i]:-0}"
      printf '      "iterations_ms": [%s],\n' "$(bashunit::benchmark::_iterations_json "$durations")"
      printf '      "average_ms": %s,\n' "${_BASHUNIT_BENCH_AVERAGES[$i]:-0}"
      printf '      "min_ms": %s,\n' "${_BASHUNIT_BENCH_STATS_MIN_OUT:-0}"
      printf '      "max_ms": %s,\n' "${_BASHUNIT_BENCH_STATS_MAX_OUT:-0}"
      printf '      "median_ms": %s,\n' "${_BASHUNIT_BENCH_STATS_MEDIAN_OUT:-0}"
      # null rather than 0: no annotation is not a threshold of zero, and a
      # consumer charting thresholds must be able to tell the two apart.
      printf '      "threshold_ms": %s,\n' "${threshold:-null}"
      printf '      "within_threshold": %s\n' "${verdict:-null}"
      printf '    }%s\n' "$sep"
    done

    printf '  ]\n'
    printf '}\n'
  } >"$output_file"
}

function bashunit::benchmark::report_junit() {
  local output_file=$1

  local timestamp
  timestamp=$(date '+%Y-%m-%dT%H:%M:%S')
  local total=${#_BASHUNIT_BENCH_NAMES[@]}
  local failures=0
  local i verdict
  for i in $(bashunit::benchmark::_indexes); do
    verdict=$(bashunit::benchmark::_verdict "$i")
    if [ "$verdict" = "false" ]; then
      failures=$((failures + 1))
    fi
  done

  local run_seconds
  bashunit::reports::__ms_to_s "$(bashunit::benchmark::_run_duration_ms)"
  run_seconds=$_BASHUNIT_REPORTS_MS_TO_S_OUT

  {
    printf '<?xml version="1.0" encoding="UTF-8"?>\n'
    printf '<testsuites name="bashunit-bench" tests="%s" failures="%s" errors="0" time="%s">\n' \
      "$total" "$failures" "$run_seconds"
    printf '  <testsuite name="benchmarks" tests="%s" failures="%s" errors="0" time="%s" timestamp="%s">\n' \
      "$total" "$failures" "$run_seconds" "$timestamp"

    local name label file classname seconds threshold
    for i in $(bashunit::benchmark::_indexes); do
      name="${_BASHUNIT_BENCH_NAMES[$i]:-}"
      bashunit::helper::normalize_test_function_name_to_slot "$name"
      label=$(bashunit::reports::__xml_escape "$_BASHUNIT_HELPER_NORMALIZED_OUT")
      file="${_BASHUNIT_BENCH_FILES[$i]:-}"
      bashunit::reports::__junit_classname "$file"
      classname=$_BASHUNIT_REPORTS_CLASSNAME_OUT
      bashunit::reports::__ms_to_s "${_BASHUNIT_BENCH_AVERAGES[$i]:-0}"
      seconds=$_BASHUNIT_REPORTS_MS_TO_S_OUT
      threshold="${_BASHUNIT_BENCH_MAX_MILLIS[$i]:-}"

      printf '    <testcase classname="%s" name="%s" file="%s" time="%s">\n' \
        "$classname" "$label" "$(bashunit::reports::__xml_escape "$file")" "$seconds"
      if [ "$(bashunit::benchmark::_verdict "$i")" = "false" ]; then
        printf '      <failure message="%s" type="PerformanceRegression">%s</failure>\n' \
          "average ${_BASHUNIT_BENCH_AVERAGES[$i]:-0}ms exceeds @max_ms ${threshold}" \
          "revs=${_BASHUNIT_BENCH_REVS[$i]:-0} its=${_BASHUNIT_BENCH_ITS[$i]:-0}"
      fi
      printf '    </testcase>\n'
    done

    printf '  </testsuite>\n'
    printf '</testsuites>\n'
  } >"$output_file"
}

##
# The indexes of the collected results, oldest first. Bash 3.0 has no
# `${!arr[@]}` guarantee on a possibly-empty array under `set -u`, so the range
# is built by counting.
##
function bashunit::benchmark::_indexes() {
  local total=${#_BASHUNIT_BENCH_NAMES[@]}
  local i=0
  while [ "$i" -lt "$total" ]; do
    printf '%s\n' "$i"
    i=$((i + 1))
  done
}

##
# The run's wall time in milliseconds, from the same clock the console footer
# reports, so the two agree. Falls back to 0 before the clock is initialised
# (a unit test calling a writer directly).
##
function bashunit::benchmark::_run_duration_ms() {
  if [ -z "${_BASHUNIT_START_TIME:-}" ]; then
    printf '0'
    return
  fi
  local elapsed
  elapsed=$(bashunit::clock::total_runtime_in_milliseconds)
  case "$elapsed" in
  '' | *[!0-9.]*) elapsed=0 ;;
  esac
  printf '%s' "$elapsed"
}
