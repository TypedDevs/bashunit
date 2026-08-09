#!/usr/bin/env bash
# shellcheck disable=SC2155

function set_up() {
  export BASHUNIT_SIMPLE_OUTPUT=false
  unset BASHUNIT_SNAPSHOT_PLACEHOLDER
}

function test_successful_assert_match_snapshot() {
  assert_empty "$(assert_match_snapshot "Hello World!")"
}

function test_creates_a_snapshot() {
  local snapshot_path="$(bashunit::temp_dir)/assert_snapshot_test_sh.test_creates_a_snapshot.snapshot"
  local expected=$((_BASHUNIT_ASSERTIONS_SNAPSHOT + 1))

  assert_file_not_exists "$snapshot_path"
  assert_match_snapshot "Expected snapshot" "$snapshot_path"

  assert_same "$expected" "$_BASHUNIT_ASSERTIONS_SNAPSHOT"
  assert_file_exists "$snapshot_path"
  assert_same "Expected snapshot" "$(cat "$snapshot_path")"
}

function test_unsuccessful_assert_match_snapshot() {
  local actual
  actual="$(assert_match_snapshot "Expected snapshot")" || true

  assert_matches "Unsuccessful assert match snapshot" "$actual"
  assert_matches "Expected to match the snapshot" "$actual"
  assert_contains "snapshot_test_sh.test_unsuccessful_assert_match_snapshot.snapshot" "$actual"
  assert_contains "--snapshot-update" "$actual"
}

function test_successful_assert_match_snapshot_ignore_colors() {
  local colored
  colored=$(printf '\e[31mHello\e[0m World!')
  assert_empty "$(assert_match_snapshot_ignore_colors "$colored")"
}

function test_creates_a_snapshot_ignore_colors() {
  local snapshot_path
  snapshot_path="$(bashunit::temp_dir)/assert_snapshot_test_sh.test_creates_a_snapshot_ignore_colors.snapshot"
  local expected=$((_BASHUNIT_ASSERTIONS_SNAPSHOT + 1))

  assert_file_not_exists "$snapshot_path"
  local colored
  colored=$(printf '\e[32mExpected\e[0m snapshot')
  assert_match_snapshot_ignore_colors "$colored" "$snapshot_path"

  assert_same "$expected" "$_BASHUNIT_ASSERTIONS_SNAPSHOT"
  assert_file_exists "$snapshot_path"
  assert_same "Expected snapshot" "$(cat "$snapshot_path")"
}

function test_unsuccessful_assert_match_snapshot_ignore_colors() {
  local colored actual
  colored=$(printf '\e[31mExpected snapshot\e[0m')
  actual="$(assert_match_snapshot_ignore_colors "$colored")" || true

  assert_matches "Unsuccessful assert match snapshot ignore colors" "$actual"
  assert_matches "Expected to match the snapshot" "$actual"
  assert_contains \
    "snapshot_test_sh.test_unsuccessful_assert_match_snapshot_ignore_colors.snapshot" "$actual"
  assert_contains "--snapshot-update" "$actual"
}

function test_assert_match_snapshot_strips_carriage_returns_from_actual() {
  local snapshot_path
  snapshot_path="$(bashunit::temp_dir)/assert_snapshot_test_sh.test_strips_cr_actual.snapshot"
  printf 'Line1\nLine2\n' >"$snapshot_path"

  # ANSI-C quoting (Bash 3.0 safe; printf -v is 3.1+) keeps the raw \r bytes
  local actual=$'Line1\r\nLine2\r\n'
  assert_empty "$(assert_match_snapshot "$actual" "$snapshot_path")"
}

function test_assert_match_snapshot_matches_snapshot_file_with_crlf_endings() {
  local snapshot_path
  snapshot_path="$(bashunit::temp_dir)/assert_snapshot_test_sh.test_snapshot_crlf.snapshot"
  printf 'Line1\r\nLine2\r\n' >"$snapshot_path"

  assert_empty "$(assert_match_snapshot "$(printf 'Line1\nLine2')" "$snapshot_path")"
}

