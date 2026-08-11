#!/usr/bin/env bash

# JUnit XML report writer. One <testsuite> per test file, because that is the
# unit Jenkins, GitLab, Azure and dorny/test-reporter group results by; a flat
# suite collapsed every run into one undifferentiated bucket.

function bashunit::reports::__xml_escape() {
  local text="$1"
  # Strip ANSI escape sequences and control characters invalid in XML 1.0,
  # then escape XML special characters (& first to avoid double-escaping)
  bashunit::reports::__strip_ansi "$text" \
    | tr -d '\000-\010\013\014\016-\037' \
    | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&apos;/g"
}

# Milliseconds to "S.mmm" seconds, written into the slot below. Pure bash on
# purpose: the previous `env LC_ALL=C awk` call (needed so the radix stays a
# dot, #912) forked once per testcase; printf with a literal dot is
# locale-immune and free.
_BASHUNIT_REPORTS_MS_TO_S_OUT=""
function bashunit::reports::__ms_to_s() {
  local ms="${1:-0}"
  case "$ms" in
    '' | *[!0-9]*) ms=0 ;;
  esac
  _BASHUNIT_REPORTS_MS_TO_S_OUT="$((ms / 1000)).$(printf '%03d' "$((ms % 1000))")"
}

# Test file path to the dotted classname consumers group by:
# tests/unit/assert/core_test.sh -> tests.unit.assert.core_test
_BASHUNIT_REPORTS_CLASSNAME_OUT=""
function bashunit::reports::__junit_classname() {
  local path="$1"
  path="${path#./}"
  path="${path%.sh}"
  _BASHUNIT_REPORTS_CLASSNAME_OUT="${path//\//.}"
}

##
# Writes the JUnit XML report to the given file.
# Arguments: $1 - output file
##
function bashunit::reports::generate_junit_xml() {
  bashunit::reports::print_junit_xml >"$1"
}

##
# Renders the JUnit XML report on stdout, for `--output junit`.
##
function bashunit::reports::print_junit_xml() {
  local timestamp
  timestamp=$(date '+%Y-%m-%dT%H:%M:%S')

  # Group rows by file in first-appearance order. Parallel indexed arrays
  # instead of declare -A (Bash 3.0): suite lookup is a linear scan over the
  # file count, which stays small next to the test count.
  local suite_files suite_tests suite_failures suite_skipped suite_time cases
  suite_files=()
  suite_tests=()
  suite_failures=()
  suite_skipped=()
  suite_time=()
  cases=()

  local total_tests="${#_BASHUNIT_REPORTS_TEST_NAMES[@]}"
  local total_failures=0
  local total_skipped=0
  local total_time_ms=0

  local i j s
  for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
    local file="${_BASHUNIT_REPORTS_TEST_FILES[$i]:-}"
    local name="${_BASHUNIT_REPORTS_TEST_NAMES[$i]:-}"
    local status="${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}"
    local duration_ms="${_BASHUNIT_REPORTS_TEST_DURATIONS[$i]:-0}"
    local failure_message="${_BASHUNIT_REPORTS_TEST_FAILURES[$i]:-}"
    local test_output="${_BASHUNIT_REPORTS_TEST_OUTPUTS[$i]:-}"
    case "$duration_ms" in '' | *[!0-9]*) duration_ms=0 ;; esac

    s=-1
    for j in ${suite_files[@]+"${!suite_files[@]}"}; do
      if [ "${suite_files[$j]}" = "$file" ]; then
        s=$j
        break
      fi
    done
    if [ "$s" -eq -1 ]; then
      s=${#suite_files[@]}
      suite_files[s]="$file"
      suite_tests[s]=0
      suite_failures[s]=0
      suite_skipped[s]=0
      suite_time[s]=0
      cases[s]=""
    fi

    suite_tests[s]=$((suite_tests[s] + 1))
    suite_time[s]=$((suite_time[s] + duration_ms))
    total_time_ms=$((total_time_ms + duration_ms))

    local test_time escaped_name classname
    bashunit::reports::__ms_to_s "$duration_ms"
    test_time=$_BASHUNIT_REPORTS_MS_TO_S_OUT
    escaped_name=$(bashunit::reports::__xml_escape "$name")
    bashunit::reports::__junit_classname "$file"
    classname=$_BASHUNIT_REPORTS_CLASSNAME_OUT

    local case_xml="    <testcase classname=\"$classname\" name=\"$escaped_name\"
        file=\"$file\" time=\"$test_time\">
"

    if [ "$status" = "failed" ]; then
      suite_failures[s]=$((suite_failures[s] + 1))
      total_failures=$((total_failures + 1))
      local escaped_message plain_message msg_head
      escaped_message=$(bashunit::reports::__xml_escape "$failure_message")
      # The first informative line as @message: many consumers show only the
      # attribute, and a constant "Test failed" there hid the real reason
      # (#1016). The "✗ Failed: <name>" banner repeats the name attribute, so
      # when a further line exists that one speaks for the failure instead.
      plain_message=$(bashunit::reports::__strip_ansi "$failure_message")
      msg_head="${plain_message%%$'\n'*}"
      case "$msg_head" in
        '✗ Failed:'* | '✗ Error:'*)
          local msg_rest="${plain_message#*$'\n'}"
          if [ "$msg_rest" != "$plain_message" ]; then
            msg_head="${msg_rest%%$'\n'*}"
            msg_head="${msg_head#"${msg_head%%[![:space:]]*}"}"
          fi
          ;;
      esac
      local first_line
      first_line=$(bashunit::reports::__xml_escape "$msg_head")
      case_xml="$case_xml      <failure message=\"$first_line\" type=\"AssertionFailed\">$escaped_message</failure>
