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

# Runs the mirrored awk propagation against an explicit raw hit list.
function awk_hits_for() { # $1 = source file, $@ = line numbers to record
  local src="$1"
  shift
  env LC_ALL=C "$AWK" -v raw_hits="$*" "$(bashunit::coverage::awk_rules)"'
    BEGIN {
      n = split(raw_hits, raw, " ")
      for (i = 1; i <= n; i++) { if (raw[i] != "") { hits[raw[i]]++ } }
    }
    { total++; source[total] = $0 }
    END {
      bu_propagate(source, hits, total)
      for (ln = 1; ln <= total; ln++) {
        if ((ln in hits) && hits[ln] > 0) { print ln ":" hits[ln] }
      }
    }
  ' "$src"
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

function stack_for_file() { # $1 = source file
  local line
  bashunit::coverage::scan_reset
  while IFS= read -r line || [ -n "$line" ]; do
    bashunit::coverage::scan_line "$line"
  done <"$1"
  printf '%s' "$_BASHUNIT_COVERAGE_SCAN_STACK"
}

function awk_stack_for_file() { # $1 = source file
  env LC_ALL=C "$AWK" "$(bashunit::coverage::awk_rules)"'
      BEGIN { bu_scan_reset() }
      { bu_scan_line($0) }
      END { printf "%s", bu_scan_stack() }
    ' "$1"
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

function test_a_quote_around_a_command_substitution_does_not_open_a_span() {
  assert_same "00000" "$(open_flags 'x="$(' '  if false; then' '    echo skipped' '  fi' ')"')"
}

function test_an_array_around_a_substitution_does_not_cover_its_commands() {
  assert_same "1000010" "$(open_flags 'x=(' '$(' 'if false; then' 'echo skipped' 'fi' ')' ')')"
}

function test_a_literal_inside_a_quoted_substitution_still_opens_a_span() {
  assert_same "011100" "$(open_flags 'x="$(' '  value=(' '    "one"' '    "two"' '  )' ')"')"
}

function test_a_process_substitution_inside_an_array_is_not_a_span() {
  assert_same "10010" "$(open_flags 'x=(' '  <(' '    compute' '  )' ')')"
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

function test_a_backslash_in_a_trailing_comment_does_not_continue_the_statement() {
  assert_same "00" "$(open_flags 'echo ran # comment \' 'echo skipped')"
}

function test_arithmetic_shifts_do_not_start_a_heredoc() {
  assert_same "00000" "$(open_flags 'x=$((1 << 2))' 'x="$((1 << 2))"' '((x = (1 << 2)))' 'echo done' '')"
  assert_same "00" "$(open_flags 'x=$((1 <<(2 << 1)))' 'echo done')"
}

function test_an_arithmetic_expansion_balances() {
  assert_same "0" "$(open_flags 'count=$((count + 1))')"
}

function test_a_case_arm_does_not_unbalance_the_stack() {
  assert_same "000" "$(open_flags 'case "$x" in' '  --flag) run ;;' 'esac')"
}

function test_a_case_arm_inside_a_quoted_substitution_does_not_close_it() {
  assert_same "000000000" "$(open_flags 'result="$(' '  case "$value" in' '    x)' \
    '      if false; then' '        echo skipped' '      fi' '      ;;' '  esac' ')"')"
}

function test_a_nested_case_after_an_arm_delimiter_keeps_both_cases_open() {
  assert_same "000000000000" "$(open_flags 'result="$(' '  case x in' \
    '    x) case y in' '      y) : ;;' '    esac ;;' '    z)' \
    '      if false; then' '        echo skipped' '      fi' '      ;;' \
    '  esac' ')"')"
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

function test_a_quoted_command_substitution_does_not_cover_skipped_commands() {
  local src="$WORK/quoted_cmdsub.sh"
  printf '%s\n' 'x="$(' '  if false; then' '    echo skipped' '  fi' ')"' >"$src"

  assert_same "$(printf '%s\n' '1:1' '5:1')" "$(hits_for "$src" 1)"
}

function test_an_array_command_substitution_does_not_cover_skipped_commands() {
  local src="$WORK/array_cmdsub.sh"
  printf '%s\n' 'x=(' '  $(' '    if false; then' '      echo skipped' '    fi' '  )' ')' >"$src"

  assert_same "$(printf '%s\n' '1:1' '2:1' '6:1' '7:1')" "$(hits_for "$src" 1)"
}

