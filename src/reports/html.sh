#!/usr/bin/env bash
# shellcheck disable=SC2155

# HTML report writer.

function bashunit::reports::generate_report_html() {
  local output_file="$1"

  local test_passed=$(bashunit::state::get_tests_passed)
  local tests_skipped=$(bashunit::state::get_tests_skipped)
  local tests_incomplete=$(bashunit::state::get_tests_incomplete)
  local tests_snapshot=$(bashunit::state::get_tests_snapshot)
  local tests_failed=$(bashunit::state::get_tests_failed)
  local time=$(bashunit::clock::total_runtime_in_milliseconds)

  # Temporary file to store test cases by file (use mktemp for parallel safety)
  local temp_file
  temp_file=$(mktemp "${TMPDIR:-/tmp}/bashunit-report.XXXXXX")

  # Fields are separated by US (0x1f), not `|`. A test name is user text --
  # bashunit::set_test_title takes anything and a data provider interpolates
  # values into it -- so a title containing the delimiter shifted every column
  # and turned `class="$status"` into a class that does not exist (#1249).
  local _us
  _us=$(printf '\037')

  # Collect test cases by file
  : >"$temp_file" # Clear temp file if it exists
  local i
  for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
    local file="${_BASHUNIT_REPORTS_TEST_FILES[$i]:-}"
    local name="${_BASHUNIT_REPORTS_TEST_NAMES[$i]:-}"
    local status="${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}"
    local test_time="${_BASHUNIT_REPORTS_TEST_DURATIONS[$i]:-}"
    local test_case="$file$_us$name$_us$status$_us$test_time"

    echo "$test_case" >>"$temp_file"
  done

  # Escape every field for HTML in one pass. The same user text was written
  # straight into the markup, so a title containing `<script>` ran in whoever
  # opened the report -- a CI artifact is read in a browser.
  #
  # awk, not ${var//&/&amp;}: a bare `&` in a bash replacement means "the
  # matched text" from 5.2 on while staying literal on 3.2, and there is no
  # spelling that is right across the supported range (#1096). In awk the same
  # rule applies to gsub, hence the escaped \\& below. The separator is passed
  # in as a byte rather than written as \x1f, which is not POSIX awk (#1098).
  local escaped_file
  escaped_file=$(mktemp "${TMPDIR:-/tmp}/bashunit-report-esc.XXXXXX")
  awk -v FS="$_us" -v OFS="$_us" '{
    for (i = 1; i <= NF; i++) {
      gsub(/&/, "\\&amp;", $i)
      gsub(/</, "\\&lt;", $i)
      gsub(/>/, "\\&gt;", $i)
      gsub(/"/, "\\&quot;", $i)
    }
    print
  }' "$temp_file" >"$escaped_file" && mv "$escaped_file" "$temp_file"

  {
    echo "<!DOCTYPE html>"
    echo "<html lang=\"en\">"
    echo "<head>"
    echo "  <meta charset=\"UTF-8\">"
    echo "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">"
    echo "  <title>Test Report</title>"
    echo "  <style>"
    echo "    body { font-family: Arial, sans-serif; }"
    echo "    table { width: 100%; border-collapse: collapse; }"
    echo "    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }"
    echo "    th { background-color: #f2f2f2; }"
    echo "    .passed { background-color: #dff0d8; }"
    echo "    .failed { background-color: #f2dede; }"
    echo "    .skipped { background-color: #fcf8e3; }"
    echo "    .incomplete { background-color: #d9edf7; }"
    echo "    .snapshot { background-color: #dfe6e9; }"
    echo "    .risky { background-color: #f5e6f5; }"
    echo "    .flaky { background-color: #ffe8cc; }"
    echo "  </style>"
    echo "</head>"
    echo "<body>"
    echo "  <h1>Test Report</h1>"
    echo "  <table>"
    echo "    <thead>"
    echo "      <tr>"
    echo "        <th>Total Tests</th>"
    echo "        <th>Passed</th>"
    echo "        <th>Failed</th>"
    echo "        <th>Incomplete</th>"
    echo "        <th>Skipped</th>"
    echo "        <th>Snapshot</th>"
    echo "        <th>Time (ms)</th>"
    echo "      </tr>"
    echo "    </thead>"
    echo "    <tbody>"
    echo "      <tr>"
    echo "        <td>${#_BASHUNIT_REPORTS_TEST_NAMES[@]}</td>"
    echo "        <td>$test_passed</td>"
    echo "        <td>$tests_failed</td>"
    echo "        <td>$tests_incomplete</td>"
    echo "        <td>$tests_skipped</td>"
    echo "        <td>$tests_snapshot</td>"
    echo "        <td>$time</td>"
    echo "      </tr>"
    echo "    </tbody>"
    echo "  </table>"
    echo "  <p>Time: $time ms</p>"

    # Read the temporary file and group by file
    local current_file=""
    local file name status test_time
    while IFS="$_us" read -r file name status test_time; do
      if [ "$file" != "$current_file" ]; then
        if [ -n "$current_file" ]; then
          echo "    </tbody>"
          echo "  </table>"
        fi
        echo "  <h2>File: $file</h2>"
        echo "  <table>"
        echo "    <thead>"
        echo "      <tr>"
        echo "        <th>Test Name</th>"
        echo "        <th>Status</th>"
        echo "        <th>Time (ms)</th>"
        echo "      </tr>"
        echo "    </thead>"
        echo "    <tbody>"
        current_file="$file"
      fi
      echo "      <tr class=\"$status\">"
      echo "        <td>$name</td>"
      echo "        <td>$status</td>"
      echo "        <td>$test_time</td>"
      echo "      </tr>"
    done <"$temp_file"

    # Close the last table
    if [ -n "$current_file" ]; then
      echo "    </tbody>"
      echo "  </table>"
    fi

    echo "</body>"
    echo "</html>"
  } >"$output_file"

  # Clean up temporary file
  rm -f "$temp_file"
}
