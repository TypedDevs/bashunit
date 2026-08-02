#!/usr/bin/env bash

# HTML coverage report: orchestration and shared helpers.

# Escape HTML special characters
# Uses sed for cross-version bash compatibility (bash 3.2 vs 4.4+ handle & differently in replacement strings)
function bashunit::coverage::html_escape() {
  local text="$1"
  printf "%s" "$text" | sed "s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g"
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

    local stats executable hit pct
    stats=$(bashunit::coverage::get_cached_stats "$file")
    bashunit::coverage::split_stats "$stats"
    executable="$_BASHUNIT_COVERAGE_SPLIT_EXEC_OUT"
    hit="$_BASHUNIT_COVERAGE_SPLIT_HIT_OUT"
    pct="$_BASHUNIT_COVERAGE_SPLIT_PCT_OUT"

    total_executable=$((total_executable + executable))
    total_hit=$((total_hit + hit))

    local display_file="${file#"$(pwd)"/}"
    local safe_filename
    safe_filename=$(bashunit::coverage::path_to_filename "$file")

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