function test_an_outer_opening_hit_crosses_a_substitution_without_covering_its_child() {
  local src="$WORK/outer_open.sh"
  printf '%s\n' 'values=(' '  first' '  "$(' '    printf nested' '  )"' '  last' ')' >"$src"

  local expected
  expected="$(printf '%s\n' '1:1' '2:1' '3:1' '5:1' '6:1' '7:1')"
  assert_same "$expected" "$(hits_for "$src" 1)"
  assert_same "$expected" "$(awk_hits_for "$src" 1)"
}

function test_an_outer_closing_hit_crosses_a_substitution_without_covering_its_child() {
  local src="$WORK/outer_close.sh"
  printf '%s\n' 'values=(' '  first' '  "$(' '    printf nested' '  )"' '  last' ')' >"$src"

  local expected
  expected="$(printf '%s\n' '1:1' '2:1' '3:1' '5:1' '6:1' '7:1')"
  assert_same "$expected" "$(hits_for "$src" 7)"
  assert_same "$expected" "$(awk_hits_for "$src" 7)"
}

function test_a_child_hit_does_not_escape_to_its_outer_literal() {
  local src="$WORK/outer_child.sh"
  printf '%s\n' 'values=(' '  first' '  "$(' '    printf nested' '  )"' '  last' ')' >"$src"

  assert_same '4:1' "$(hits_for "$src" 4)"
  assert_same '4:1' "$(awk_hits_for "$src" 4)"
}

function test_a_case_arm_does_not_expose_the_outer_quote_to_a_skipped_command() {
  local src="$WORK/case_arm.sh"
  printf '%s\n' 'result="$(' '  case "$value" in' '    x)' '      if false; then' \
    '        echo skipped' '      fi' '      ;;' '  esac' ')"' >"$src"

  assert_same '4:1' "$(hits_for "$src" 4)"
  assert_same '4:1' "$(awk_hits_for "$src" 4)"
  assert_empty "$(stack_for_file "$src")"
  assert_empty "$(awk_stack_for_file "$src")"
}

function test_a_nested_case_does_not_expose_the_outer_quote_to_a_skipped_command() {
  local src="$WORK/nested_case.sh"
  printf '%s\n' 'result="$(' '  case x in' '    x) case y in' '      y) : ;;' \
    '    esac ;;' '    z)' '      if false; then' '        echo skipped' \
    '      fi' '      ;;' '  esac' ')"' >"$src"

  assert_same '7:1' "$(hits_for "$src" 7)"
  assert_same '7:1' "$(awk_hits_for "$src" 7)"
  assert_empty "$(stack_for_file "$src")"
  assert_empty "$(awk_stack_for_file "$src")"
}

function test_a_continued_command_crosses_a_substitution_without_covering_its_child() {
  local src="$WORK/continued_substitution.sh"
  printf '%s\n' 'printf "%s\n" \' '  "$(' '    printf nested' '  )" \' \
    '  last' >"$src"

  local expected
  expected="$(printf '%s\n' '1:1' '2:1' '4:1' '5:1')"
  assert_same "$expected" "$(hits_for "$src" 1)"
  assert_same "$expected" "$(awk_hits_for "$src" 1)"
}

function test_a_child_continuation_ends_when_its_substitution_closes() {
  local src="$WORK/child_continuation.sh"
  printf '%s\n' 'result="$(' '  printf ran \' ')"' 'result="$(' \
    '  if false; then' '    echo skipped' '  fi' ')"' >"$src"

  local expected
  expected="$(printf '%s\n' '2:1' '3:1')"
  assert_same "$expected" "$(hits_for "$src" 2)"
  assert_same "$expected" "$(awk_hits_for "$src" 2)"
}

function test_a_heredoc_clears_its_leading_continuation() {
  local src="$WORK/heredoc_continuation.sh"
  printf '%s\n' 'return 0 <<EOF \' 'payload' 'EOF' 'echo unreachable' >"$src"

  local expected
  expected="$(printf '%s\n' '1:1' '2:1' '3:1')"
  assert_same "$expected" "$(hits_for "$src" 1)"
  assert_same "$expected" "$(awk_hits_for "$src" 1)"
}

