#!/usr/bin/env bash
# shellcheck disable=SC2094

# Coverage data storage
# Use :- to preserve inherited values from parent bashunit processes
_BASHUNIT_COVERAGE_DATA_FILE="${_BASHUNIT_COVERAGE_DATA_FILE:-}"
_BASHUNIT_COVERAGE_TRACKED_FILES="${_BASHUNIT_COVERAGE_TRACKED_FILES:-}"

# Simple file-based cache for tracked files (Bash 3.2 compatible)
# The tracked cache file stores files that have already been processed
_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE="${_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE:-}"

# Store the subshell level when coverage trap is enabled
# Used to skip recording in nested subshells (command substitution)
# Uses $BASH_SUBSHELL which is Bash 3.2 compatible (unlike $BASHPID)
_BASHUNIT_COVERAGE_SUBSHELL_LEVEL="${_BASHUNIT_COVERAGE_SUBSHELL_LEVEL:-}"

function bashunit::coverage::init() {
  if ! bashunit::env::is_coverage_enabled; then
    return 0
  fi

  # Skip coverage init if we're a subprocess of another coverage-enabled bashunit
  # This prevents nested bashunit calls (e.g., in acceptance tests) from
  # interfering with the parent's coverage tracking
  if [[ -n "${_BASHUNIT_COVERAGE_DATA_FILE:-}" ]]; then
    export BASHUNIT_COVERAGE=false
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

  # Store the subshell level for nested subshell detection
  # $BASH_SUBSHELL increments in each nested subshell (Bash 3.2 compatible)
  _BASHUNIT_COVERAGE_SUBSHELL_LEVEL="$BASH_SUBSHELL"
  export _BASHUNIT_COVERAGE_SUBSHELL_LEVEL

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

  # Skip recording in nested subshells (command substitution like $(...))
  # $BASH_SUBSHELL increments in each nested subshell
  # This prevents interference with tests that capture output
  [[ -n "$_BASHUNIT_COVERAGE_SUBSHELL_LEVEL" && "$BASH_SUBSHELL" -gt "$_BASHUNIT_COVERAGE_SUBSHELL_LEVEL" ]] && return 0

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
  # In parallel mode, use per-process cache to avoid race conditions
  local cache_file="$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
  if bashunit::parallel::is_enabled && [[ -n "$cache_file" ]]; then
    cache_file="${cache_file}.$$"
    # Initialize per-process cache if needed
    [[ ! -f "$cache_file" ]] && [[ -d "$(dirname "$cache_file")" ]] && : > "$cache_file"
  fi
  if [[ -n "$cache_file" && -f "$cache_file" ]]; then
    local cached_decision
    # Use || true to prevent exit in strict mode when grep finds no match
    cached_decision=$(grep "^${file}:" "$cache_file" 2>/dev/null | head -1) || true
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
        # Cache exclusion decision (use per-process cache in parallel mode)
        [[ -n "$cache_file" && -f "$cache_file" ]] && echo "${file}:0" >> "$cache_file"
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
    # Cache exclusion decision (use per-process cache in parallel mode)
    [[ -n "$cache_file" && -f "$cache_file" ]] && echo "${file}:0" >> "$cache_file"
    return 1
  fi

  # Cache tracking decision (use per-process cache in parallel mode)
  [[ -n "$cache_file" && -f "$cache_file" ]] && echo "${file}:1" >> "$cache_file"

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

  # Unused but kept for API compatibility
  : "$lineno"

  # Skip empty lines (line with only whitespace)
  [[ -z "${line// }" ]] && return 1

  # Skip comment-only lines (including shebang)
  [[ "$line" =~ ^[[:space:]]*# ]] && return 1

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

  # Get unique hit line numbers
  local hit_lines
  hit_lines=$( (grep "^${file}:" "$_BASHUNIT_COVERAGE_DATA_FILE" 2>/dev/null || true) | \
    cut -d: -f2 | sort -u)

  if [[ -z "$hit_lines" ]]; then
    echo "0"
    return
  fi

  # Only count hits that correspond to executable lines
  # This prevents >100% coverage when DEBUG trap fires on non-executable lines
  local count=0
  local line_num
  for line_num in $hit_lines; do
    local line_content
    line_content=$(sed -n "${line_num}p" "$file" 2>/dev/null) || continue
    if bashunit::coverage::is_executable_line "$line_content" "$line_num"; then
      ((count++))
    fi
  done

  echo "$count"
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

  # Calculate uncovered lines and file count
  local total_uncovered=$((total_executable - total_hit))
  local file_count=${#file_data[@]}

  # Calculate gauge stroke offset (440 is full circle circumference)
  local gauge_offset=$((440 - (440 * total_pct / 100)))

  {
    cat << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Coverage Report | bashunit</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --primary: #6366f1; --primary-dark: #4f46e5; --primary-light: #818cf8;
      --success: #10b981; --success-light: #34d399;
      --warning: #f59e0b; --warning-light: #fbbf24;
      --danger: #ef4444; --danger-light: #f87171;
      --bg-dark: #0f172a; --bg-card: #1e293b; --bg-hover: #334155;
      --text-primary: #f8fafc; --text-secondary: #94a3b8; --text-muted: #64748b;
      --border: #334155;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif; background: var(--bg-dark); color: var(--text-primary); min-height: 100vh; line-height: 1.6; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 0; position: relative; overflow: hidden; }
    .header::before { content: ''; position: absolute; inset: 0; background: url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none'%3E%3Cg fill='%23ffffff' fill-opacity='0.05'%3E%3Cpath d='M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E"); opacity: 0.5; }
    .header-content { position: relative; z-index: 1; max-width: 1400px; margin: 0 auto; padding: 40px 30px; }
    .header-top { display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; }
    .logo { display: flex; align-items: center; gap: 12px; }
    .logo-icon { width: 48px; height: 48px; background: rgba(255,255,255,0.2); border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 24px; backdrop-filter: blur(10px); }
    .logo-text { font-size: 1.5rem; font-weight: 700; letter-spacing: -0.5px; }
    .logo-text span { opacity: 0.7; font-weight: 400; }
    .header-badge { background: rgba(255,255,255,0.2); padding: 8px 16px; border-radius: 20px; font-size: 0.85rem; font-weight: 500; backdrop-filter: blur(10px); }
    .header-title { font-size: 2.5rem; font-weight: 800; margin-bottom: 8px; letter-spacing: -1px; }
    .header-subtitle { font-size: 1.1rem; opacity: 0.9; }
    .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 20px; max-width: 1400px; margin: -50px auto 0; padding: 0 30px; position: relative; z-index: 10; }
    .stat-card { background: var(--bg-card); border-radius: 16px; padding: 24px; border: 1px solid var(--border); transition: all 0.3s ease; position: relative; overflow: hidden; animation: fadeInUp 0.5s ease-out forwards; opacity: 0; }
    .stat-card::before { content: ''; position: absolute; top: 0; left: 0; right: 0; height: 4px; }
    .stat-card.coverage::before { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
    .stat-card.lines::before { background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); }
    .stat-card.covered::before { background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); }
    .stat-card.uncovered::before { background: linear-gradient(135deg, #cb2d3e 0%, #ef473a 100%); }
    .stat-card.files::before { background: linear-gradient(135deg, #f7971e 0%, #ffd200 100%); }
    .stat-card:hover { transform: translateY(-4px); border-color: var(--primary); box-shadow: 0 20px 40px rgba(0,0,0,0.3); }
    .stat-card:nth-child(1) { animation-delay: 0.1s; } .stat-card:nth-child(2) { animation-delay: 0.2s; } .stat-card:nth-child(3) { animation-delay: 0.3s; } .stat-card:nth-child(4) { animation-delay: 0.4s; } .stat-card:nth-child(5) { animation-delay: 0.5s; }
    .stat-icon { width: 48px; height: 48px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 24px; margin-bottom: 16px; }
    .stat-card.coverage .stat-icon { background: rgba(99, 102, 241, 0.2); }
    .stat-card.lines .stat-icon { background: rgba(79, 209, 254, 0.2); }
    .stat-card.covered .stat-icon { background: rgba(16, 185, 129, 0.2); }
    .stat-card.uncovered .stat-icon { background: rgba(239, 68, 68, 0.2); }
    .stat-card.files .stat-icon { background: rgba(245, 158, 11, 0.2); }
    .stat-value { font-size: 2.5rem; font-weight: 800; letter-spacing: -1px; margin-bottom: 4px; }
    .stat-card.coverage .stat-value { color: var(--primary-light); }
    .stat-card.lines .stat-value { color: #4facfe; }
    .stat-card.covered .stat-value { color: var(--success); }
    .stat-card.uncovered .stat-value { color: var(--danger); }
    .stat-card.files .stat-value { color: var(--warning); }
    .stat-label { color: var(--text-secondary); font-size: 0.9rem; font-weight: 500; text-transform: uppercase; letter-spacing: 1px; }
    .main { max-width: 1400px; margin: 0 auto; padding: 40px 30px; }
    .gauge-section { background: var(--bg-card); border-radius: 20px; padding: 40px; margin-bottom: 30px; border: 1px solid var(--border); display: flex; align-items: center; gap: 60px; }
    .gauge-container { position: relative; width: 200px; height: 200px; flex-shrink: 0; }
    .gauge-bg { fill: none; stroke: var(--bg-hover); stroke-width: 20; }
    .gauge-fill { fill: none; stroke: url(#gaugeGradient); stroke-width: 20; stroke-linecap: round; transform: rotate(-90deg); transform-origin: center; animation: gaugeAnimation 1.5s ease-out forwards; }
    @keyframes gaugeAnimation { from { stroke-dashoffset: 440; } }
    @keyframes fadeInUp { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }
    .gauge-text { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); text-align: center; }
    .gauge-percent { font-size: 3.5rem; font-weight: 800; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }
    .gauge-label { color: var(--text-secondary); font-size: 0.9rem; text-transform: uppercase; letter-spacing: 2px; }
    .gauge-info { flex: 1; }
    .gauge-title { font-size: 1.8rem; font-weight: 700; margin-bottom: 12px; }
    .gauge-description { color: var(--text-secondary); font-size: 1.05rem; margin-bottom: 24px; line-height: 1.7; }
    .gauge-breakdown { display: flex; gap: 30px; flex-wrap: wrap; }
    .breakdown-item { display: flex; align-items: center; gap: 10px; }
    .breakdown-dot { width: 12px; height: 12px; border-radius: 50%; }
    .breakdown-dot.covered { background: var(--success); }
    .breakdown-dot.uncovered { background: var(--danger); }
    .breakdown-dot.ignored { background: var(--text-muted); }
    .breakdown-label { color: var(--text-secondary); font-size: 0.9rem; }
    .breakdown-value { font-weight: 600; color: var(--text-primary); }
    .section-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; flex-wrap: wrap; gap: 16px; }
    .section-title { font-size: 1.5rem; font-weight: 700; display: flex; align-items: center; gap: 12px; }
    .section-title::before { content: ''; width: 4px; height: 24px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 2px; }
    .legend { display: flex; gap: 20px; background: var(--bg-hover); padding: 12px 20px; border-radius: 10px; }
    .legend-item { display: flex; align-items: center; gap: 8px; font-size: 0.85rem; color: var(--text-secondary); }
    .legend-color { width: 16px; height: 16px; border-radius: 4px; }
    .legend-color.high { background: var(--success); }
    .legend-color.medium { background: var(--warning); }
    .legend-color.low { background: var(--danger); }
    .files-table { background: var(--bg-card); border-radius: 16px; overflow: hidden; border: 1px solid var(--border); }
    .files-table table { width: 100%; border-collapse: collapse; }
    .files-table th { background: var(--bg-hover); padding: 16px 24px; text-align: left; font-weight: 600; color: var(--text-secondary); font-size: 0.85rem; text-transform: uppercase; letter-spacing: 1px; border-bottom: 1px solid var(--border); }
    .files-table td { padding: 20px 24px; border-bottom: 1px solid var(--border); vertical-align: middle; }
    .files-table tr:last-child td { border-bottom: none; }
    .files-table tbody tr { transition: all 0.2s ease; animation: fadeInUp 0.5s ease-out forwards; opacity: 0; }
    .files-table tbody tr:nth-child(1) { animation-delay: 0.6s; } .files-table tbody tr:nth-child(2) { animation-delay: 0.7s; } .files-table tbody tr:nth-child(3) { animation-delay: 0.8s; } .files-table tbody tr:nth-child(4) { animation-delay: 0.9s; } .files-table tbody tr:nth-child(5) { animation-delay: 1.0s; }
    .files-table tbody tr:hover { background: var(--bg-hover); }
    .file-info { display: flex; align-items: center; gap: 16px; }
    .file-icon { width: 44px; height: 44px; background: var(--bg-hover); border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 20px; flex-shrink: 0; }
    .file-name { font-weight: 600; color: var(--text-primary); text-decoration: none; font-size: 1rem; transition: color 0.2s; }
    .file-name:hover { color: var(--primary-light); }
    .file-path { color: var(--text-muted); font-size: 0.85rem; font-family: 'JetBrains Mono', monospace; }
    .lines-info { text-align: center; }
    .lines-covered { font-weight: 700; font-size: 1.1rem; color: var(--text-primary); }
    .lines-total { color: var(--text-muted); font-size: 0.85rem; }
    .coverage-cell { width: 200px; }
    .coverage-bar-container { display: flex; align-items: center; gap: 16px; }
    .coverage-bar { flex: 1; height: 10px; background: var(--bg-hover); border-radius: 5px; overflow: hidden; }
    .coverage-bar-fill { height: 100%; border-radius: 5px; transition: width 1s ease-out; }
    .coverage-bar-fill.high { background: linear-gradient(90deg, var(--success) 0%, var(--success-light) 100%); }
    .coverage-bar-fill.medium { background: linear-gradient(90deg, var(--warning) 0%, var(--warning-light) 100%); }
    .coverage-bar-fill.low { background: linear-gradient(90deg, var(--danger) 0%, var(--danger-light) 100%); }
    .coverage-percent { font-weight: 700; font-size: 1rem; min-width: 50px; text-align: right; }
    .coverage-percent.high { color: var(--success); }
    .coverage-percent.medium { color: var(--warning); }
    .coverage-percent.low { color: var(--danger); }
    .view-btn { display: inline-flex; align-items: center; gap: 8px; padding: 10px 20px; background: var(--bg-hover); border: 1px solid var(--border); border-radius: 8px; color: var(--text-primary); text-decoration: none; font-size: 0.9rem; font-weight: 500; transition: all 0.2s; }
    .view-btn:hover { background: var(--primary); border-color: var(--primary); transform: translateX(4px); }
    .footer { max-width: 1400px; margin: 0 auto; padding: 40px 30px; text-align: center; border-top: 1px solid var(--border); }
    .footer-content { display: flex; justify-content: center; align-items: center; gap: 20px; flex-wrap: wrap; }
    .footer-text { color: var(--text-muted); font-size: 0.9rem; }
    .footer-link { color: var(--primary-light); text-decoration: none; font-weight: 500; transition: color 0.2s; }
    .footer-link:hover { color: var(--primary); }
    .footer-divider { width: 4px; height: 4px; background: var(--text-muted); border-radius: 50%; }
    @media (max-width: 768px) {
      .header-content { padding: 30px 20px; } .header-title { font-size: 1.8rem; }
      .stats-grid { padding: 0 20px; gap: 15px; margin-top: -30px; }
      .stat-card { padding: 20px; } .stat-value { font-size: 2rem; }
      .main { padding: 30px 20px; }
      .gauge-section { flex-direction: column; padding: 30px; gap: 30px; }
      .gauge-container { width: 160px; height: 160px; } .gauge-percent { font-size: 2.5rem; }
      .gauge-breakdown { flex-direction: column; gap: 15px; }
      .files-table th, .files-table td { padding: 15px; }
      .coverage-cell { width: auto; }
      .coverage-bar-container { flex-direction: column; align-items: flex-start; gap: 8px; }
      .coverage-bar { width: 100%; }
    }
  </style>
</head>
<body>
  <header class="header">
    <div class="header-content">
      <div class="header-top">
        <div class="logo">
          <div class="logo-icon">🧪</div>
          <div class="logo-text">bashunit <span>coverage</span></div>
        </div>
EOF
    echo "        <div class=\"header-badge\">v${BASHUNIT_VERSION:-0.0.0}</div>"
    cat << 'EOF'
      </div>
      <h1 class="header-title">Code Coverage Report</h1>
      <p class="header-subtitle">Comprehensive line-by-line coverage analysis for your bash scripts</p>
    </div>
  </header>
  <div class="stats-grid">
    <div class="stat-card coverage">
      <div class="stat-icon">📊</div>
EOF
    echo "      <div class=\"stat-value\">${total_pct}%</div>"
    cat << 'EOF'
      <div class="stat-label">Total Coverage</div>
    </div>
    <div class="stat-card lines">
      <div class="stat-icon">📝</div>
EOF
    echo "      <div class=\"stat-value\">${total_executable}</div>"
    cat << 'EOF'
      <div class="stat-label">Total Lines</div>
    </div>
    <div class="stat-card covered">
      <div class="stat-icon">✅</div>
EOF
    echo "      <div class=\"stat-value\">${total_hit}</div>"
    cat << 'EOF'
      <div class="stat-label">Lines Covered</div>
    </div>
    <div class="stat-card uncovered">
      <div class="stat-icon">❌</div>
EOF
    echo "      <div class=\"stat-value\">${total_uncovered}</div>"
    cat << 'EOF'
      <div class="stat-label">Lines Uncovered</div>
    </div>
    <div class="stat-card files">
      <div class="stat-icon">📁</div>
EOF
    echo "      <div class=\"stat-value\">${file_count}</div>"
    cat << 'EOF'
      <div class="stat-label">Source Files</div>
    </div>
  </div>
  <main class="main">
    <section class="gauge-section">
      <div class="gauge-container">
        <svg viewBox="0 0 160 160" width="200" height="200">
          <defs>
            <linearGradient id="gaugeGradient" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" style="stop-color:#667eea"/>
              <stop offset="100%" style="stop-color:#764ba2"/>
            </linearGradient>
          </defs>
          <circle class="gauge-bg" cx="80" cy="80" r="70"/>
EOF
    echo "          <circle class=\"gauge-fill\" cx=\"80\" cy=\"80\" r=\"70\" stroke-dasharray=\"440\" stroke-dashoffset=\"${gauge_offset}\"/>"
    cat << 'EOF'
        </svg>
        <div class="gauge-text">
EOF
    echo "          <div class=\"gauge-percent\">${total_pct}%</div>"
    cat << 'EOF'
          <div class="gauge-label">Coverage</div>
        </div>
      </div>
      <div class="gauge-info">
        <h2 class="gauge-title">Overall Code Coverage</h2>
EOF
    echo "        <p class=\"gauge-description\">Your test suite executes <strong>${total_hit} out of ${total_executable}</strong> executable lines across ${file_count} source files. Coverage measures which lines of your source code are executed when running tests, helping identify untested code paths.</p>"
    cat << 'EOF'
        <div class="gauge-breakdown">
          <div class="breakdown-item">
            <span class="breakdown-dot covered"></span>
            <span class="breakdown-label">Covered:</span>
EOF
    echo "            <span class=\"breakdown-value\">${total_hit} lines</span>"
    cat << 'EOF'
          </div>
          <div class="breakdown-item">
            <span class="breakdown-dot uncovered"></span>
            <span class="breakdown-label">Uncovered:</span>
EOF
    echo "            <span class=\"breakdown-value\">${total_uncovered} lines</span>"
    cat << 'EOF'
          </div>
          <div class="breakdown-item">
            <span class="breakdown-dot ignored"></span>
            <span class="breakdown-label">Non-executable:</span>
            <span class="breakdown-value">comments, declarations</span>
          </div>
        </div>
      </div>
    </section>
    <section>
      <div class="section-header">
        <h2 class="section-title">File Coverage Details</h2>
        <div class="legend">
          <div class="legend-item">
            <span class="legend-color high"></span>
EOF
    echo "            <span>≥${BASHUNIT_COVERAGE_THRESHOLD_HIGH:-80}% High</span>"
    cat << 'EOF'
          </div>
          <div class="legend-item">
            <span class="legend-color medium"></span>
EOF
    echo "            <span>${BASHUNIT_COVERAGE_THRESHOLD_LOW:-50}-${BASHUNIT_COVERAGE_THRESHOLD_HIGH:-80}% Medium</span>"
    cat << 'EOF'
          </div>
          <div class="legend-item">
            <span class="legend-color low"></span>
EOF
    echo "            <span>&lt;${BASHUNIT_COVERAGE_THRESHOLD_LOW:-50}% Low</span>"
    cat << 'EOF'
          </div>
        </div>
      </div>
      <div class="files-table">
        <table>
          <thead>
            <tr>
              <th>File</th>
              <th style="text-align: center;">Lines</th>
              <th>Coverage</th>
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

      echo "            <tr>"
      echo "              <td>"
      echo "                <div class=\"file-info\">"
      echo "                  <div class=\"file-icon\">📄</div>"
      echo "                  <div>"
      echo "                    <a href=\"files/${safe_filename}.html\" class=\"file-name\">$(basename "$display_file")</a>"
      echo "                    <div class=\"file-path\">./${display_file}</div>"
      echo "                  </div>"
      echo "                </div>"
      echo "              </td>"
      echo "              <td>"
      echo "                <div class=\"lines-info\">"
      echo "                  <div class=\"lines-covered\">${hit}</div>"
      echo "                  <div class=\"lines-total\">of ${executable} lines</div>"
      echo "                </div>"
      echo "              </td>"
      echo "              <td class=\"coverage-cell\">"
      echo "                <div class=\"coverage-bar-container\">"
      echo "                  <div class=\"coverage-bar\">"
      echo "                    <div class=\"coverage-bar-fill $class\" style=\"width: ${pct}%;\"></div>"
      echo "                  </div>"
      echo "                  <span class=\"coverage-percent $class\">${pct}%</span>"
      echo "                </div>"
      echo "              </td>"
      echo "              <td>"
      echo "                <a href=\"files/${safe_filename}.html\" class=\"view-btn\">View →</a>"
      echo "              </td>"
      echo "            </tr>"
    done

    cat << 'EOF'
          </tbody>
        </table>
      </div>
    </section>
  </main>
  <footer class="footer">
    <div class="footer-content">
      <span class="footer-text">Generated by</span>
      <a href="https://bashunit.typeddevs.com" class="footer-link" target="_blank">bashunit</a>
      <span class="footer-divider"></span>
      <span class="footer-text">Documentation at</span>
      <a href="https://bashunit.typeddevs.com/coverage" class="footer-link" target="_blank">bashunit.typeddevs.com/coverage</a>
    </div>
  </footer>
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
  local uncovered=$((executable - hit))

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

  # Count total lines and functions
  local total_lines
  total_lines=$(wc -l < "$file" | tr -d ' ')
  local non_executable=$((total_lines - executable))

  {
    cat << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
EOF
    echo "  <title>$(basename "$display_file") | Coverage Report</title>"
    cat << 'EOF'
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --primary: #6366f1; --primary-dark: #4f46e5; --primary-light: #818cf8;
      --success: #10b981; --success-bg: rgba(16, 185, 129, 0.15); --success-border: rgba(16, 185, 129, 0.3);
      --warning: #f59e0b;
      --danger: #ef4444; --danger-bg: rgba(239, 68, 68, 0.15); --danger-border: rgba(239, 68, 68, 0.3);
      --bg-dark: #0f172a; --bg-card: #1e293b; --bg-hover: #334155; --bg-code: #0d1117;
      --text-primary: #f8fafc; --text-secondary: #94a3b8; --text-muted: #64748b;
      --border: #334155; --line-number-bg: #161b22;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif; background: var(--bg-dark); color: var(--text-primary); min-height: 100vh; line-height: 1.6; }
    .header { background: var(--bg-card); border-bottom: 1px solid var(--border); padding: 20px 30px; position: sticky; top: 0; z-index: 100; backdrop-filter: blur(10px); }
    .header-content { max-width: 1600px; margin: 0 auto; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 20px; }
    .nav-section { display: flex; align-items: center; gap: 20px; flex-wrap: wrap; }
    .back-btn { display: inline-flex; align-items: center; gap: 8px; padding: 10px 20px; background: var(--bg-hover); border: 1px solid var(--border); border-radius: 8px; color: var(--text-primary); text-decoration: none; font-size: 0.9rem; font-weight: 500; transition: all 0.2s; }
    .back-btn:hover { background: var(--primary); border-color: var(--primary); transform: translateX(-4px); }
    .file-title { display: flex; align-items: center; gap: 12px; }
    .file-icon { width: 40px; height: 40px; background: var(--bg-hover); border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 20px; }
    .file-name { font-size: 1.3rem; font-weight: 700; font-family: 'JetBrains Mono', monospace; }
    .stats-section { display: flex; align-items: center; gap: 30px; flex-wrap: wrap; }
    .stat-item { display: flex; align-items: center; gap: 10px; }
    .stat-badge { padding: 8px 16px; border-radius: 20px; font-weight: 600; font-size: 0.9rem; }
    .stat-badge.coverage.high { background: linear-gradient(135deg, var(--success) 0%, #34d399 100%); color: #000; }
    .stat-badge.coverage.medium { background: linear-gradient(135deg, var(--warning) 0%, #fbbf24 100%); color: #000; }
    .stat-badge.coverage.low { background: linear-gradient(135deg, var(--danger) 0%, #f87171 100%); color: #fff; }
    .stat-badge.lines { background: var(--bg-hover); color: var(--text-primary); }
    .stat-label { color: var(--text-secondary); font-size: 0.85rem; }
    .summary-bar { background: var(--bg-card); border-bottom: 1px solid var(--border); padding: 20px 30px; }
    .summary-content { max-width: 1600px; margin: 0 auto; display: flex; align-items: center; gap: 40px; flex-wrap: wrap; }
    .progress-section { flex: 1; min-width: 300px; }
    .progress-header { display: flex; justify-content: space-between; margin-bottom: 8px; }
    .progress-label { color: var(--text-secondary); font-size: 0.9rem; }
    .progress-percent { font-weight: 700; }
    .progress-percent.high { color: var(--success); }
    .progress-percent.medium { color: var(--warning); }
    .progress-percent.low { color: var(--danger); }
    .progress-bar { height: 12px; background: var(--bg-hover); border-radius: 6px; overflow: hidden; }
    .progress-fill { height: 100%; border-radius: 6px; transition: width 1s ease-out; }
    .progress-fill.high { background: linear-gradient(90deg, var(--success) 0%, #34d399 100%); }
    .progress-fill.medium { background: linear-gradient(90deg, var(--warning) 0%, #fbbf24 100%); }
    .progress-fill.low { background: linear-gradient(90deg, var(--danger) 0%, #f87171 100%); }
    .legend { display: flex; gap: 24px; flex-wrap: wrap; }
    .legend-item { display: flex; align-items: center; gap: 8px; font-size: 0.9rem; color: var(--text-secondary); }
    .legend-color { width: 16px; height: 16px; border-radius: 4px; }
    .legend-color.covered { background: var(--success); }
    .legend-color.uncovered { background: var(--danger); }
    .legend-color.neutral { background: var(--text-muted); }
    .code-container { max-width: 1600px; margin: 30px auto; padding: 0 30px; }
    .code-wrapper { background: var(--bg-code); border-radius: 16px; overflow: hidden; border: 1px solid var(--border); box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3); }
    .code-header { background: var(--line-number-bg); padding: 16px 24px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border); flex-wrap: wrap; gap: 12px; }
    .code-path { font-family: 'JetBrains Mono', monospace; font-size: 0.9rem; color: var(--text-secondary); }
    .code-stats { display: flex; gap: 16px; font-size: 0.85rem; }
    .code-stats span { padding: 4px 12px; background: var(--bg-hover); border-radius: 4px; color: var(--text-secondary); }
    .code-body { overflow-x: auto; }
    .code-table { width: 100%; border-collapse: collapse; font-family: 'JetBrains Mono', monospace; font-size: 13px; line-height: 1.6; }
    .code-table tr { transition: background 0.15s; }
    .code-table tr:hover { background: rgba(255, 255, 255, 0.02); }
    .line-num { width: 60px; padding: 2px 16px; text-align: right; color: var(--text-muted); background: var(--line-number-bg); border-right: 1px solid var(--border); user-select: none; vertical-align: top; }
    .hits { width: 60px; padding: 2px 12px; text-align: center; color: var(--text-muted); background: var(--line-number-bg); border-right: 1px solid var(--border); font-size: 0.85em; vertical-align: top; }
    .hits-badge { display: inline-block; padding: 2px 8px; border-radius: 10px; font-size: 0.8em; font-weight: 600; }
    .covered .hits-badge { background: var(--success-bg); color: var(--success); }
    .uncovered .hits-badge { background: var(--danger-bg); color: var(--danger); }
    .code { padding: 2px 20px; white-space: pre; vertical-align: top; }
    .covered { background: var(--success-bg); }
    .covered .line-num, .covered .hits { background: rgba(16, 185, 129, 0.1); border-color: var(--success-border); }
    .uncovered { background: var(--danger-bg); }
    .uncovered .line-num, .uncovered .hits { background: rgba(239, 68, 68, 0.1); border-color: var(--danger-border); }
    .footer { max-width: 1600px; margin: 0 auto; padding: 40px 30px; text-align: center; }
    .footer-text { color: var(--text-muted); font-size: 0.9rem; }
    .footer-link { color: var(--primary-light); text-decoration: none; font-weight: 500; }
    .footer-link:hover { color: var(--primary); }
    @media (max-width: 768px) {
      .header { padding: 15px 20px; } .header-content { gap: 15px; }
      .stats-section { gap: 15px; } .summary-bar { padding: 15px 20px; }
      .summary-content { gap: 20px; } .code-container { padding: 0 15px; margin: 20px auto; }
      .code-header { padding: 12px 16px; } .line-num, .hits { padding: 2px 8px; }
      .code { padding: 2px 12px; }
    }
  </style>
</head>
<body>
  <header class="header">
    <div class="header-content">
      <div class="nav-section">
        <a href="../index.html" class="back-btn">← Back to Overview</a>
        <div class="file-title">
          <div class="file-icon">📄</div>
EOF
    echo "          <span class=\"file-name\">$(basename "$display_file")</span>"
    cat << 'EOF'
        </div>
      </div>
      <div class="stats-section">
        <div class="stat-item">
EOF
    echo "          <span class=\"stat-badge coverage $class\">${pct}%</span>"
    cat << 'EOF'
          <span class="stat-label">Coverage</span>
        </div>
        <div class="stat-item">
EOF
    echo "          <span class=\"stat-badge lines\">${hit}/${executable}</span>"
    cat << 'EOF'
          <span class="stat-label">Lines</span>
        </div>
      </div>
    </div>
  </header>
  <div class="summary-bar">
    <div class="summary-content">
      <div class="progress-section">
        <div class="progress-header">
          <span class="progress-label">Line Coverage Progress</span>
EOF
    echo "          <span class=\"progress-percent $class\">${pct}%</span>"
    cat << 'EOF'
        </div>
        <div class="progress-bar">
EOF
    echo "          <div class=\"progress-fill $class\" style=\"width: ${pct}%;\"></div>"
    cat << 'EOF'
        </div>
      </div>
      <div class="legend">
        <div class="legend-item">
          <span class="legend-color covered"></span>
EOF
    echo "          <span>${hit} lines covered</span>"
    cat << 'EOF'
        </div>
        <div class="legend-item">
          <span class="legend-color uncovered"></span>
EOF
    echo "          <span>${uncovered} lines uncovered</span>"
    cat << 'EOF'
        </div>
        <div class="legend-item">
          <span class="legend-color neutral"></span>
EOF
    echo "          <span>${non_executable} non-executable</span>"
    cat << 'EOF'
        </div>
      </div>
    </div>
  </div>
  <div class="code-container">
    <div class="code-wrapper">
      <div class="code-header">
EOF
    echo "        <span class=\"code-path\">./${display_file}</span>"
    echo "        <div class=\"code-stats\">"
    echo "          <span>${total_lines} total lines</span>"
    echo "        </div>"
    cat << 'EOF'
      </div>
      <div class="code-body">
        <table class="code-table">
EOF

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
        hits_display="<span class=\"hits-badge\">${hits}×</span>"

        if [[ $hits -gt 0 ]]; then
          row_class="covered"
        else
          row_class="uncovered"
        fi
      fi

      echo "          <tr class=\"$row_class\">"
      echo "            <td class=\"line-num\">$lineno</td>"
      echo "            <td class=\"hits\">$hits_display</td>"
      echo "            <td class=\"code\">$escaped_line</td>"
      echo "          </tr>"
    done < "$file"

    cat << 'EOF'
        </table>
      </div>
    </div>
  </div>
  <footer class="footer">
    <p class="footer-text">
      Generated by <a href="https://bashunit.typeddevs.com" class="footer-link" target="_blank">bashunit</a>
    </p>
  </footer>
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
