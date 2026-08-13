#!/usr/bin/env bash

# HTML coverage report: orchestration and shared helpers.

# Escape HTML special characters.
#
# This cannot be `${text//&/&amp;}`. Bash 5.2 made a bare `&` in the
# REPLACEMENT mean "the matched text", so `${text//</&lt;}` yields `<lt;`
# there, while escaping it as `\&` to satisfy 5.2 emits a literal backslash on
# 3.2. No single pattern-substitution form is right across the supported range,
# and both failure modes are silent, so the escaping goes through a tool with
# stable semantics.
function bashunit::coverage::html_escape() {
  local text="$1"
  printf "%s" "$text" | sed "s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g"
}

# The same escaping for a whole file, one awk pass, emitting one escaped line
# per source line in order.
#
# The per-line call above cost a command substitution AND a `sed` for every
# line of every page: about 22,000 processes for this repo, which is why an
# HTML report took 58.7s (#1096). In awk the replacement metacharacter is `&`
# too, hence the `\&` in each replacement.
# shellcheck disable=SC2016
_BASHUNIT_COVERAGE_AWK_HTML_ESCAPE='
{
  gsub(/&/, "\\&amp;")
  gsub(/</, "\\&lt;")
  gsub(/>/, "\\&gt;")
  print
}
'

##
# Writes a heredoc block to stdout without forking.
#
# `cat <<EOF` is an external command, and the page emitter has 15 such blocks:
# 1935 forks for a 129-page report, about 3 seconds of it (#1098). A read loop
# over the same heredoc is a builtin, so the markup stays where it is and the
# fork does not happen.
##
function bashunit::coverage::emit_block() {
  local _line
  while IFS= read -r _line || [ -n "$_line" ]; do
    printf '%s\n' "$_line"
  done
}

##
# Escapes every line of $1, one line of output per line of input.
# Arguments: $1 - source file
##
function bashunit::coverage::html_escape_file() {
  env LC_ALL=C "$AWK" "$_BASHUNIT_COVERAGE_AWK_HTML_ESCAPE" "$1"
}

function bashunit::coverage::report_html() {
  local output_dir="${1:-coverage/html}"

  if [ -z "$output_dir" ]; then
    return 0
  fi

  # Create output directory structure
  mkdir -p "$output_dir/files"

  # Collect file data for index
  local IFS=$' \t\n'
  local total_executable=0
  local total_hit=0
  local -a file_data=()
  local file_data_count=0
  local file=""

  while IFS= read -r file; do
    { [ -z "$file" ] || [ ! -f "$file" ]; } && continue

    local executable hit pct
    bashunit::coverage::cached_stats_to_slots "$file"
    executable="$_BASHUNIT_COVERAGE_SPLIT_EXEC_OUT"
    hit="$_BASHUNIT_COVERAGE_SPLIT_HIT_OUT"
    pct="$_BASHUNIT_COVERAGE_SPLIT_PCT_OUT"

    total_executable=$((total_executable + executable))
    total_hit=$((total_hit + hit))

    local display_file="${file#"$PWD"/}"
    bashunit::coverage::path_to_filename_to_slot "$file"
    local safe_filename="$_BASHUNIT_COVERAGE_SAFE_NAME_OUT"

    file_data[file_data_count]="$display_file|$hit|$executable|$pct|$safe_filename"
    file_data_count=$((file_data_count + 1))

    # Generate individual file HTML
    bashunit::coverage::generate_file_html "$file" "$output_dir/files/${safe_filename}.html"
  done < <(bashunit::coverage::get_tracked_files)

  # Calculate total percentage
  local total_pct
  total_pct=$(bashunit::coverage::calculate_percentage "$total_hit" "$total_executable")

  # Get test results
  local tests_passed tests_failed tests_total
  tests_passed=$(bashunit::state::get_tests_passed)
  tests_failed=$(bashunit::state::get_tests_failed)
  tests_total=$((tests_passed + tests_failed))

  # Generate index.html
  bashunit::coverage::generate_index_html \
    "$output_dir/index.html" "$total_hit" "$total_executable" "$total_pct" \
    "$tests_total" "$tests_passed" "$tests_failed" ${file_data[@]+"${file_data[@]}"}

  echo "Coverage HTML report written to: $output_dir/index.html"
}
