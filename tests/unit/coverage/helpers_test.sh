#!/usr/bin/env bash
# shellcheck disable=SC2317

# Save original coverage state to restore after tests
_ORIG_COVERAGE_DATA_FILE=""
_ORIG_COVERAGE_TRACKED_FILES=""
_ORIG_COVERAGE_TRACKED_CACHE_FILE=""
_ORIG_COVERAGE=""
_ORIG_COVERAGE_PATHS=""
_ORIG_COVERAGE_EXCLUDE=""
_ORIG_COVERAGE_REPORT=""
_ORIG_COVERAGE_MIN=""

function set_up() {
  # Save original coverage state
  _ORIG_COVERAGE_DATA_FILE="$_BASHUNIT_COVERAGE_DATA_FILE"
  _ORIG_COVERAGE_TRACKED_FILES="$_BASHUNIT_COVERAGE_TRACKED_FILES"
  _ORIG_COVERAGE_TRACKED_CACHE_FILE="$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
  _ORIG_COVERAGE="${BASHUNIT_COVERAGE:-}"
  _ORIG_COVERAGE_PATHS="${BASHUNIT_COVERAGE_PATHS:-}"
  _ORIG_COVERAGE_EXCLUDE="${BASHUNIT_COVERAGE_EXCLUDE:-}"
  _ORIG_COVERAGE_REPORT="${BASHUNIT_COVERAGE_REPORT:-}"
  _ORIG_COVERAGE_MIN="${BASHUNIT_COVERAGE_MIN:-}"

  # Reset coverage state for testing
  _BASHUNIT_COVERAGE_DATA_FILE=""
  _BASHUNIT_COVERAGE_TRACKED_FILES=""
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE=""
  export BASHUNIT_COVERAGE="false"
  export BASHUNIT_COVERAGE_PATHS="src/"
  export BASHUNIT_COVERAGE_EXCLUDE="tests/*,vendor/*,*_test.sh,*Test.sh"
  export BASHUNIT_COVERAGE_REPORT=""
  export BASHUNIT_COVERAGE_MIN=""
}

function tear_down() {
  # Clean up any coverage temp files created by tests
  if [ -n "$_BASHUNIT_COVERAGE_DATA_FILE" ] &&
    [ "$_BASHUNIT_COVERAGE_DATA_FILE" != "$_ORIG_COVERAGE_DATA_FILE" ]; then
    local coverage_dir
    coverage_dir=$(dirname "$_BASHUNIT_COVERAGE_DATA_FILE")
    rm -rf "$coverage_dir" 2>/dev/null || true
  fi

  # Restore original coverage state
  _BASHUNIT_COVERAGE_DATA_FILE="$_ORIG_COVERAGE_DATA_FILE"
  _BASHUNIT_COVERAGE_TRACKED_FILES="$_ORIG_COVERAGE_TRACKED_FILES"
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE="$_ORIG_COVERAGE_TRACKED_CACHE_FILE"
  if [ -n "$_ORIG_COVERAGE" ]; then
    export BASHUNIT_COVERAGE="$_ORIG_COVERAGE"
  else
    unset BASHUNIT_COVERAGE
  fi
  if [ -n "$_ORIG_COVERAGE_PATHS" ]; then
    export BASHUNIT_COVERAGE_PATHS="$_ORIG_COVERAGE_PATHS"
  else
    unset BASHUNIT_COVERAGE_PATHS
  fi
  if [ -n "$_ORIG_COVERAGE_EXCLUDE" ]; then
    export BASHUNIT_COVERAGE_EXCLUDE="$_ORIG_COVERAGE_EXCLUDE"
  else
    unset BASHUNIT_COVERAGE_EXCLUDE
  fi
  if [ -n "$_ORIG_COVERAGE_REPORT" ]; then
    export BASHUNIT_COVERAGE_REPORT="$_ORIG_COVERAGE_REPORT"
  else
    unset BASHUNIT_COVERAGE_REPORT
  fi
  if [ -n "$_ORIG_COVERAGE_MIN" ]; then
    export BASHUNIT_COVERAGE_MIN="$_ORIG_COVERAGE_MIN"
  else
    unset BASHUNIT_COVERAGE_MIN
  fi
}

# === Coverage class tests ===

function test_coverage_get_coverage_class_returns_high() {
  local result
  export BASHUNIT_COVERAGE_THRESHOLD_HIGH=80
  export BASHUNIT_COVERAGE_THRESHOLD_LOW=50
  result=$(bashunit::coverage::get_coverage_class 85)
  assert_equals "high" "$result"
}

