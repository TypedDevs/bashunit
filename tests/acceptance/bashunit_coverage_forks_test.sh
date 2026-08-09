#!/usr/bin/env bash
set -euo pipefail

# Regression guard for the coverage *report* phase.
#
# Profiling #1005 showed the report, not the capture engine, was half the cost
# of a `--coverage` run: `is_executable_line` fell back to a `grep -E` fork for
# every line it could not classify in pure Bash, and every tracked line is
# classified twice per run (once by precompute_file_stats, once by report_lcov).
# 286 source lines cost 1055 grep forks; the classification is pure Bash now.
#
# The budget is expressed as "does not grow with the number of source lines"
# rather than an absolute count: that is the property that was fixed, and it
# does not need retuning when an unrelated grep is added elsewhere.

# Writes a fixture pair into $1: a test file, plus a source file of $2 lines
# whose content exercises every branch of the classifier (comments, function
# declarations, case patterns, loop terminators, continuations).
function _coverage_fixture() {
  local dir="$1"
  local body_lines="$2"

  {
    echo '#!/usr/bin/env bash'
    echo 'function covered_fn() {'
    echo '  local total=0'
    local i
    for i in $(seq 1 "$body_lines"); do
      echo "  # comment $i"
      echo "  total=\$((total + $i))"
      echo "  case \"\$total\" in"
      echo "  ${i}) total=\$((total + 0)) ;;"
      echo "  *) : ;;"
      echo "  esac"
    done
    echo '  echo "$total"'
    echo '}'
    # Deliberately not named *_test.sh: that is a default BASHUNIT_COVERAGE_EXCLUDE
    # pattern, and an excluded file is never classified at all.
  } >"$dir/libcov.sh"

  {
    echo "source \"$dir/libcov.sh\""
    echo 'function test_covers_source() { assert_not_empty "$(covered_fn)"; }'
  } >"$dir/coverage_forks_test.sh"
}

# Runs a --coverage run with a `grep` PATH shim and echoes the fork count.
function _count_grep_forks_for_coverage() {
  local dir="$1"
  local real_grep="$2"
  local count_file="$dir/grep_count"

  {
    echo '#!/usr/bin/env bash'
    echo "echo x >> \"$count_file\""
    echo "exec \"$real_grep\" \"\$@\""
  } >"$dir/grep"
  chmod +x "$dir/grep"
  : >"$count_file"

  PATH="$dir:$PATH" \
    BASHUNIT_COVERAGE_PATHS="$dir" \
    BASHUNIT_COVERAGE_REPORT="$dir/lcov.info" \
    ./bashunit --no-parallel --coverage "$dir/coverage_forks_test.sh" >/dev/null 2>&1 || true

  local forks=0
  if [ -f "$count_file" ]; then
    forks="$(grep -c . "$count_file" || true)"
  fi
  echo "$forks"
}

function test_coverage_report_does_not_fork_grep_per_source_line() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "PATH shims are unreliable under Git Bash" && return
  fi

  local real_grep
  real_grep="$(command -v grep)"

  # Canonicalise: bashunit::temp_dir can yield a doubled slash (TMPDIR already
  # ends in one), and BASHUNIT_COVERAGE_PATHS is prefix-matched against paths
  # that coverage has already canonicalised — a mismatch tracks nothing at all
  # and the census would silently measure an empty run.
  local small_dir large_dir
  small_dir="$(cd "$(bashunit::temp_dir)" && pwd)"
  large_dir="$(cd "$(bashunit::temp_dir)" && pwd)"

  # 6 lines of source per unit: the large fixture has ~240 more lines to
  # classify than the small one, which used to cost ~480 extra grep forks
  # (every line is classified twice per run).
  _coverage_fixture "$small_dir" 2
  _coverage_fixture "$large_dir" 42

  local small_forks large_forks
  small_forks="$(_count_grep_forks_for_coverage "$small_dir" "$real_grep")"
  large_forks="$(_count_grep_forks_for_coverage "$large_dir" "$real_grep")"

  # Allow a small constant slack for the per-file greps that legitimately
  # remain (hit-data extraction), but nothing proportional to line count.
  assert_less_than 20 "$((large_forks - small_forks))"
}
