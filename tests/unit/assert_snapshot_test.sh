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
