#!/usr/bin/env bash
# shellcheck disable=SC2155

# JUnit XML report writer.

function bashunit::reports::__xml_escape() {
  local text="$1"
  # Strip ANSI escape sequences and control characters invalid in XML 1.0,
  # then escape XML special characters (& first to avoid double-escaping)
  bashunit::reports::__strip_ansi "$text" \
    | tr -d '\000-\010\013\014\016-\037' \
    | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&apos;/g"
}

function bashunit::reports::generate_junit_xml() {
  local output_file="$1"

  local tests_skipped=$(bashunit::state::get_tests_skipped)
  local tests_incomplete=$(bashunit::state::get_tests_incomplete)
  local tests_failed=$(bashunit::state::get_tests_failed)
  local time_ms=$(bashunit::clock::total_runtime_in_milliseconds)
  local time
  # `env` rather than a bare `LC_ALL=C` prefix: C keeps awk's radix a dot for the
  # XML, and that prefix form segfaults inside `$()` on Bash 5.3 macOS (#912).
  time=$(env LC_ALL=C awk -v ms="$time_ms" 'BEGIN {printf "%.3f", ms/1000}')

  {
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    echo "<testsuites>"
    echo "  <testsuite name=\"bashunit\" tests=\"${#_BASHUNIT_REPORTS_TEST_NAMES[@]}\""
    echo "             failures=\"$tests_failed\" errors=\"0\""
    echo "             skipped=\"$(( tests_skipped + tests_incomplete ))\""
    echo "             time=\"$time\">"

    local i
    for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
      local file="${_BASHUNIT_REPORTS_TEST_FILES[$i]:-}"
      local name="${_BASHUNIT_REPORTS_TEST_NAMES[$i]:-}"
      local status="${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}"
      local test_time_ms="${_BASHUNIT_REPORTS_TEST_DURATIONS[$i]:-}"
      local failure_message="${_BASHUNIT_REPORTS_TEST_FAILURES[$i]:-}"
      local test_time
      test_time=$(env LC_ALL=C awk -v ms="$test_time_ms" 'BEGIN {printf "%.3f", ms/1000}')

      echo "    <testcase file=\"$file\""
      echo "        name=\"$name\""
      echo "        time=\"$test_time\">"

      # Add failure element for failed tests with actual failure message
      if [ "$status" = "failed" ]; then
        local escaped_message
        escaped_message=$(bashunit::reports::__xml_escape "$failure_message")
        echo "      <failure message=\"Test failed\">$escaped_message</failure>"
      elif [ "$status" = "flaky" ]; then
        # Jenkins and GitLab render flakyFailure natively, and it does not count
        # towards failures="" -- which is the point: the test passed.
        local escaped_flaky
        escaped_flaky=$(bashunit::reports::__xml_escape "$failure_message")
        echo "      <flakyFailure message=\"Test passed after ${_BASHUNIT_REPORTS_TEST_RETRIES[$i]:-0} \
retries\">$escaped_flaky</flakyFailure>"
      elif [ "$status" = "risky" ]; then
        echo "      <skipped message=\"Test has no assertions (risky)\"/>"
      elif [ "$status" = "skipped" ]; then
        echo "      <skipped/>"
      elif [ "$status" = "incomplete" ]; then
        echo "      <skipped message=\"Test incomplete\"/>"
      fi

      echo "    </testcase>"
    done

    echo "  </testsuite>"
    echo "</testsuites>"
  } >"$output_file"
}
