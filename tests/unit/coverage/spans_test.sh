#!/usr/bin/env bash

# shellcheck disable=SC1003 # intentional literal trailing backslashes in test inputs

# Multi-line statement spans (#1338).
#
# #722 taught the report that a backslash chain is one statement. A statement
# that spans lines because a quote, an array literal or a heredoc is still open
# is the same shape, and the DEBUG trap attributes it to one line of the span --
# which line depends on the Bash version: 3.2 reports an array assignment on its
# closing `)`, 5.x on its opening line. So the propagation has to cover the whole
# span from a hit anywhere inside it.

function set_up() {
  WORK="$(bashunit::temp_dir)/spans"
  mkdir -p "$WORK"
  _BASHUNIT_COVERAGE_DATA_FILE="$WORK/coverage.data"
  : >"$_BASHUNIT_COVERAGE_DATA_FILE"
  bashunit::coverage::invalidate_hits_aggregation
}

function tear_down() {
  _BASHUNIT_COVERAGE_DATA_FILE=""
  bashunit::coverage::invalidate_hits_aggregation
}

# Records one hit per "<line>" argument and returns the propagated hit list.
function hits_for() { # $1 = source file, $@ = line numbers to record
  local src="$1"
  shift
  local ln
  for ln in "$@"; do
    echo "${src}:${ln}" >>"$_BASHUNIT_COVERAGE_DATA_FILE"
  done
  bashunit::coverage::invalidate_hits_aggregation
  bashunit::coverage::get_all_line_hits "$src"
}

# --- the scanner -------------------------------------------------------------

# Runs the scanner over the given lines and reports the open flag of each, so a
# state machine bug points at the line that broke it.
function open_flags() { # $@ = source lines
  local line out=""
  bashunit::coverage::scan_reset
  for line in "$@"; do
    bashunit::coverage::scan_line "$line"
    if bashunit::coverage::scan_is_open; then
      out="${out}1"
    else
      out="${out}0"
    fi
  done
  printf '%s' "$out"
}

function test_an_array_literal_stays_open_until_its_closing_paren() {
  assert_same "1110" "$(open_flags 'local commands=(' '  "start"' '  "stop"' ')')"
}

function test_a_single_line_array_literal_opens_nothing() {
  assert_same "0" "$(open_flags 'local commands=("start" "stop")')"
}

function test_a_command_substitution_is_not_a_span() {
  assert_same "00" "$(open_flags 'x=$(' ')')"
}

function test_a_subshell_is_not_a_span() {
  assert_same "00" "$(open_flags '(' ')')"
}

function test_a_process_substitution_is_not_a_span() {
  assert_same "0" "$(open_flags 'while read -r l; do :; done < <(printf x)')"
}

function test_a_multi_line_single_quoted_string_stays_open() {
  assert_same "110" "$(open_flags "x='{" '  "a": 1' "}'")"
}

function test_a_multi_line_double_quoted_string_stays_open() {
  assert_same "10" "$(open_flags 'x="one' 'two"')"
}

function test_a_quote_inside_a_comment_opens_nothing() {
  assert_same "0" "$(open_flags "# it's a comment")"
}

function test_a_trailing_comment_does_not_swallow_a_quote() {
  assert_same "0" "$(open_flags "echo hi  # don't")"
}

