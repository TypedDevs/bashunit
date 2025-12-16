#!/usr/bin/env bash
# shellcheck disable=SC2094

# Coverage data storage
_BASHUNIT_COVERAGE_DATA_FILE=""
_BASHUNIT_COVERAGE_TRACKED_FILES=""

# Simple file-based cache for tracked files (Bash 3.2 compatible)
# The tracked cache file stores files that have already been processed
_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE=""

function bashunit::coverage::init() {
  if ! bashunit::env::is_coverage_enabled; then
    return 0
  fi

  # Create coverage data directory
  local coverage_dir
  coverage_dir="${BASHUNIT_TEMP_DIR:-/tmp}/bashunit-coverage-$$"
  mkdir -p "$coverage_dir"

  _BASHUNIT_COVERAGE_DATA_FILE="${coverage_dir}/hits.dat"
  _BASHUNIT_COVERAGE_TRACKED_FILES="${coverage_dir}/files.dat"
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE="${coverage_dir}/cache.dat"

  # Initialize empty files
  : > "$_BASHUNIT_COVERAGE_DATA_FILE"
  : > "$_BASHUNIT_COVERAGE_TRACKED_FILES"
  : > "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"

  export _BASHUNIT_COVERAGE_DATA_FILE
  export _BASHUNIT_COVERAGE_TRACKED_FILES
  export _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE
}

function bashunit::coverage::enable_trap() {
  if ! bashunit::env::is_coverage_enabled; then
    return 0
  fi

  # Enable trap inheritance into functions
  set -T

  # Set DEBUG trap to record line execution
  # Use ${VAR:-} to handle unset variables when set -u is active (in subshells)
  # shellcheck disable=SC2154
  trap 'bashunit::coverage::record_line "${BASH_SOURCE:-}" "${LINENO:-}"' DEBUG
}

function bashunit::coverage::disable_trap() {
  trap - DEBUG
  set +T
}

# Normalize file path to absolute
function bashunit::coverage::normalize_path() {
  local file="$1"

  # Normalize path to absolute
  if [[ -f "$file" ]]; then
    echo "$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
  else
    echo "$file"
  fi
}

function bashunit::coverage::record_line() {
  local file="$1"
  local lineno="$2"

  # Skip if no file or line
  [[ -z "$file" || -z "$lineno" ]] && return 0

  # Skip if coverage data file doesn't exist (trap inherited by child process)
  [[ -z "$_BASHUNIT_COVERAGE_DATA_FILE" ]] && return 0

  # Skip if not tracking this file (uses cache internally)
  bashunit::coverage::should_track "$file" || return 0

  # Normalize file path using cache (must match tracked_files for hit counting)
  local normalized_file
  normalized_file=$(bashunit::coverage::normalize_path "$file")

  # In parallel mode, use a per-process file to avoid race conditions
  local data_file="$_BASHUNIT_COVERAGE_DATA_FILE"
  if bashunit::parallel::is_enabled; then
    data_file="${_BASHUNIT_COVERAGE_DATA_FILE}.$$"
  fi

  # Record the hit (only if parent directory exists)
  [[ -d "$(dirname "$data_file")" ]] && echo "${normalized_file}:${lineno}" >> "$data_file"
}

