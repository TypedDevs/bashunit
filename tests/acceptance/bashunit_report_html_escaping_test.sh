#!/usr/bin/env bash
set -euo pipefail

# The HTML report wrote test names straight into the markup, and a test title
# is user text -- `bashunit::set_test_title` takes anything, and a data
# provider interpolates values into it. So a title containing `<` corrupted the
# table, and one containing `<script>` was executed by whoever opened the
# report, which for a CI artifact is a browser (#1249).
#
# Rows were also joined with `|` into a temp file and split back on it, so a
# title containing a pipe shifted every column: the name truncated, the status
# cell showed a fragment of the title, and `class="$status"` became a CSS class
# that does not exist, losing the row's colour.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
}

function set_up() {
  WORKDIR="$(bashunit::temp_dir)"
}

function _report_with_title() { # $1 = title
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function test_titled() {'
    printf '  bashunit::set_test_title "%s"\n' "$1"
    printf '%s\n' '  assert_same 1 1'
    printf '%s\n' '}'
  } >"$WORKDIR/t_test.sh"

  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --report-html rep.html t_test.sh >/dev/null 2>&1) || true
  cat "$WORKDIR/rep.html"
}

function test_a_title_with_markup_is_escaped() {
  local html
  html="$(_report_with_title '<script>alert(1)</script>')"

  assert_not_contains "<script>alert(1)</script>" "$html"
  assert_contains "&lt;script&gt;" "$html"
}

function test_a_title_with_an_ampersand_is_escaped() {
  local html
  html="$(_report_with_title 'a & b')"

  assert_contains "a &amp; b" "$html"
}

# The row is stored and split on a delimiter, so a title carrying it must not
# shift the columns: the status cell has to hold a status, not a fragment.
function test_a_title_with_a_pipe_keeps_the_columns_aligned() {
  local html
  html="$(_report_with_title 'before|after')"

  assert_contains 'class="passed"' "$html"
  assert_not_contains 'class="after"' "$html"
  assert_contains "<td>passed</td>" "$html"
}

# And it still has to render as the title the user asked for. A pipe needs no
# entity once it is not the delimiter -- it is ordinary text in HTML.
function test_a_title_with_a_pipe_still_reads_as_written() {
  local html
  html="$(_report_with_title 'before|after')"

  assert_contains "<td>before|after</td>" "$html"
}

# An ordinary title must come through untouched, or the escaping is too eager.
function test_a_plain_title_is_unchanged() {
  local html
  html="$(_report_with_title 'plain title')"

  assert_contains "<td>plain title</td>" "$html"
  assert_contains 'class="passed"' "$html"
}

# The HTML report listed test names and statuses but never said why anything
# failed, while JUnit, JSON, TAP and Markdown all carry the message. It is the
# format people open in a browser to find out what broke, so it was the one
# that most needed it (#1251).
function _report_for_failing_test() {
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function test_bad() { assert_same "want" "got"; }'
    printf '%s\n' 'function test_good() { assert_same 1 1; }'
  } >"$WORKDIR/f_test.sh"

  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --report-html rep.html f_test.sh >/dev/null 2>&1) || true
  cat "$WORKDIR/rep.html"
}

function test_the_report_explains_why_a_test_failed() {
  local html
  html="$(_report_for_failing_test)"

  assert_contains "Failures" "$html"
  assert_contains "Expected" "$html"
  assert_contains "want" "$html"
  assert_contains "got" "$html"
}

function test_the_failure_names_its_file_and_line() {
  local html
  html="$(_report_for_failing_test)"

  assert_contains "f_test.sh:2" "$html"
}

# A green run must not grow an empty section.
function test_a_passing_run_has_no_failures_section() {
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function test_good() { assert_same 1 1; }'
  } >"$WORKDIR/g_test.sh"

  local html
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --report-html ok.html g_test.sh >/dev/null 2>&1) || true
  html="$(cat "$WORKDIR/ok.html")"

  assert_not_contains "Failures" "$html"
}

# The message is user text too, so it goes through the same escaping.
function test_a_failure_message_with_markup_is_escaped() {
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function test_markup() { assert_same "<b>want</b>" "<i>got</i>"; }'
  } >"$WORKDIR/m_test.sh"

  local html
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --report-html m.html m_test.sh >/dev/null 2>&1) || true
  html="$(cat "$WORKDIR/m.html")"

  assert_not_contains "<b>want</b>" "$html"
  assert_contains "&lt;b&gt;want&lt;/b&gt;" "$html"
}

# The summary counted Passed/Failed/Incomplete/Skipped/Snapshot but not Risky,
# so a run with a risky test showed a Total the visible categories could not
# add up to -- 2 total against 1 passed and four zeros. The row was there, with
# the `.risky` class the stylesheet defines, but nothing counted it. The console
# and the Markdown report both report it (#1252).
function test_the_summary_counts_a_risky_test() {
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function test_pass() { assert_same 1 1; }'
    printf '%s\n' 'function test_risky() { echo noise; }'
  } >"$WORKDIR/r_test.sh"

  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --report-html r.html r_test.sh >/dev/null 2>&1) || true
  local html
  html="$(cat "$WORKDIR/r.html")"

  assert_contains "<th>Risky</th>" "$html"
}

# Flaky already reconciles -- it sits inside the pass total -- but the console
# and Markdown both surface the number, so the HTML summary should too.
function test_the_summary_reports_flaky() {
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function test_pass() { assert_same 1 1; }'
  } >"$WORKDIR/p_test.sh"

  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --report-html p.html p_test.sh >/dev/null 2>&1) || true
  local html
  html="$(cat "$WORKDIR/p.html")"

  assert_contains "<th>Flaky</th>" "$html"
}

# The invariant behind #1252: every test lands in exactly one category, so the
# categories sum to the total. Asserting the columns exist is weaker -- a column
# that is present but always renders zero passes that and fails this.
#
# Flaky is deliberately excluded from the sum: a flaky test stays inside the
# pass total, so adding it would double-count and this test would fail on a
# retry-recovered run.
function test_the_summary_categories_sum_to_the_total() {
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function test_pass() { assert_same 1 1; }'
    printf '%s\n' 'function test_fail() { assert_same 1 2; }'
    printf '%s\n' 'function test_skip() { bashunit::skip "why" && return; }'
    printf '%s\n' 'function test_todo() { bashunit::todo "later"; }'
    printf '%s\n' 'function test_risky() { echo noise; }'
  } >"$WORKDIR/a_test.sh"

  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --report-html a.html a_test.sh >/dev/null 2>&1) || true

  # The summary row is the first <td> run in the document: total, passed,
  # failed, incomplete, skipped, snapshot, risky, flaky, time.
  local -a cells=()
  local cell
  while IFS= read -r cell; do
    cells[${#cells[@]}]="$cell"
  done < <("$GREP" -oE '<td>[0-9]+</td>' "$WORKDIR/a.html" | "$GREP" -oE '[0-9]+' | head -9)

  local total="${cells[0]:-0}"
  local sum=$((${cells[1]:-0} + ${cells[2]:-0} + ${cells[3]:-0} + ${cells[4]:-0} + ${cells[5]:-0} + ${cells[6]:-0}))

  assert_same "$total" "$sum"
}