function test_assert_match_snapshot_strips_trailing_newlines_from_actual() {
  local snapshot_path
  snapshot_path="$(bashunit::temp_dir)/assert_snapshot_test_sh.test_trailing_newlines.snapshot"
  printf 'Line1\nLine2\n' >"$snapshot_path"

  local actual=$'Line1\nLine2\n\n\n'
  assert_empty "$(assert_match_snapshot "$actual" "$snapshot_path")"
}

function test_assert_match_snapshot_ignore_colors_matches_plain_input() {
  local snapshot_path
  snapshot_path="$(bashunit::temp_dir)/assert_snapshot_test_sh.test_ignore_colors_plain.snapshot"
  printf 'Plain text\n' >"$snapshot_path"

  assert_empty "$(assert_match_snapshot_ignore_colors "Plain text" "$snapshot_path")"
}

function test_assert_match_snapshot_ignore_colors_strips_ansi_and_cr() {
  local snapshot_path
  snapshot_path="$(bashunit::temp_dir)/assert_snapshot_test_sh.test_ignore_colors_ansi.snapshot"
  printf 'Colored line\n' >"$snapshot_path"

  local colored=$'\e[31mColored\e[0m line\r'
  assert_empty "$(assert_match_snapshot_ignore_colors "$colored" "$snapshot_path")"
}

function test_assert_match_snapshot_with_placeholder() {
  if ! bashunit::dependencies::has_perl; then
    bashunit::skip "perl not available" && return
  fi

  local snapshot_path
  snapshot_path="$(bashunit::temp_dir)/assert_snapshot_test_sh.test_assert_match_snapshot_with_placeholder.snapshot"
  echo 'Run at ::ignore::' >"$snapshot_path"

  assert_empty "$(assert_match_snapshot "Run at $(date -u '+%F %T UTC')" "$snapshot_path")"
}

function test_assert_snapshot_with_custom_placeholder() {
  if ! bashunit::dependencies::has_perl; then
    bashunit::skip "perl not available" && return
  fi

  local snapshot_path
  snapshot_path="$(bashunit::temp_dir)/assert_snapshot_test_sh.test_assert_snapshot_with_custom_placeholder.snapshot"
  echo 'Value __ANY__' >"$snapshot_path"

  export BASHUNIT_SNAPSHOT_PLACEHOLDER='__ANY__'
  assert_empty "$(assert_match_snapshot "Value 42" "$snapshot_path")"
}

# --- internals ---------------------------------------------------------------

function test_snapshot_compare_bypasses_placeholder_matcher_for_literal_match() {
  local snapshot_path
  snapshot_path="$(bashunit::temp_dir)/literal-match.snapshot"
  printf 'plain snapshot\n' >"$snapshot_path"

  # Invoked indirectly by snapshot::compare.
  # shellcheck disable=SC2329
  function bashunit::snapshot::match_with_placeholder() { return 1; }

  bashunit::snapshot::compare "plain snapshot" "$snapshot_path" "test_literal_match"
}

function test_snapshot_compare_bypasses_placeholder_matcher_for_literal_mismatch() {
  local snapshot_path
  snapshot_path="$(bashunit::temp_dir)/literal-mismatch.snapshot"
  printf 'expected\n' >"$snapshot_path"

  # Must not be invoked by snapshot::compare.
  # shellcheck disable=SC2329
  function bashunit::snapshot::match_with_placeholder() { return 0; }

  local output status=0
  output="$(bashunit::snapshot::compare \
    "actual" "$snapshot_path" "test_literal_mismatch")" || status=$?

  assert_same 1 "$status"
  assert_contains "Expected to match the snapshot" "$output"
}

function test_snapshot_compare_uses_placeholder_matcher_when_marker_is_present() {
  local snapshot_path
  snapshot_path="$(bashunit::temp_dir)/placeholder-match.snapshot"
  printf 'expected ::ignore::\n' >"$snapshot_path"

  # Invoked indirectly by snapshot::compare.
  # shellcheck disable=SC2329
  function bashunit::snapshot::match_with_placeholder() { return 0; }

  bashunit::snapshot::compare "different fixed text" "$snapshot_path" "test_placeholder_match"
}