function test_coverage_get_coverage_class_returns_medium() {
  local result
  export BASHUNIT_COVERAGE_THRESHOLD_HIGH=80
  export BASHUNIT_COVERAGE_THRESHOLD_LOW=50
  result=$(bashunit::coverage::get_coverage_class 65)
  assert_equals "medium" "$result"
}

function test_coverage_get_coverage_class_returns_low() {
  local result
  export BASHUNIT_COVERAGE_THRESHOLD_HIGH=80
  export BASHUNIT_COVERAGE_THRESHOLD_LOW=50
  result=$(bashunit::coverage::get_coverage_class 30)
  assert_equals "low" "$result"
}

function test_coverage_get_coverage_class_boundary_high() {
  local result
  export BASHUNIT_COVERAGE_THRESHOLD_HIGH=80
  export BASHUNIT_COVERAGE_THRESHOLD_LOW=50
  result=$(bashunit::coverage::get_coverage_class 80)
  assert_equals "high" "$result"
}

function test_coverage_get_coverage_class_boundary_low() {
  local result
  export BASHUNIT_COVERAGE_THRESHOLD_HIGH=80
  export BASHUNIT_COVERAGE_THRESHOLD_LOW=50
  result=$(bashunit::coverage::get_coverage_class 50)
  assert_equals "medium" "$result"
}

# _BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_HIGH/_LOW (env.sh) are the single source
# of truth for the threshold defaults. When the BASHUNIT_COVERAGE_THRESHOLD_*
# env vars are unset, get_coverage_class must fall back to those same globals
# rather than an independently hardcoded number, so the two never drift apart.
function test_coverage_get_coverage_class_falls_back_to_the_default_high_threshold_when_unset() {
  local result
  unset BASHUNIT_COVERAGE_THRESHOLD_HIGH
  unset BASHUNIT_COVERAGE_THRESHOLD_LOW
  result=$(bashunit::coverage::get_coverage_class "$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_HIGH")
  assert_equals "high" "$result"
}

function test_coverage_get_coverage_class_falls_back_to_the_default_low_threshold_when_unset() {
  local result
  unset BASHUNIT_COVERAGE_THRESHOLD_HIGH
  unset BASHUNIT_COVERAGE_THRESHOLD_LOW
  result=$(bashunit::coverage::get_coverage_class "$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_LOW")
  assert_equals "medium" "$result"
}

# === Percentage calculation tests ===

function test_coverage_calculate_percentage_basic() {
  local result
  result=$(bashunit::coverage::calculate_percentage 5 10)
  assert_equals "50" "$result"
}

function test_coverage_calculate_percentage_full_coverage() {
  local result
  result=$(bashunit::coverage::calculate_percentage 100 100)
  assert_equals "100" "$result"
}

function test_coverage_calculate_percentage_zero_hits() {
  local result
  result=$(bashunit::coverage::calculate_percentage 0 50)
  assert_equals "0" "$result"
}

function test_coverage_calculate_percentage_zero_executable() {
  local result
  result=$(bashunit::coverage::calculate_percentage 0 0)
  assert_equals "0" "$result"
}

# === HTML escape tests ===

function test_coverage_html_escape_ampersand() {
  local result
  result=$(bashunit::coverage::html_escape 'foo & bar')
  assert_equals 'foo &amp; bar' "$result"
}

function test_coverage_html_escape_less_than() {
  local result
  result=$(bashunit::coverage::html_escape 'x < y')
  assert_equals 'x &lt; y' "$result"
}

function test_coverage_html_escape_greater_than() {
  local result
  result=$(bashunit::coverage::html_escape 'x > y')
  assert_equals 'x &gt; y' "$result"
}

function test_coverage_html_escape_combined() {
  local result
  # shellcheck disable=SC2016 # Single quotes intentional - testing literal string escaping
  result=$(bashunit::coverage::html_escape 'if [[ $a < $b && $c > $d ]]; then')
  # shellcheck disable=SC2016
  assert_equals 'if [[ $a &lt; $b &amp;&amp; $c &gt; $d ]]; then' "$result"
}

# === Path to filename tests ===

function test_coverage_path_to_filename_converts_slashes() {
  cd /tmp || return
  local result
  result=$(bashunit::coverage::path_to_filename '/tmp/src/lib/utils.sh')
  assert_equals 'src_lib_utils_sh' "$result"
}

function test_coverage_path_to_filename_handles_dots() {
  cd /tmp || return
  local result
  result=$(bashunit::coverage::path_to_filename '/tmp/test.spec.sh')
  assert_equals 'test_spec_sh' "$result"
}

# === Extract functions tests ===

function test_coverage_extract_functions_finds_basic_function() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
function my_func() {
  echo "hello"
}
EOF

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_contains "my_func" "$result"

  rm -f "$temp_file"
}

