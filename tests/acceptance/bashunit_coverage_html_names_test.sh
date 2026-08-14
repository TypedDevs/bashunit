#!/usr/bin/env bash
set -euo pipefail

# The coverage HTML pages carried both defects the test report had (#1249),
# independently: rows were joined and split on `|`, and filenames went into the
# markup unescaped.
#
# The pipe case is the one worth remembering -- the coverage *numbers* stayed
# correct while the index displayed a truncated name, so the output was wrong in
# a way that looks plausible (#1254).
#
# `html_file.sh`'s awk `escape()` covers the rendered source lines and rightly
# omits `"`, since that text is element content. It was only the filenames.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
}

function set_up() {
  WORKDIR="$(bashunit::temp_dir)"
}

# A project whose only source file is named $1, with coverage HTML generated.
function _coverage_html_for() { # $1 = source file name
  mkdir -p "$WORKDIR/src"
  printf '%s\n' '#!/usr/bin/env bash' 'function rw() { echo hi; }' >"$WORKDIR/src/$1"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf 'source "./src/%s"\n' "$1"
    printf '%s\n' 'function test_rw() { assert_same hi "$(rw)"; }'
  } >"$WORKDIR/t_test.sh"

  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --coverage --coverage-paths src/ \
    --coverage-report-html cov t_test.sh >/dev/null 2>&1) || true
  cat "$WORKDIR/cov/index.html" 2>/dev/null
}

function test_a_filename_with_a_pipe_is_not_truncated() {
  local html
  html="$(_coverage_html_for 'a|b.sh')"

  assert_contains 'class="file-name">a|b.sh<' "$html"
  assert_contains './src/a|b.sh' "$html"
}

function test_a_filename_with_markup_is_escaped() {
  local html
  html="$(_coverage_html_for 'a<b>c.sh')"

  assert_not_contains 'class="file-name">a<b>' "$html"
  assert_contains 'a&lt;b&gt;c.sh' "$html"
}

function test_a_filename_with_an_ampersand_is_escaped() {
  local html
  html="$(_coverage_html_for 'read&write.sh')"

  assert_contains 'read&amp;write.sh' "$html"
}

# A plain filename must come through untouched.
function test_a_plain_filename_is_unchanged() {
  local html
  html="$(_coverage_html_for 'plain.sh')"

  assert_contains 'class="file-name">plain.sh<' "$html"
}

# The per-file page renders the name too: <title> and two spans.
function test_the_per_file_page_escapes_the_filename() {
  _coverage_html_for 'a<b>c.sh' >/dev/null

  local page
  page="$(cat "$WORKDIR"/cov/files/*.html 2>/dev/null)"

  assert_not_contains '<title>a<b>' "$page"
  assert_contains 'a&lt;b&gt;c.sh' "$page"
}