function bashunit::coverage::should_track() {
  local file="$1"

  # Skip empty paths
  [[ -z "$file" ]] && return 1

  # Skip if tracked files list doesn't exist (trap inherited by child process)
  [[ -z "$_BASHUNIT_COVERAGE_TRACKED_FILES" ]] && return 1

  # Check file-based cache for previous decision (Bash 3.2 compatible)
  # Cache format: "file:0" for excluded, "file:1" for tracked
  if [[ -n "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE" && -f "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE" ]]; then
    local cached_decision
    # Use || true to prevent exit in strict mode when grep finds no match
    cached_decision=$(grep "^${file}:" "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE" 2>/dev/null | head -1) || true
    if [[ -n "$cached_decision" ]]; then
      [[ "${cached_decision##*:}" == "1" ]] && return 0 || return 1
    fi
  fi

  # Normalize path
  local normalized_file
  normalized_file=$(bashunit::coverage::normalize_path "$file")

  # Check exclusion patterns
  # Save and restore IFS to avoid corrupting caller's environment
  local old_ifs="$IFS"
  IFS=','
  local pattern
  for pattern in $BASHUNIT_COVERAGE_EXCLUDE; do
    # shellcheck disable=SC2254
    case "$normalized_file" in
      *$pattern*)
        IFS="$old_ifs"
        # Cache exclusion decision
        [[ -n "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE" ]] && \
          echo "${file}:0" >> "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
        return 1
        ;;
    esac
  done

  # Check inclusion paths
  local matched=false
  local path
  for path in $BASHUNIT_COVERAGE_PATHS; do
    # Resolve relative paths
    local resolved_path
    if [[ "$path" == /* ]]; then
      resolved_path="$path"
    else
      resolved_path="$(pwd)/$path"
    fi

    if [[ "$normalized_file" == "$resolved_path"* ]]; then
      matched=true
      break
    fi
  done
  IFS="$old_ifs"

  if [[ "$matched" == "false" ]]; then
    # Cache exclusion decision
    [[ -n "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE" ]] && \
      echo "${file}:0" >> "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
    return 1
  fi

  # Cache tracking decision
  [[ -n "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE" ]] && \
    echo "${file}:1" >> "$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"

  # Track this file for later reporting
  # In parallel mode, use a per-process file to avoid race conditions
  local tracked_file="$_BASHUNIT_COVERAGE_TRACKED_FILES"
  if bashunit::parallel::is_enabled; then
    tracked_file="${_BASHUNIT_COVERAGE_TRACKED_FILES}.$$"
  fi

  # Only write if parent directory exists
  if [[ -d "$(dirname "$tracked_file")" ]]; then
    # Check if not already written to avoid duplicates
    if ! grep -q "^${normalized_file}$" "$tracked_file" 2>/dev/null; then
      echo "$normalized_file" >> "$tracked_file"
    fi
  fi

  return 0
}

function bashunit::coverage::aggregate_parallel() {
  # Aggregate per-process coverage files created during parallel execution
  local base_file="$_BASHUNIT_COVERAGE_DATA_FILE"
  local tracked_base="$_BASHUNIT_COVERAGE_TRACKED_FILES"

  # Find and merge all per-process coverage data files
  # Use nullglob to handle case when no files match
  local pid_files
  pid_files=$(ls -1 "${base_file}."* 2>/dev/null) || true
  if [[ -n "$pid_files" ]]; then
    while IFS= read -r pid_file; do
      [[ -f "$pid_file" ]] || continue
      cat "$pid_file" >> "$base_file"
      rm -f "$pid_file"
    done <<< "$pid_files"
  fi

  # Find and merge all per-process tracked files lists
  pid_files=$(ls -1 "${tracked_base}."* 2>/dev/null) || true
  if [[ -n "$pid_files" ]]; then
    while IFS= read -r pid_file; do
      [[ -f "$pid_file" ]] || continue
      cat "$pid_file" >> "$tracked_base"
      rm -f "$pid_file"
    done <<< "$pid_files"
  fi

  # Deduplicate tracked files
  if [[ -f "$tracked_base" ]]; then
    sort -u "$tracked_base" -o "$tracked_base"
  fi
}

# Pre-compiled regex pattern for function declarations (performance optimization)
# Matches: function foo() { OR foo() { OR function foo() OR foo()
# Does NOT match single-line functions with body: function foo() { echo "hi"; }
_BASHUNIT_COVERAGE_FUNC_PATTERN='^[[:space:]]*(function[[:space:]]+)?'
_BASHUNIT_COVERAGE_FUNC_PATTERN+='[a-zA-Z_][a-zA-Z0-9_:]*[[:space:]]*\(\)[[:space:]]*\{?[[:space:]]*$'

# Check if a line is executable (used by get_executable_lines and report_lcov)
# Arguments: line content, line number
# Returns: 0 if executable, 1 if not
function bashunit::coverage::is_executable_line() {
  local line="$1"
  local lineno="$2"

  # Skip empty lines (line with only whitespace)
  [[ -z "${line// }" ]] && return 1

  # Skip comment-only lines (but not shebang on line 1)
  if [[ "$line" =~ ^[[:space:]]*# ]] && [[ $lineno -ne 1 ]]; then
    return 1
  fi

  # Skip function declaration lines (but not single-line functions with body)
  [[ "$line" =~ $_BASHUNIT_COVERAGE_FUNC_PATTERN ]] && return 1

  # Skip lines with only braces
  [[ "$line" =~ ^[[:space:]]*[\{\}][[:space:]]*$ ]] && return 1

  return 0
}

function bashunit::coverage::get_executable_lines() {
  local file="$1"
  local count=0
  local lineno=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    ((lineno++))
    bashunit::coverage::is_executable_line "$line" "$lineno" && ((count++))
  done < "$file"

  echo "$count"
}

function bashunit::coverage::get_hit_lines() {
  local file="$1"

  if [[ ! -f "$_BASHUNIT_COVERAGE_DATA_FILE" ]]; then
    echo "0"
    return
  fi

  # Count unique lines hit for this file
  # Use subshell with || echo 0 to handle no matches gracefully in strict mode
  (grep "^${file}:" "$_BASHUNIT_COVERAGE_DATA_FILE" 2>/dev/null || true) | \
    cut -d: -f2 | sort -u | wc -l | tr -d ' '
}

function bashunit::coverage::get_line_hits() {
  local file="$1"
  local lineno="$2"

  if [[ ! -f "$_BASHUNIT_COVERAGE_DATA_FILE" ]]; then
    echo "0"
    return
  fi

  local count
  count=$(grep -c "^${file}:${lineno}$" "$_BASHUNIT_COVERAGE_DATA_FILE" 2>/dev/null) || count=0
  echo "$count"
}

# Get all line hits for a file in one pass (performance optimization)
# Output format: one "lineno:count" per line
function bashunit::coverage::get_all_line_hits() {
  local file="$1"

  if [[ ! -f "$_BASHUNIT_COVERAGE_DATA_FILE" ]]; then
    return
  fi

  # Extract all lines for this file, count occurrences of each line number
  grep "^${file}:" "$_BASHUNIT_COVERAGE_DATA_FILE" 2>/dev/null | \
    cut -d: -f2 | sort | uniq -c | \
    while read -r count lineno; do
      echo "${lineno}:${count}"
    done
}

function bashunit::coverage::get_percentage() {
  local total_executable=0
  local total_hit=0

  # Check if tracked files exist
  if [[ ! -f "$_BASHUNIT_COVERAGE_TRACKED_FILES" ]]; then
    echo "0"
    return
  fi

  while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue

    local executable
    executable=$(bashunit::coverage::get_executable_lines "$file")
    local hit
    hit=$(bashunit::coverage::get_hit_lines "$file")

    ((total_executable += executable))
    ((total_hit += hit))
  done < "$_BASHUNIT_COVERAGE_TRACKED_FILES"

  if [[ $total_executable -eq 0 ]]; then
    echo "0"
    return
  fi

  # Calculate percentage (integer)
  echo $((total_hit * 100 / total_executable))
}

function bashunit::coverage::report_text() {
  if ! bashunit::env::is_coverage_enabled; then
    return 0
  fi

  local total_executable=0
  local total_hit=0

  echo ""
  echo "Coverage Report"
  echo "---------------"

  # Check if tracked files exist
  if [[ ! -f "$_BASHUNIT_COVERAGE_TRACKED_FILES" ]]; then
    echo "---------------"
    echo "Total: 0/0 (0%)"
    return 0
  fi

  while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue

    local executable
    executable=$(bashunit::coverage::get_executable_lines "$file")
    local hit
    hit=$(bashunit::coverage::get_hit_lines "$file")

    ((total_executable += executable))
    ((total_hit += hit))

    # Calculate percentage
    local pct=0
    if [[ $executable -gt 0 ]]; then
      pct=$((hit * 100 / executable))
    fi

    # Determine color based on thresholds
    local color=""
    local reset=""
    if [[ "${BASHUNIT_NO_COLOR:-false}" != "true" ]]; then
      reset=$'\033[0m'
      if [[ $pct -lt ${BASHUNIT_COVERAGE_THRESHOLD_LOW:-50} ]]; then
        color=$'\033[31m'  # Red
      elif [[ $pct -lt ${BASHUNIT_COVERAGE_THRESHOLD_HIGH:-80} ]]; then
        color=$'\033[33m'  # Yellow
      else
        color=$'\033[32m'  # Green
      fi
    fi

    # Display relative path
    local display_file
    display_file="${file#"$(pwd)"/}"

    printf "%s%-40s %3d/%3d lines (%3d%%)%s\n" \
      "$color" "$display_file" "$hit" "$executable" "$pct" "$reset"
  done < "$_BASHUNIT_COVERAGE_TRACKED_FILES"

  echo "---------------"

  # Total
  local total_pct=0
  if [[ $total_executable -gt 0 ]]; then
    total_pct=$((total_hit * 100 / total_executable))
  fi

  local color=""
  local reset=""
  if [[ "${BASHUNIT_NO_COLOR:-false}" != "true" ]]; then
    reset=$'\033[0m'
    if [[ $total_pct -lt ${BASHUNIT_COVERAGE_THRESHOLD_LOW:-50} ]]; then
      color=$'\033[31m'
    elif [[ $total_pct -lt ${BASHUNIT_COVERAGE_THRESHOLD_HIGH:-80} ]]; then
      color=$'\033[33m'
    else
      color=$'\033[32m'
    fi
  fi

  printf "%sTotal: %d/%d (%d%%)%s\n" \
    "$color" "$total_hit" "$total_executable" "$total_pct" "$reset"

  # Show report location if generated
  if [[ -n "$BASHUNIT_COVERAGE_REPORT" ]]; then
    echo ""
    echo "Coverage report written to: $BASHUNIT_COVERAGE_REPORT"
  fi
}

function bashunit::coverage::report_lcov() {
  local output_file="${1:-$BASHUNIT_COVERAGE_REPORT}"

  if [[ -z "$output_file" ]]; then
    return 0
  fi

  # Create output directory if needed
  local output_dir
  output_dir=$(dirname "$output_file")
  mkdir -p "$output_dir"

  # Check if tracked files exist - if not, write empty LCOV file
  if [[ ! -f "$_BASHUNIT_COVERAGE_TRACKED_FILES" ]]; then
    echo "TN:" > "$output_file"
    return 0
  fi

  # Generate LCOV format
  {
    echo "TN:"

    while IFS= read -r file; do
      [[ -z "$file" || ! -f "$file" ]] && continue

      echo "SF:$file"

      local lineno=0
      # shellcheck disable=SC2094
      while IFS= read -r line || [[ -n "$line" ]]; do
        ((lineno++))

        # Skip non-executable lines (use shared helper)
        bashunit::coverage::is_executable_line "$line" "$lineno" || continue

        # Get hit count for this line
        local hits
        hits=$(bashunit::coverage::get_line_hits "$file" "$lineno")

        echo "DA:${lineno},${hits}"
      done < "$file"

      local executable
      executable=$(bashunit::coverage::get_executable_lines "$file")
      local hit
      hit=$(bashunit::coverage::get_hit_lines "$file")

      echo "LF:$executable"
      echo "LH:$hit"
      echo "end_of_record"
    done < "$_BASHUNIT_COVERAGE_TRACKED_FILES"
  } > "$output_file"
}

function bashunit::coverage::check_threshold() {
  if [[ -z "$BASHUNIT_COVERAGE_MIN" ]]; then
    return 0
  fi

  local pct
  pct=$(bashunit::coverage::get_percentage)

  if [[ $pct -lt $BASHUNIT_COVERAGE_MIN ]]; then
    local color=""
    local reset=""
    if [[ "${BASHUNIT_NO_COLOR:-false}" != "true" ]]; then
      color=$'\033[31m'
      reset=$'\033[0m'
    fi
    printf "%sCoverage %d%% is below minimum %d%%%s\n" \
      "$color" "$pct" "$BASHUNIT_COVERAGE_MIN" "$reset"
    return 1
  fi

  return 0
}

# Escape HTML special characters
function bashunit::coverage::html_escape() {
  local text="$1"
  text="${text//&/&amp;}"
  text="${text//</&lt;}"
  text="${text//>/&gt;}"
  echo "$text"
}

# Convert file path to safe filename for HTML
function bashunit::coverage::path_to_filename() {
  local file="$1"
  local display_file="${file#"$(pwd)"/}"
  # Replace / with _ and . with _
  local safe_name="${display_file//\//_}"
  echo "${safe_name//./_}"
}

function bashunit::coverage::report_html() {
  local output_dir="${1:-coverage/html}"

  if [[ -z "$output_dir" ]]; then
    return 0
  fi

  # Check if tracked files exist
  if [[ ! -f "$_BASHUNIT_COVERAGE_TRACKED_FILES" ]]; then
    return 0
  fi

  # Create output directory structure
  mkdir -p "$output_dir/files"

  # Collect file data for index
  local total_executable=0
  local total_hit=0
  local file_data=()

  while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue

    local executable
    executable=$(bashunit::coverage::get_executable_lines "$file")
    local hit
    hit=$(bashunit::coverage::get_hit_lines "$file")

    ((total_executable += executable))
    ((total_hit += hit))

    local pct=0
    if [[ $executable -gt 0 ]]; then
      pct=$((hit * 100 / executable))
    fi

    local display_file="${file#"$(pwd)"/}"
    local safe_filename
    safe_filename=$(bashunit::coverage::path_to_filename "$file")

    file_data+=("$display_file|$hit|$executable|$pct|$safe_filename")

    # Generate individual file HTML
    bashunit::coverage::generate_file_html "$file" "$output_dir/files/${safe_filename}.html"
  done < "$_BASHUNIT_COVERAGE_TRACKED_FILES"

  # Calculate total percentage
  local total_pct=0
  if [[ $total_executable -gt 0 ]]; then
    total_pct=$((total_hit * 100 / total_executable))
  fi

  # Generate index.html
  bashunit::coverage::generate_index_html \
    "$output_dir/index.html" "$total_hit" "$total_executable" "$total_pct" "${file_data[@]}"

  echo "Coverage HTML report written to: $output_dir/index.html"
}

function bashunit::coverage::generate_index_html() {
  local output_file="$1"
  local total_hit="$2"
  local total_executable="$3"
  local total_pct="$4"
  shift 4
  local file_data=("$@")

  # Determine total color class
  local total_class="low"
  if [[ $total_pct -ge ${BASHUNIT_COVERAGE_THRESHOLD_HIGH:-80} ]]; then
    total_class="high"
  elif [[ $total_pct -ge ${BASHUNIT_COVERAGE_THRESHOLD_LOW:-50} ]]; then
    total_class="medium"
  fi

  {
    cat << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Coverage Report</title>
  <style>
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      margin: 0;
      padding: 20px;
      background: #f5f5f5;
    }
    .container { max-width: 1200px; margin: 0 auto; }
    h1 { color: #333; margin-bottom: 20px; }
    .summary {
      background: white;
      border-radius: 8px;
      padding: 20px;
      margin-bottom: 20px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    }
    .summary-title { font-size: 1.2em; margin-bottom: 10px; color: #666; }
    .summary-pct { font-size: 2.5em; font-weight: bold; }
    .summary-pct.high { color: #28a745; }
    .summary-pct.medium { color: #ffc107; }
    .summary-pct.low { color: #dc3545; }
    .summary-detail { color: #666; margin-top: 5px; }
    table {
      width: 100%;
      border-collapse: collapse;
      background: white;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    }
    th, td { padding: 12px 15px; text-align: left; }
    th { background: #f8f9fa; font-weight: 600; color: #333; border-bottom: 2px solid #dee2e6; }
    td { border-bottom: 1px solid #dee2e6; }
    tr:last-child td { border-bottom: none; }
    tr:hover { background: #f8f9fa; }
    .file-link { color: #007bff; text-decoration: none; }
    .file-link:hover { text-decoration: underline; }
    .pct { font-weight: 600; }
    .pct.high { color: #28a745; }
    .pct.medium { color: #ffc107; }
    .pct.low { color: #dc3545; }
    .progress-bar {
      width: 100px;
      height: 8px;
      background: #e9ecef;
      border-radius: 4px;
      overflow: hidden;
    }
    .progress-fill { height: 100%; border-radius: 4px; }
    .progress-fill.high { background: #28a745; }
    .progress-fill.medium { background: #ffc107; }
    .progress-fill.low { background: #dc3545; }
    .text-right { text-align: right; }
    .text-center { text-align: center; }
    .footer { margin-top: 20px; color: #666; font-size: 0.9em; text-align: center; }
    .footer a { color: #007bff; text-decoration: none; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Coverage Report</h1>
    <div class="summary">
      <div class="summary-title">Total Coverage</div>
EOF
    echo "      <div class=\"summary-pct $total_class\">${total_pct}%</div>"
    echo "      <div class=\"summary-detail\">${total_hit} of ${total_executable} lines covered</div>"
    cat << 'EOF'
    </div>
    <table>
      <thead>
        <tr>
          <th>File</th>
          <th class="text-right">Lines</th>
          <th class="text-center">Coverage</th>
          <th style="width: 120px;"></th>
        </tr>
      </thead>
      <tbody>
EOF

    for data in "${file_data[@]}"; do
      IFS='|' read -r display_file hit executable pct safe_filename <<< "$data"

      local class="low"
      if [[ $pct -ge ${BASHUNIT_COVERAGE_THRESHOLD_HIGH:-80} ]]; then
        class="high"
      elif [[ $pct -ge ${BASHUNIT_COVERAGE_THRESHOLD_LOW:-50} ]]; then
        class="medium"
      fi

      echo "        <tr>"
      echo "          <td><a class=\"file-link\" href=\"files/${safe_filename}.html\">$display_file</a></td>"
      echo "          <td class=\"text-right\">${hit}/${executable}</td>"
      echo "          <td class=\"text-center pct $class\">${pct}%</td>"
      echo "          <td><div class=\"progress-bar\">"
      echo "<div class=\"progress-fill $class\" style=\"width: ${pct}%;\"></div></div></td>"
      echo "        </tr>"
    done

    cat << 'EOF'
      </tbody>
    </table>
    <div class="footer">
      Generated by <a href="https://bashunit.typeddevs.com">bashunit</a>
    </div>
  </div>
</body>
</html>
EOF
  } > "$output_file"
}

function bashunit::coverage::generate_file_html() {
  local file="$1"
  local output_file="$2"

  local display_file="${file#"$(pwd)"/}"
  local executable
  executable=$(bashunit::coverage::get_executable_lines "$file")
  local hit
  hit=$(bashunit::coverage::get_hit_lines "$file")

  local pct=0
  if [[ $executable -gt 0 ]]; then
    pct=$((hit * 100 / executable))
  fi

  local class="low"
  if [[ $pct -ge ${BASHUNIT_COVERAGE_THRESHOLD_HIGH:-80} ]]; then
    class="high"
  elif [[ $pct -ge ${BASHUNIT_COVERAGE_THRESHOLD_LOW:-50} ]]; then
    class="medium"
  fi

  # Pre-load all line hits into indexed array (performance optimization)
  local -a hits_by_line=()
  local _ln _cnt
  while IFS=: read -r _ln _cnt; do
    hits_by_line[_ln]=$_cnt
  done < <(bashunit::coverage::get_all_line_hits "$file")

  {
    cat << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
EOF
    echo "  <title>Coverage: $display_file</title>"
    cat << 'EOF'
  <style>
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      margin: 0;
      padding: 20px;
      background: #f5f5f5;
    }
    .container { max-width: 1400px; margin: 0 auto; }
    h1 { color: #333; margin-bottom: 5px; font-size: 1.5em; }
    .breadcrumb { margin-bottom: 20px; }
    .breadcrumb a { color: #007bff; text-decoration: none; }
    .breadcrumb a:hover { text-decoration: underline; }
    .summary {
      background: white;
      border-radius: 8px;
      padding: 15px 20px;
      margin-bottom: 20px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1);
      display: flex;
      align-items: center;
      gap: 20px;
    }
    .summary-pct { font-size: 1.8em; font-weight: bold; }
    .summary-pct.high { color: #28a745; }
    .summary-pct.medium { color: #ffc107; }
    .summary-pct.low { color: #dc3545; }
    .summary-detail { color: #666; }
    .code-container {
      background: white;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    }
    table { width: 100%; border-collapse: collapse; }
    tr { line-height: 1.4; }
    tr:hover { background: rgba(0,0,0,0.02); }
    .line-num {
      width: 50px;
      text-align: right;
      padding: 0 10px;
      color: #999;
      background: #f8f9fa;
      border-right: 1px solid #e9ecef;
      user-select: none;
      font-family: 'SF Mono', Monaco, 'Courier New', monospace;
      font-size: 12px;
    }
    .hits {
      width: 50px;
      text-align: center;
      padding: 0 8px;
      color: #666;
      background: #f8f9fa;
      border-right: 1px solid #e9ecef;
      font-family: 'SF Mono', Monaco, 'Courier New', monospace;
      font-size: 12px;
    }
    .code {
      padding: 0 15px;
      font-family: 'SF Mono', Monaco, 'Courier New', monospace;
      font-size: 13px;
      white-space: pre;
      overflow-x: auto;
    }
    .covered { background-color: #d4edda; }
    .covered .line-num, .covered .hits { background-color: #c3e6cb; }
    .uncovered { background-color: #f8d7da; }
    .uncovered .line-num, .uncovered .hits { background-color: #f5c6cb; }
    .footer { margin-top: 20px; color: #666; font-size: 0.9em; text-align: center; }
    .footer a { color: #007bff; text-decoration: none; }
  </style>
</head>
<body>
  <div class="container">
    <div class="breadcrumb"><a href="../index.html">&larr; Back to Index</a></div>
EOF
    echo "    <h1>$display_file</h1>"
    echo "    <div class=\"summary\">"
    echo "      <div class=\"summary-pct $class\">${pct}%</div>"
    echo "      <div class=\"summary-detail\">${hit} of ${executable} lines covered</div>"
    echo "    </div>"
    echo "    <div class=\"code-container\">"
    echo "      <table>"

    local lineno=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      ((lineno++))

      local escaped_line
      escaped_line=$(bashunit::coverage::html_escape "$line")

      local row_class=""
      local hits_display=""

      if bashunit::coverage::is_executable_line "$line" "$lineno"; then
        # O(1) lookup from pre-loaded array
        local hits=${hits_by_line[$lineno]:-0}
        hits_display="$hits"

        if [[ $hits -gt 0 ]]; then
          row_class="covered"
        else
          row_class="uncovered"
        fi
      fi

      echo "        <tr class=\"$row_class\">"
      echo "          <td class=\"line-num\">$lineno</td>"
      echo "          <td class=\"hits\">$hits_display</td>"
      echo "          <td class=\"code\">$escaped_line</td>"
      echo "        </tr>"
    done < "$file"

    cat << 'EOF'
      </table>
    </div>
    <div class="footer">
      Generated by <a href="https://bashunit.typeddevs.com">bashunit</a>
    </div>
  </div>
</body>
</html>
EOF
  } > "$output_file"
}

function bashunit::coverage::cleanup() {
  if [[ -n "$_BASHUNIT_COVERAGE_DATA_FILE" ]]; then
    local coverage_dir
    coverage_dir=$(dirname "$_BASHUNIT_COVERAGE_DATA_FILE")
    rm -rf "$coverage_dir"
  fi
}