function test_a_hash_in_a_parameter_expansion_is_not_a_comment() {
  assert_same "0" "$(open_flags 'echo "${#arr[@]}" "${x#pre}"')"
}

function test_a_quote_inside_a_command_substitution_inside_a_string() {
  # "$(f 'a"b')" -- the inner double quote belongs to the single-quoted word of
  # the substituted command, not to the outer string.
  assert_same "0" "$(open_flags 'y="$(f '"'"'a"b'"'"')"')"
}

function test_an_escaped_quote_does_not_open_a_string() {
  assert_same "0" "$(open_flags 'echo \" done')"
}

function test_a_heredoc_body_stays_open_until_its_terminator() {
  assert_same "1110" "$(open_flags 'cat <<EOF' 'a' 'b' 'EOF')"
}

function test_a_quoted_heredoc_delimiter_is_recognised() {
  assert_same "110" "$(open_flags "cat <<'EOF'" "it's fine" 'EOF')"
}

function test_a_here_string_is_not_a_heredoc() {
  assert_same "0" "$(open_flags 'read -r x <<<"value"')"
}

function test_a_backslash_continuation_is_open() {
  assert_same "10" "$(open_flags 'printf %s \' '  value')"
}

function test_an_arithmetic_expansion_balances() {
  assert_same "0" "$(open_flags 'count=$((count + 1))')"
}

function test_a_case_arm_does_not_unbalance_the_stack() {
  assert_same "000" "$(open_flags 'case "$x" in' '  --flag) run ;;' 'esac')"
}

# --- span propagation --------------------------------------------------------

function test_an_array_hit_on_the_closing_paren_covers_the_whole_span() {
  # What Bash 3.2 records: the assignment is attributed to the `)` line.
  local src="$WORK/array_close.sh"
  printf '%s\n' 'local commands=(' '  "start"' '  "stop"' ')' 'echo done' >"$src"

  assert_same "$(printf '%s\n' '1:1' '2:1' '3:1' '4:1')" "$(hits_for "$src" 4)"
}

function test_an_array_hit_on_the_opening_line_covers_the_whole_span() {
  # What Bash 5.x records: the assignment is attributed to its first line.
  local src="$WORK/array_open.sh"
  printf '%s\n' 'local commands=(' '  "start"' '  "stop"' ')' 'echo done' >"$src"

  assert_same "$(printf '%s\n' '1:1' '2:1' '3:1' '4:1')" "$(hits_for "$src" 1)"
}

function test_a_multi_line_string_hit_covers_its_interior() {
  local src="$WORK/string.sh"
  printf '%s\n' "printf '%s' '{" '  "index": "spend"' "}'" 'echo done' >"$src"

  assert_same "$(printf '%s\n' '1:1' '2:1' '3:1')" "$(hits_for "$src" 1)"
}

function test_a_heredoc_hit_covers_its_body() {
  local src="$WORK/heredoc.sh"
  printf '%s\n' 'cat <<EOF' 'one' 'two' 'EOF' 'echo done' >"$src"

  assert_same "$(printf '%s\n' '1:1' '2:1' '3:1' '4:1')" "$(hits_for "$src" 1)"
}

function test_a_multi_line_command_substitution_is_left_alone() {
  # Its interior lines are real commands: they get their own DEBUG hits, so
  # crediting them from the opening line would report lines that never ran.
  local src="$WORK/cmdsub.sh"
  printf '%s\n' 'x=$(' '  compute_a' '  compute_b' ')' >"$src"

  assert_same "1:1" "$(hits_for "$src" 1)"
}

function test_a_span_that_never_ran_stays_uncovered() {
  local src="$WORK/cold.sh"
  printf '%s\n' 'local commands=(' '  "start"' ')' 'echo done' >"$src"

  assert_same "4:1" "$(hits_for "$src" 4)"
}

function test_the_highest_count_in_a_span_wins() {
  local src="$WORK/counts.sh"
  printf '%s\n' 'local commands=(' '  "start"' ')' >"$src"

  assert_same "$(printf '%s\n' '1:3' '2:3' '3:3')" "$(hits_for "$src" 3 3 3)"
}

# #722 stays exactly as it was: a chain propagates, an unrelated line does not.
function test_a_backslash_chain_still_propagates() {
  local src="$WORK/chain.sh"
  printf '%s\n' 'echo start \' '  middle \' '  end' 'echo other' >"$src"

  assert_same "$(printf '%s\n' '1:2' '2:2' '3:2' '4:1')" "$(hits_for "$src" 1 1 4)"
}
