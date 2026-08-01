#!/usr/bin/env bash

# Locating function definitions and their line spans, for the reports.

# Extract function definitions from a bash file
# Output format: function_name:start_line:end_line (one per function)
function bashunit::coverage::extract_functions() {
  local file="$1"

  local lineno=0
  local in_function=0
  local brace_count=0
  local current_fn=""
  local fn_start=0
  local line

  while IFS= read -r line || [ -n "$line" ]; do
    ((++lineno))

    # Check for function definition patterns
    # Pattern 1: function name() { or function name {
    # Pattern 2: name() { or name () {
    if [ "$in_function" -eq 0 ]; then
      local fn_name=""

      # Extract function name using pure Bash string operations (avoids sed subshell)
      local stripped="${line#"${line%%[![:space:]]*}"}"

      # Strip "function " prefix if present
      case "$stripped" in
      function[\ \	]*)
        stripped="${stripped#function}"
        stripped="${stripped#"${stripped%%[![:space:]]*}"}"
        ;;
      esac

      # Extract first word as candidate function name
      fn_name="${stripped%%[[:space:]\(\{]*}"

      # Validate: must BE an identifier, and rest must have () or {
      if [ -n "$fn_name" ]; then
        case "$fn_name" in
        # A candidate holding anything outside the identifier alphabet is not a
        # function name. Cutting at the first `{` means `VAR="x${Y}"` yields
        # `VAR="x$`, whose trailing `{Y}"` then looks like a body opener — every
        # such assignment became a phantom FN record, and one containing the
        # record separator `|` shifted the fields and crashed report_lcov's
        # arithmetic (#936). Checking only the first character let all of that
        # through.
        *[!a-zA-Z0-9_:]*) fn_name="" ;;
        [a-zA-Z_]*)
          local after_name="${stripped#"$fn_name"}"
          after_name="${after_name#"${after_name%%[![:space:]]*}"}"
          case "$after_name" in
          '()'* | '{'*) ;;
          *) fn_name="" ;;
          esac
          ;;
        *) fn_name="" ;;
        esac
      fi

      if [ -n "$fn_name" ]; then
        in_function=1
        current_fn="$fn_name"
        fn_start=$lineno
        brace_count=0

        # Count opening braces on this line
        local open_braces="${line//[^\{]/}"
        local close_braces="${line//[^\}]/}"
        local open_count=${#open_braces}
        local close_count=${#close_braces}
        brace_count=$((brace_count + open_count - close_count))

        # Single-line function: braces balance on same line and both present
        if [ "$brace_count" -eq 0 ] && [ "$open_count" -gt 0 ] && [ "$close_count" -gt 0 ]; then
          echo "${current_fn}|${fn_start}|${lineno}"
          in_function=0
          current_fn=""
        fi
        continue
      fi
    fi

    # Track braces inside function
    if [ "$in_function" -eq 1 ]; then
      local open_braces="${line//[^\{]/}"
      local close_braces="${line//[^\}]/}"
      brace_count=$((brace_count + ${#open_braces} - ${#close_braces}))

      # Function ended
      if [ "$brace_count" -le 0 ]; then
        echo "${current_fn}|${fn_start}|${lineno}"
        in_function=0
        current_fn=""
        brace_count=0
      fi
    fi
  done <"$file"

  # Handle unclosed function (shouldn't happen in valid code)
  if [ "$in_function" -eq 1 ] && [ -n "$current_fn" ]; then
    echo "${current_fn}|${fn_start}|${lineno}"
  fi
}