function test_case_pattern_named_case_keeps_skipped_commands_isolated() {
  local src="$WORK/case_pattern_named_case.sh"
  printf '%s\n' 'result="$(' '  case case in' '    case)' \
    '      if false; then' '        echo skipped' '      fi' '      ;;' \
    '  esac' ')"' >"$src"

  assert_same '4:1' "$(hits_for "$src" 4)"
  assert_same '4:1' "$(awk_hits_for "$src" 4)"
  assert_empty "$(stack_for_file "$src")"
  assert_empty "$(awk_stack_for_file "$src")"
}

function test_optional_case_pattern_keeps_nested_case_commands_isolated() {
  local src="$WORK/optional_nested_case.sh"
  printf '%s\n' 'result="$(' '  case x in' '    (x) case y in' \
    '      y) : ;;' '    esac ;;' '    z)' '      if false; then' \
    '        echo skipped' '      fi' '      ;;' '  esac' ')"' >"$src"

  assert_same '7:1' "$(hits_for "$src" 7)"
  assert_same '7:1' "$(awk_hits_for "$src" 7)"
  assert_empty "$(stack_for_file "$src")"
  assert_empty "$(awk_stack_for_file "$src")"
}

function test_case_subject_named_in_keeps_compact_nested_commands_isolated() {
  local src="$WORK/compact_optional_nested_case.sh"
  printf '%s\n' 'result="$(' '  case in in (x) case y in' '    y) : ;;' \
    '  esac ;;' '  z)' '    if false; then' '      echo skipped' '    fi' \
    '    ;;' '  esac' ')"' >"$src"

  assert_same '6:1' "$(hits_for "$src" 6)"
  assert_same '6:1' "$(awk_hits_for "$src" 6)"
  assert_empty "$(stack_for_file "$src")"
  assert_empty "$(awk_stack_for_file "$src")"
}

function test_case_pattern_alternative_named_esac_stays_in_the_pattern() {
  local src="$WORK/case_pattern_esac_alternative.sh"
  printf '%s\n' 'result="$(' '  case z in' '    foo|esac)' \
    '      if false; then' '        echo skipped' '      fi' '      ;;' \
    '  esac' ')"' >"$src"

  assert_same '4:1' "$(hits_for "$src" 4)"
  assert_same '4:1' "$(awk_hits_for "$src" 4)"
  assert_empty "$(stack_for_file "$src")"
  assert_empty "$(awk_stack_for_file "$src")"
}

function test_conditional_case_commands_keep_later_commands_isolated() {
  local keyword branch end src
  for keyword in if while until; do
    if [ "$keyword" = 'if' ]; then
      branch='then'
      end='fi'
    else
      branch='do'
      end='done'
    fi
    src="$WORK/${keyword}_case.sh"
    printf '%s\n' 'result="$(' "  $keyword case x in" '    x) false ;;' \
      '  esac' "  $branch" '    :' "  $end" '  if false; then' \
      '    echo skipped' '  fi' ')"' >"$src"

    assert_same '3:1' "$(hits_for "$src" 3)"
    assert_same '3:1' "$(awk_hits_for "$src" 3)"
    assert_empty "$(stack_for_file "$src")"
    assert_empty "$(awk_stack_for_file "$src")"
  done
}

function test_arithmetic_case_variable_does_not_hide_a_following_array_span() {
  local src="$WORK/arithmetic_case_variable.sh"
  printf '%s\n' 'value=$((' '  case' '  + 1' '))' 'items=(' '  one' ')' >"$src"

  local expected
  expected="$(printf '%s\n' '5:1' '6:1' '7:1')"
  assert_same "$expected" "$(hits_for "$src" 7)"
  assert_same "$expected" "$(awk_hits_for "$src" 7)"
  assert_empty "$(stack_for_file "$src")"
  assert_empty "$(awk_stack_for_file "$src")"
}

function test_an_arithmetic_shift_does_not_swallow_a_later_array_span() {
  local src="$WORK/shift.sh"
  printf '%s\n' 'x=$((1 << 2))' 'items=(' '  one' '  two' ')' >"$src"

  assert_same "$(printf '%s\n' '2:1' '3:1' '4:1' '5:1')" "$(hits_for "$src" 5)"
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
