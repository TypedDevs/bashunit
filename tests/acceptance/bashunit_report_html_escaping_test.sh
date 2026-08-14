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