"
    elif [ "$status" = "flaky" ]; then
      # Jenkins and GitLab render flakyFailure natively, and it does not count
      # towards failures="" -- which is the point: the test passed.
      local escaped_flaky
      escaped_flaky=$(bashunit::reports::__xml_escape "$failure_message")
      case_xml="$case_xml      <flakyFailure message=\"Test passed after ${_BASHUNIT_REPORTS_TEST_RETRIES[$i]:-0} \
retries\">$escaped_flaky</flakyFailure>
"
    elif [ "$status" = "risky" ]; then
      suite_skipped[s]=$((suite_skipped[s] + 1))
      total_skipped=$((total_skipped + 1))
      case_xml="$case_xml      <skipped message=\"Test has no assertions (risky)\"/>
"
    elif [ "$status" = "skipped" ]; then
      suite_skipped[s]=$((suite_skipped[s] + 1))
      total_skipped=$((total_skipped + 1))
      case_xml="$case_xml      <skipped/>
"
    elif [ "$status" = "incomplete" ]; then
      suite_skipped[s]=$((suite_skipped[s] + 1))
      total_skipped=$((total_skipped + 1))
      case_xml="$case_xml      <skipped message=\"Test incomplete\"/>
"
    fi

    if [ -n "$test_output" ]; then
      local escaped_output
      escaped_output=$(bashunit::reports::__xml_escape "$test_output")
      case_xml="$case_xml      <system-out>$escaped_output</system-out>
"
    fi

    cases[s]="${cases[s]}$case_xml    </testcase>
"
  done

  local total_time
  bashunit::reports::__ms_to_s "$total_time_ms"
  total_time=$_BASHUNIT_REPORTS_MS_TO_S_OUT

  {
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    echo "<testsuites name=\"bashunit\" tests=\"$total_tests\" failures=\"$total_failures\"" \
      "skipped=\"$total_skipped\" errors=\"0\" time=\"$total_time\">"

    for s in ${suite_files[@]+"${!suite_files[@]}"}; do
      local suite_time_s
      bashunit::reports::__ms_to_s "${suite_time[$s]}"
      suite_time_s=$_BASHUNIT_REPORTS_MS_TO_S_OUT
      echo "  <testsuite name=\"${suite_files[$s]}\" tests=\"${suite_tests[$s]}\"" \
        "failures=\"${suite_failures[$s]}\" skipped=\"${suite_skipped[$s]}\" errors=\"0\"" \
        "time=\"$suite_time_s\" timestamp=\"$timestamp\">"
      printf '%s' "${cases[$s]}"
      echo "  </testsuite>"
    done

    echo "</testsuites>"
  }
}