function test_coverage_extract_functions_finds_namespaced_function() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
function bashunit::helper::do_thing() {
  echo "hello"
}
EOF

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_contains "bashunit::helper::do_thing" "$result"

  rm -f "$temp_file"
}

function test_coverage_extract_functions_finds_multiple_functions() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
function func_one() {
  echo "one"
}
function func_two() {
  echo "two"
}
EOF

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_contains "func_one" "$result"
  assert_contains "func_two" "$result"

  rm -f "$temp_file"
}

# The span of a function is decided by brace balance, so a nested block inside
# the body must not close it early.
function test_coverage_extract_functions_spans_nested_braces() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'FIXTURE'
#!/usr/bin/env bash
function outer() {
  local map="${x:-fallback}"
  if [ -n "$map" ]; then
    echo "deep"
  fi
}
function after() {
  echo "after"
}
FIXTURE

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_same "outer|2|7
after|8|10" "$result"

  rm -f "$temp_file"
}

# A body that opens and closes on the declaration line is one record whose start
# and end are the same line.
function test_coverage_extract_functions_reports_a_single_line_function() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'FIXTURE'
#!/usr/bin/env bash
function one_liner() { echo "hi"; }
bare_liner() { echo "there"; }
FIXTURE

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_same "one_liner|2|2
bare_liner|3|3" "$result"

  rm -f "$temp_file"
}

# The three declaration spellings bash accepts, plus an indented one: `name()`,
# `function name()` and `function name` with no parentheses at all.
function test_coverage_extract_functions_accepts_every_declaration_spelling() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'FIXTURE'
#!/usr/bin/env bash
bare() {
  echo "a"
}
function keyword() {
  echo "b"
}
function no_parens {
  echo "c"
}
  indented() {
    echo "d"
  }
FIXTURE

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_same "bare|2|4
keyword|5|7
no_parens|8|10
indented|11|13" "$result"

  rm -f "$temp_file"
}

# An unbalanced file still reports the function, ending at the last line, so a
# truncated or generated file cannot drop a record silently.
function test_coverage_extract_functions_closes_an_unclosed_function_at_eof() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'FIXTURE'
#!/usr/bin/env bash
function unclosed() {
  echo "no closing brace"
FIXTURE

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_same "unclosed|2|3" "$result"

  rm -f "$temp_file"
}

# A name is only a name inside [a-zA-Z0-9_:] and starting with a letter or `_`,
# and the declaration must continue with `()` or `{` -- a call is not a
# definition.
function test_coverage_extract_functions_rejects_non_declarations() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'FIXTURE'
#!/usr/bin/env bash
9lives() {
  echo "starts with a digit"
}
call_me arg
real_fn() {
  echo "yes"
}
FIXTURE

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_same "real_fn|6|8" "$result"

  rm -f "$temp_file"
}

# A function ends where its braces balance, so a brace that is not code at all
# must not count. One stray `{` in a comment or a string used to keep the
# function open and swallow every later declaration in the file: 11 functions
# in src/coverage/lines.sh collapsed into 1 (#1086).
function test_coverage_extract_functions_ignores_a_brace_in_a_comment() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'FIXTURE'
#!/usr/bin/env bash
function first() {
  # a stray { in a comment
  echo "one"
}
function second() {
  echo "two"
}
FIXTURE

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_same "first|2|5
second|6|8" "$result"

  rm -f "$temp_file"
}

function test_coverage_extract_functions_ignores_a_brace_in_a_string() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'FIXTURE'
#!/usr/bin/env bash
function first() {
  local open="{"
  local close='}'
  echo "$open$close"
}
function second() {
  echo "two"
}
FIXTURE

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_same "first|2|6
second|7|9" "$result"

  rm -f "$temp_file"
}

# An embedded awk program is a single-quoted string spanning many lines. Its
# `END {` was read as a declaration of a function called END, and its braces
# were counted as if they belonged to the enclosing file.
function test_coverage_extract_functions_ignores_a_multi_line_quoted_program() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'FIXTURE'
#!/usr/bin/env bash
PROGRAM='
{ print "{" }
END { print "}" }
'
function after_program() {
  echo "after"
}
FIXTURE

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_same "after_program|6|8" "$result"

  rm -f "$temp_file"
}

# A heredoc body is data, not code: neither its braces nor a line that looks
# like a declaration belong to the file being scanned.
function test_coverage_extract_functions_skips_a_heredoc_body() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'FIXTURE'
#!/usr/bin/env bash
function emits() {
  cat <<'BODY'
function not_a_function() {
BODY
  echo "done"
}
function after_heredoc() {
  echo "after"
}
FIXTURE

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_same "emits|2|7
after_heredoc|8|10" "$result"

  rm -f "$temp_file"
}

