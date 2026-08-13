#!/usr/bin/env bash
set -euo pipefail

# Regression guard for the HTML report.
#
# Every source line it prints has to be HTML-escaped, and that escaping used to
# be a command substitution plus a `sed` PER LINE: about 22,000 processes for
# this repo and 58.7s of report (#1096). It is one awk pass per file now.
#
# The budget is expressed as "does not grow with the number of source lines",
# the same property tests/acceptance/bashunit_coverage_forks_test.sh pins for
# the classifier, because that is what was fixed and it needs no retuning when
# an unrelated `sed` appears elsewhere.

# Writes a fixture pair into $1: a test file plus a source file of $2 body units,
# each unit holding characters the escaper has to rewrite.
function _html_fixture() {
  local dir="$1"
  local units="$2"

  {
    echo '#!/usr/bin/env bash'
    echo 'function covered_fn() {'
    echo '  local total=0'
    local i
    for i in $(seq 1 "$units"); do
      echo "  # a & b <tag> $i"
      echo "  total=\$((total + $i))"
      echo "  printf '%s' \"<x> & <y>\""
    done
    echo '  echo "$total"'
    echo '}'
  } >"$dir/libhtml.sh"

  {
    echo "source \"$dir/libhtml.sh\""
    echo 'function test_covers_source() { assert_not_empty "$(covered_fn)"; }'
  } >"$dir/html_forks_test.sh"
}

# Runs an HTML coverage report with a `sed` PATH shim and echoes the fork count.
function _count_sed_forks_for_html() {
  local dir="$1"
  local real_sed="$2"
  local count_file="$dir/sed_count"

  {
    echo '#!/usr/bin/env bash'
    echo "echo x >> \"$count_file\""
    echo "exec \"$real_sed\" \"\$@\""
  } >"$dir/sed"
  chmod +x "$dir/sed"
  : >"$count_file"

  PATH="$dir:$PATH" \
    BASHUNIT_COVERAGE_PATHS="$dir" \
    ./bashunit --no-parallel --coverage \
    --coverage-report-html "$dir/html" "$dir/html_forks_test.sh" >/dev/null 2>&1 || true

  local forks=0
  if [ -f "$count_file" ]; then
    forks="$(grep -c . "$count_file" || true)"
  fi
  echo "$forks"
}

function test_the_html_report_does_not_fork_sed_per_source_line() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "PATH shims are unreliable under Git Bash" && return
  fi

  local real_sed
  real_sed="$(command -v sed)"

  # Canonicalise: bashunit::temp_dir can yield a doubled slash and
  # BASHUNIT_COVERAGE_PATHS is prefix-matched against canonicalised paths, so a
  # mismatch would track nothing and the census would measure an empty run.
  local small_dir large_dir
  small_dir="$(cd "$(bashunit::temp_dir)" && pwd)"
  large_dir="$(cd "$(bashunit::temp_dir)" && pwd)"

  # 3 lines per unit: the large fixture has ~120 more lines to escape, which
  # used to cost one sed each.
  _html_fixture "$small_dir" 2
  _html_fixture "$large_dir" 42

  local small_forks large_forks
  small_forks="$(_count_sed_forks_for_html "$small_dir" "$real_sed")"
  large_forks="$(_count_sed_forks_for_html "$large_dir" "$real_sed")"

  assert_less_than 10 "$((large_forks - small_forks))"
}

function test_the_html_report_renders_the_escaped_source() {
  local dir
  dir="$(cd "$(bashunit::temp_dir)" && pwd)"
  _html_fixture "$dir" 1

  BASHUNIT_COVERAGE_PATHS="$dir" ./bashunit --no-parallel --coverage \
    --coverage-report-html "$dir/html" "$dir/html_forks_test.sh" >/dev/null 2>&1 || true

  # Pages are named after the whole mangled path, not the basename.
  local page
  page="$(find "$dir/html" -name '*libhtml_sh.html' | head -1)"
  assert_not_empty "$page"

  # The markup in the source must arrive escaped, not as markup.
  local body
  body="$(cat "$page")"
  assert_contains "&lt;tag&gt;" "$body"
  assert_contains "&amp;" "$body"
  assert_not_contains '<x> & <y>' "$body"
}
