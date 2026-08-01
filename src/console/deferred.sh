#!/usr/bin/env bash

# End-of-run blocks buffered during the run and flushed once it finishes.

function bashunit::console_results::print_failing_tests_and_reset() {
  if [ -s "$FAILURES_OUTPUT_PATH" ]; then
    local total_failed
    total_failed=$(bashunit::state::get_tests_failed)

    if bashunit::env::is_simple_output_enabled; then
      printf "\n\n"
    fi

    if [ "$total_failed" -eq 1 ]; then
      echo -e "${_BASHUNIT_COLOR_BOLD}There was 1 failure:${_BASHUNIT_COLOR_DEFAULT}\n"
    else
      echo -e "${_BASHUNIT_COLOR_BOLD}There were $total_failed failures:${_BASHUNIT_COLOR_DEFAULT}\n"
    fi

    sed '${/^$/d;}' "$FAILURES_OUTPUT_PATH" | sed 's/^/|/'
    rm "$FAILURES_OUTPUT_PATH"

    echo ""
  fi
}


##
# Prints the slowest tests recorded during the run, sorted by duration
# descending, limited to BASHUNIT_PROFILE_COUNT entries. Reads the
# tab-separated records appended to PROFILE_OUTPUT_PATH (duration, name, file).
##
function bashunit::console_results::print_profile_and_reset() {
  if [ ! -s "$PROFILE_OUTPUT_PATH" ]; then
    rm -f "$PROFILE_OUTPUT_PATH"
    return
  fi

  local count="${BASHUNIT_PROFILE_COUNT:-10}"

  echo -e "\n${_BASHUNIT_COLOR_BOLD}Slowest tests:${_BASHUNIT_COLOR_DEFAULT}"

  local duration name file formatted
  # -rn on the first (numeric) field; head limits to the requested count.
  while IFS=$'\t' read -r duration name file; do
    formatted=$(bashunit::console_results::format_duration "$duration")
    printf "  %s\t%s (%s)\n" "$formatted" "$name" "$file"
  done < <(sort -t"$(printf '\t')" -k1 -rn "$PROFILE_OUTPUT_PATH" | head -n "$count")

  echo ""

  rm -f "$PROFILE_OUTPUT_PATH"
}


##
# Flushes a deferred summary block (skipped/incomplete/risky): prints the
# "There was 1 <noun>" / "There were N <nouns>" header, then the recorded lines
# from output_path (carriage returns stripped, blank lines dropped, each prefixed
# with "|"), removes the file and prints a trailing blank line. Callers own the
# `[ -s path ]` (and any `is_show_*`) guard so each block keeps its own gate.
# Arguments: $1 output path, $2 total count, $3 singular noun, $4 plural noun
##
function bashunit::console_results::flush_deferred_block() {
  local output_path=$1
  local total=$2
  local singular=$3
  local plural=$4

  if bashunit::env::is_simple_output_enabled; then
    printf "\n"
  fi

  if [ "$total" -eq 1 ]; then
    echo -e "${_BASHUNIT_COLOR_BOLD}There was 1 ${singular}:${_BASHUNIT_COLOR_DEFAULT}\n"
  else
    echo -e "${_BASHUNIT_COLOR_BOLD}There were ${total} ${plural}:${_BASHUNIT_COLOR_DEFAULT}\n"
  fi

  tr -d '\r' <"$output_path" | sed '/^[[:space:]]*$/d' | sed 's/^/|/'
  rm "$output_path"

  echo ""
}


function bashunit::console_results::print_skipped_tests_and_reset() {
  if [ -s "$SKIPPED_OUTPUT_PATH" ] && bashunit::env::is_show_skipped_enabled; then
    bashunit::console_results::flush_deferred_block "$SKIPPED_OUTPUT_PATH" \
      "$(bashunit::state::get_tests_skipped)" "skipped test" "skipped tests"
  fi
}


function bashunit::console_results::print_incomplete_tests_and_reset() {
  if [ -s "$INCOMPLETE_OUTPUT_PATH" ] && bashunit::env::is_show_incomplete_enabled; then
    bashunit::console_results::flush_deferred_block "$INCOMPLETE_OUTPUT_PATH" \
      "$(bashunit::state::get_tests_incomplete)" "incomplete test" "incomplete tests"
  fi
}


function bashunit::console_results::print_risky_tests_and_reset() {
  if [ -s "$RISKY_OUTPUT_PATH" ]; then
    bashunit::console_results::flush_deferred_block "$RISKY_OUTPUT_PATH" \
      "$(bashunit::state::get_tests_risky)" "risky test" "risky tests"
  fi
}