# `<<<` is a here-string, not a heredoc: it has no body to skip, so scanning
# must not swallow the rest of the file waiting for a terminator.
function test_coverage_extract_functions_treats_a_here_string_as_one_line() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'FIXTURE'
#!/usr/bin/env bash
function reads() {
  local item
  while IFS= read -r item; do
    echo "$item"
  done <<<"$list"
}
function after_here_string() {
  echo "after"
}
FIXTURE

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_same "reads|2|7
after_here_string|8|10" "$result"

  rm -f "$temp_file"
}

# Bash itself is the oracle: under `extdebug`, `declare -F` reports the real
# start line of every function it sourced. Extraction has to agree with it on a
# file holding all of the shapes above. extdebug is enabled inside the
# subshell only -- in the caller it clobbers state the runner depends on (#808).
function test_coverage_extract_functions_agrees_with_bash_on_the_hard_shapes() {
  local temp_file
  temp_file="$(bashunit::temp_file extract_oracle).sh"
  cat >"$temp_file" <<'FIXTURE'
#!/usr/bin/env bash
PROGRAM='
{ print "{" }
END { print "}" }
'
function first() {
  # a stray { in a comment
  local brace="{"
  echo "$brace"
}
function second() {
  cat <<'BODY'
function not_a_function() {
BODY
  echo "done"
}
third() { echo "one line"; }
function fourth() {
  local closing
  closing=$(printf '%s' "}")
  echo "$closing"
}
FIXTURE

  local oracle
  oracle=$(
    shopt -s extdebug
    # shellcheck source=/dev/null
    source "$temp_file"
    local fn
    for fn in first second third fourth; do
      declare -F "$fn"
    done | awk '{ print $1 "|" $2 }'
  )

  local extracted
  extracted=$(bashunit::coverage::extract_functions "$temp_file" | awk -F'|' '{ print $1 "|" $2 }')

  assert_same "$oracle" "$extracted"
}

# === Line hits tests ===

function test_coverage_get_all_line_hits_counts_per_line() {
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  local test_file
  test_file="$(bashunit::temp_file coverage_line_hits).sh"
  printf 'echo one\necho two\necho three\necho four\necho five\n' >"$test_file"
  {
    echo "${test_file}:5"
    echo "${test_file}:5"
    echo "${test_file}:5"
  } >>"$_BASHUNIT_COVERAGE_DATA_FILE"

  local result
  result=$(bashunit::coverage::get_all_line_hits "$test_file")

  rm -f "$test_file"

  assert_equals "5:3" "$result"
}

# A variable assignment is not a function definition. extract_functions cut the
# candidate name at the first space, `(` or `{`, so in `VAR="x${Y}"` the `{` of
# the expansion ended the name and the remaining `{Y}"` looked like a function
# body opener. Every such assignment became a phantom FN record, corrupting
# FNF/FNH in the LCOV report (#936).
function test_coverage_extract_functions_ignores_assignment_with_expansion() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'FIXTURE'
#!/usr/bin/env bash
URL="https://${host}/api"
PATH_="$HOME/${sub}"
function real_fn() {
  echo "hello"
}
FIXTURE

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_not_contains "URL" "$result"
  assert_not_contains "PATH_" "$result"
  assert_contains "real_fn" "$result"

  rm -f "$temp_file"
}

# Same misdetection, but the value also contains the `|` used as the record
# separator, so the emitted record gained a fourth field. report_lcov reads it
# with `IFS='|' read -r fn_name fn_start fn_end`, landing a literal `$` in
# fn_start and aborting its `for ((...))` with a bash arithmetic error (#936).
function test_coverage_extract_functions_ignores_assignment_containing_a_pipe() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'FIXTURE'
#!/usr/bin/env bash
PS4_LIKE="x|${LINENO}"
function real_fn() {
  echo "hello"
}
FIXTURE

  local result
  result=$(bashunit::coverage::extract_functions "$temp_file")

  assert_not_contains "PS4_LIKE" "$result"
  assert_contains "real_fn" "$result"

  rm -f "$temp_file"
}

# Every emitted record must be exactly name|start|end, so a malformed one can
# never reach the arithmetic in report_lcov.
function test_coverage_extract_functions_emits_three_fields_per_record() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'FIXTURE'
#!/usr/bin/env bash
PS4_LIKE="x|${LINENO}"
function real_fn() { echo "hi"; }
function bashunit::ns::other() {
  echo "there"
}
FIXTURE

  local malformed
  malformed=$(bashunit::coverage::extract_functions "$temp_file" |
    awk -F'|' 'NF != 3 || $2 !~ /^[0-9]+$/ || $3 !~ /^[0-9]+$/')

  assert_empty "$malformed"

  rm -f "$temp_file"
}
