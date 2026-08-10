#!/usr/bin/env bash

# Diff coverage: restrict the report to lines changed against a base ref.
#
# A whole-file percentage cannot answer the question a pull request actually
# asks — "are the lines I touched covered?" — and it moves for reasons unrelated
# to the change under review: adding a well-covered file raises the total while
# saying nothing about the new code (#1032).
#
# Only the text report is restricted. LCOV and HTML stay whole-file, because
# their consumers (genhtml, Codecov) do their own diffing and expect complete
# records.

##
# Whether --coverage-diff was requested.
##
function bashunit::coverage::is_diff_enabled() {
  [ -n "${BASHUNIT_COVERAGE_DIFF:-}" ]
}

##
# The base ref the diff is taken against.
##
function bashunit::coverage::diff_base() {
  echo "${BASHUNIT_COVERAGE_DIFF:-}"
}

##
# Percentage of changed executable lines that were hit.
# Nothing changed means nothing to answer for, which is 100% rather than 0% —
# otherwise a docs-only commit would fail a diff threshold.
# Arguments: $1 - changed executable lines, $2 - of those, hit
##
function bashunit::coverage::diff_percentage() {
  local total="$1"
  local hit="$2"
  if [ "$total" -le 0 ]; then
    echo "100"
    return 0
  fi
  echo $((hit * 100 / total))
}

##
# Counts, for one file, the changed lines that are executable and how many of
# those were hit. Output format: "changed_executable:hit"
#
# The caller must have loaded the file's hit data into
# _BASHUNIT_COVERAGE_HITS_BY_LINE first (same contract as compute_file_coverage).
# Arguments: $1 - base ref, $2 - path to the file
##
function bashunit::coverage::changed_line_stats() {
  local base="$1"
  local file="$2"

  local changed
  changed="$(bashunit::helper::git_changed_lines "$base" "$file")"
  if [ -z "$changed" ]; then
    echo "0:0"
    return 0
  fi

  # One pass over the source into an indexed array: the alternative is a read
  # per changed line, and the report path is already the expensive half of a
  # coverage run (#1005).
  local -a src=()
  local _i=0 _l
  while IFS= read -r _l || [ -n "$_l" ]; do
    src[_i]="$_l"
    _i=$((_i + 1))
  done <"$file"

  local total=0 hit=0 lineno content
  for lineno in $changed; do
    content="${src[$((lineno - 1))]:-}"
    if bashunit::coverage::is_executable_line "$content" "$lineno"; then
      total=$((total + 1))
      if [ "${_BASHUNIT_COVERAGE_HITS_BY_LINE[lineno]:-0}" -gt 0 ]; then
        hit=$((hit + 1))
      fi
    fi
  done

  echo "${total}:${hit}"
}

##
# Renders the diff coverage report, replacing the whole-file text report.
# Returns: 0 always; the threshold gate is checked separately.
##
function bashunit::coverage::report_diff() {
  local base
  base="$(bashunit::coverage::diff_base)"

  echo ""
  bashunit::coverage::print_engine_notice
  printf 'Diff Coverage (vs %s)\n' "$base"
  echo "---------------"

  local total_changed=0 total_hit=0 has_files=false
  local file stats changed hit pct color reset="$_BASHUNIT_COLOR_DEFAULT"
  while IFS= read -r file; do
    { [ -z "$file" ] || [ ! -f "$file" ]; } && continue

    bashunit::coverage::load_hits_by_line "$file"
    stats="$(bashunit::coverage::changed_line_stats "$base" "$file")"
    changed="${stats%%:*}"
    hit="${stats##*:}"
    [ "$changed" -eq 0 ] && continue

    has_files=true
    total_changed=$((total_changed + changed))
    total_hit=$((total_hit + hit))

    pct=$(bashunit::coverage::diff_percentage "$changed" "$hit")
    color=$(bashunit::coverage::get_color_for_class \
      "$(bashunit::coverage::get_coverage_class "$pct")")

    local display_file="${file#"$(pwd)"/}"
    printf "%s%-40s %3d/%3d lines (%3d%%)%s\n" \
      "$color" "$display_file" "$hit" "$changed" "$pct" "$reset"
  done < <(bashunit::coverage::get_tracked_files)

  if [ "$has_files" = false ]; then
    echo "No changed executable lines."
  fi

  echo "---------------"
  local total_pct
  total_pct=$(bashunit::coverage::diff_percentage "$total_changed" "$total_hit")
  color=$(bashunit::coverage::get_color_for_class \
    "$(bashunit::coverage::get_coverage_class "$total_pct")")
  printf "%sTotal: %d/%d (%d%%)%s\n" \
    "$color" "$total_hit" "$total_changed" "$total_pct" "$reset"

  _BASHUNIT_COVERAGE_DIFF_PCT_OUT="$total_pct"
}

# Set by report_diff so check_threshold can gate on the diff percentage rather
# than the whole-file one when --coverage-diff is active.
_BASHUNIT_COVERAGE_DIFF_PCT_OUT=""