function test_snapshot_compare_routes_a_custom_placeholder_to_the_matcher() {
  local snapshot_path
  snapshot_path="$(bashunit::temp_dir)/custom-placeholder-match.snapshot"
  printf 'value <<ANY>>\n' >"$snapshot_path"

  BASHUNIT_SNAPSHOT_PLACEHOLDER="<<ANY>>" \
    bashunit::snapshot::compare "value 42" "$snapshot_path" "test_custom_placeholder"
}

function test_snapshot_normalize_actual_strips_cr_and_trailing_newlines() {
  local _snapshot_normalized
  bashunit::snapshot::normalize_actual $'line1\r\nline2\r\n\n\n'

  assert_same $'line1\nline2' "$_snapshot_normalized"
}

function test_snapshot_normalize_actual_keeps_inner_blank_lines() {
  local _snapshot_normalized
  bashunit::snapshot::normalize_actual $'a\n\nb\n'

  assert_same $'a\n\nb' "$_snapshot_normalized"
}

function test_snapshot_placeholder_matches_variable_middle() {
  local snapshot=$'Version: ::ignore:: (stable)'
  local actual=$'Version: 1.2.3-rc4 (stable)'

  assert_successful_code "$(
    bashunit::snapshot::match_with_placeholder "$actual" "$snapshot"
    echo $?
  )"
  bashunit::snapshot::match_with_placeholder "$actual" "$snapshot"
}

function test_snapshot_placeholder_spans_multiple_lines() {
  # Only the perl matcher can span lines; the grep fallback (e.g. Alpine
  # without perl) matches line-by-line and documents that limitation.
  if ! command -v perl >/dev/null 2>&1; then
    bashunit::skip "multi-line placeholders need perl" && return
  fi

  local snapshot=$'start\n::ignore::\nend'
  local actual=$'start\nanything\nat all\nend'

  bashunit::snapshot::match_with_placeholder "$actual" "$snapshot"
  assert_successful_code $?
}

function test_snapshot_placeholder_rejects_nonmatching_fixed_text() {
  local snapshot=$'Version: ::ignore:: (stable)'
  local actual=$'Release: 1.2.3 (stable)'

  local status=0
  bashunit::snapshot::match_with_placeholder "$actual" "$snapshot" || status=$?
  assert_same 1 "$status"
}

function test_snapshot_placeholder_escapes_regex_metacharacters() {
  # Literal regex chars in the snapshot must match themselves, not act as regex.
  local snapshot=$'value: [a-z]+ ::ignore::'
  local actual_literal=$'value: [a-z]+ tail'
  local actual_regexy=$'value: abc tail'

  bashunit::snapshot::match_with_placeholder "$actual_literal" "$snapshot"
  assert_successful_code $?

  local status=0
  bashunit::snapshot::match_with_placeholder "$actual_regexy" "$snapshot" || status=$?
  assert_same 1 "$status"
}

function test_snapshot_placeholder_honours_custom_placeholder() {
  local snapshot=$'id=<<ANY>> done'
  local actual=$'id=12345 done'

  BASHUNIT_SNAPSHOT_PLACEHOLDER="<<ANY>>" \
    bashunit::snapshot::match_with_placeholder "$actual" "$snapshot"
  assert_successful_code $?
}

function test_snapshot_resolve_file_uses_explicit_hint_verbatim() {
  bashunit::snapshot::resolve_file "/tmp/custom.snapshot" "test_whatever"

  assert_same "/tmp/custom.snapshot" "$_BASHUNIT_SNAPSHOT_FILE_OUT"
}

# resolve_file used to prefix "./" unconditionally, so an absolute test path
# became "./" + "/abs/dir" -- a path relative to the *current* directory. The
# real snapshot was never read and a stray one was recorded under the caller's
# cwd, so every snapshot assertion in that run passed while comparing nothing.
function test_resolve_file_keeps_an_absolute_directory_absolute() {
  bashunit::snapshot::resolve_file "" "test_example" "" "/abs/dir/my_test.sh"

  assert_same "/abs/dir/snapshots/my_test_sh.test_example.snapshot" \
    "$_BASHUNIT_SNAPSHOT_FILE_OUT"
}

function test_resolve_file_keeps_a_relative_directory_relative() {
  bashunit::snapshot::resolve_file "" "test_example" "" "tests/unit/my_test.sh"

  assert_same "./tests/unit/snapshots/my_test_sh.test_example.snapshot" \
    "$_BASHUNIT_SNAPSHOT_FILE_OUT"
}

# A path with no slash yields dir_part "." and therefore a doubled "./". That is
# the shape this function has always produced and the comment above it says so
# deliberately; it resolves identically, so it is pinned rather than tidied.
function test_resolve_file_handles_a_slashless_path() {
  bashunit::snapshot::resolve_file "" "test_example" "" "my_test.sh"

  assert_same "././snapshots/my_test_sh.test_example.snapshot" \
    "$_BASHUNIT_SNAPSHOT_FILE_OUT"
}

function test_resolve_file_includes_the_snapshot_name_when_given() {
  bashunit::snapshot::resolve_file "" "test_example" "stderr" "tests/my_test.sh"

  assert_same "./tests/snapshots/my_test_sh.test_example.stderr.snapshot" \
    "$_BASHUNIT_SNAPSHOT_FILE_OUT"
}

# The placeholder marks a region of the snapshot the author chose not to pin.
# These cover the whole surface, and deliberately include the negative cases:
# a placeholder must not turn the assertion into one that always passes.
function snapshot_with() { # $1 snapshot content -> prints the path
  local path="$(bashunit::temp_dir)/placeholder.snapshot"
  printf '%s' "$1" >"$path"
  printf '%s' "$path"
}

function test_placeholder_matches_a_varying_region_mid_line() {
  assert_empty "$(assert_match_snapshot "a123b" "$(snapshot_with 'a::ignore::b')")"
}

function test_placeholder_matches_at_the_start_and_end() {
  assert_empty "$(assert_match_snapshot "anythingtail" "$(snapshot_with '::ignore::tail')")"
  assert_empty "$(assert_match_snapshot "headanything" "$(snapshot_with 'head::ignore::')")"
}

function test_placeholder_matches_an_empty_region() {
  assert_empty "$(assert_match_snapshot "ab" "$(snapshot_with 'a::ignore::b')")"
}

function test_several_placeholders_in_one_snapshot() {
  assert_empty "$(assert_match_snapshot "a=1 b=2" "$(snapshot_with 'a=::ignore:: b=::ignore::')")"
}

function test_a_lone_placeholder_matches_any_value() {
  assert_empty "$(assert_match_snapshot "literally anything" "$(snapshot_with '::ignore::')")"
}

function test_placeholder_spans_multiple_lines() {
  local snapshot actual
  snapshot=$(snapshot_with "$(printf 'A\n::ignore::\nZ')")
  actual=$(printf 'A\nq\nw\nZ')

  assert_empty "$(assert_match_snapshot "$actual" "$snapshot")"
}

# The important half. Without these a placeholder could silently become
# "match anything" and the assertion would report success while comparing
# nothing -- which is exactly what the pre-awk fallback did for the multi-line
# case.
function test_placeholder_still_requires_the_surrounding_text() {
  assert_not_empty "$(assert_match_snapshot "XXX" "$(snapshot_with 'a::ignore::b')")"
}

function test_placeholder_rejects_a_differing_suffix() {
  assert_not_empty "$(assert_match_snapshot "aXXXc" "$(snapshot_with 'a::ignore::b')")"
}

function test_multi_line_placeholder_rejects_unrelated_output() {
  local snapshot
  snapshot=$(snapshot_with "$(printf 'A\n::ignore::\nZ')")

  assert_not_empty "$(assert_match_snapshot "NOPE" "$snapshot")"
}

# Regex metacharacters in the snapshot are literal text, not pattern syntax.
function test_regex_metacharacters_around_a_placeholder_are_literal() {
  local snapshot
  snapshot=$(snapshot_with 'cost $5.00 (x) ::ignore::')

  assert_empty "$(assert_match_snapshot 'cost $5.00 (x) Z' "$snapshot")"
  assert_not_empty "$(assert_match_snapshot 'cost 999 (x) Z' "$snapshot")"
}
