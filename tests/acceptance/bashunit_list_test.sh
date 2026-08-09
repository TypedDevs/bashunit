#!/usr/bin/env bash
set -euo pipefail

# `--list` / `--dry-run` answer "which tests would run" without running them.
# Every selection mechanism (--filter, --tag, --shard, --random-order, ...) is
# otherwise only observable by executing the suite (#1007).
#
# The fixtures deliberately do not end in *test.sh — anything that does under
# tests/ is picked up by the real suite — so every run below passes explicit
# file paths rather than the fixture directory.

FIXTURES_PATH="./tests/acceptance/fixtures/list"
ALPHA="$FIXTURES_PATH/alpha.sh"
BETA="$FIXTURES_PATH/beta.sh"
TAGGED="$FIXTURES_PATH/tagged.sh"

function test_list_prints_every_test_as_file_and_function() {
  local output
  output="$(./bashunit --list "$ALPHA" 2>/dev/null)"

  assert_same "\
$ALPHA::test_alpha_one
$ALPHA::test_alpha_two" "$output"
}

function test_list_exits_zero() {
  ./bashunit --list "$ALPHA" >/dev/null 2>&1

  assert_successful_code $?
}

function test_list_reports_the_count_on_stderr() {
  local stderr
  stderr="$(./bashunit --list "$ALPHA" 2>&1 >/dev/null)"

  assert_same "2 tests" "$stderr"
}

# A query, not a run: an empty selection is not an error the way "No tests
# found" is for a real run.
function test_list_exits_zero_and_prints_nothing_for_an_empty_selection() {
  local output
  output="$(./bashunit --list --filter "no_such_test_anywhere" "$ALPHA" "$BETA" 2>/dev/null)"

  assert_empty "$output"
}

function test_an_empty_selection_still_exits_zero() {
  local exit_code=0
  ./bashunit --list --filter "no_such_test_anywhere" "$ALPHA" >/dev/null 2>&1 || exit_code=$?

  assert_equals 0 "$exit_code"
}

function test_dry_run_is_an_alias_of_list() {
  local listed dry
  listed="$(./bashunit --list "$ALPHA" 2>/dev/null)"
  dry="$(./bashunit --dry-run "$ALPHA" 2>/dev/null)"

  # Without this both sides are empty when the flag is unknown, and the
  # comparison passes while proving nothing.
  assert_not_empty "$dry"
  assert_same "$listed" "$dry"
}

function test_list_respects_the_filter() {
  local output
  output="$(./bashunit --list --filter "alpha_two" "$ALPHA" "$BETA" 2>/dev/null)"

  assert_same "$ALPHA::test_alpha_two" "$output"
}

function test_list_respects_tag_filtering() {
  local output
  output="$(./bashunit --list --tag slow "$TAGGED" 2>/dev/null)"

  assert_same "$TAGGED::test_tagged_slow" "$output"
}

function test_list_respects_exclude_tag_filtering() {
  local output
  output="$(./bashunit --list --exclude-tag slow "$TAGGED" 2>/dev/null)"

  assert_same "$TAGGED::test_tagged_fast" "$output"
}

# Sharding is the case the issue called out: checking balance used to need one
# full run per shard.
function test_list_shards_cover_every_test_exactly_once() {
  local all shard1 shard2 combined
  all="$(./bashunit --list "$ALPHA" "$BETA" 2>/dev/null | sort)"
  shard1="$(./bashunit --list --shard 1/2 "$ALPHA" "$BETA" 2>/dev/null)"
  shard2="$(./bashunit --list --shard 2/2 "$ALPHA" "$BETA" 2>/dev/null)"
  combined="$(printf '%s\n%s\n' "$shard1" "$shard2" | grep -v '^$' | sort)"

  # Two empty sides also compare equal; require the union to be the real suite.
  assert_not_empty "$all"
  assert_same "$all" "$combined"
}

# The ordering a seed produces must be the ordering that seed actually runs,
# or --list cannot reproduce a random-order failure.
function test_list_matches_the_execution_order_for_a_seed() {
  local listed executed expected fn
  listed="$(./bashunit --list --random-order --seed 42 "$ALPHA" "$BETA" 2>/dev/null | sed 's|.*::||')"
  executed="$(./bashunit --no-parallel --random-order --seed 42 "$ALPHA" "$BETA" 2>/dev/null |
    sed 's/\x1b\[[0-9;]*m//g' | grep -oE '^. Passed: .*' | sed 's/^. Passed: //' | sed 's/ *$//')"

  # Compare through the same normaliser the result lines are rendered with, so
  # this pins the ORDER rather than re-encoding how a name is humanised.
  expected=""
  for fn in $listed; do
    expected="$expected$(bashunit::helper::normalize_test_function_name "$fn")
"
  done

  assert_not_empty "$listed"
  assert_same "$(printf '%s' "$expected")" "$executed"
}

function test_list_runs_no_test_body_and_no_script_hook() {
  local marker="$FIXTURES_PATH/.marker"
  rm -f "$marker"

  local output
  output="$(./bashunit --list "$FIXTURES_PATH/side_effect.sh" 2>/dev/null)"

  # The listing must have actually happened, or "no marker" only means the
  # command failed before reaching the fixture.
  assert_same "$FIXTURES_PATH/side_effect.sh::test_writes_a_marker" "$output"
  assert_file_not_exists "$marker"
}

function test_list_writes_no_report_file() {
  local dir report output
  dir="$(bashunit::temp_dir)"
  report="$dir/report.tap"

  output="$(./bashunit --list --report-tap "$report" "$ALPHA" 2>/dev/null)"

  assert_not_empty "$output"
  assert_file_not_exists "$report"
}

function test_list_format_json_emits_valid_json_with_the_documented_fields() {
  if ! command -v jq >/dev/null 2>&1; then
    bashunit::skip "jq is required to validate the JSON shape" && return
  fi

  local output
  output="$(./bashunit --list --list-format json "$ALPHA" 2>/dev/null)"

  assert_same "2" "$(printf '%s' "$output" | jq -r '.count')"
  assert_same "$ALPHA" "$(printf '%s' "$output" | jq -r '.tests[0].file')"
  assert_same "test_alpha_one" "$(printf '%s' "$output" | jq -r '.tests[0].function')"
  assert_same "Alpha one" "$(printf '%s' "$output" | jq -r '.tests[0].name')"
  assert_not_empty "$(printf '%s' "$output" | jq -r '.tests[0].line')"
}

function test_list_format_json_reports_tags() {
  if ! command -v jq >/dev/null 2>&1; then
    bashunit::skip "jq is required to validate the JSON shape" && return
  fi

  local output
  output="$(./bashunit --list --list-format json --tag slow "$TAGGED" 2>/dev/null)"

  assert_same "slow" "$(printf '%s' "$output" | jq -r '.tests[0].tags[0]')"
}

function test_list_format_json_is_valid_for_an_empty_selection() {
  if ! command -v jq >/dev/null 2>&1; then
    bashunit::skip "jq is required to validate the JSON shape" && return
  fi

  local output
  output="$(./bashunit --list --list-format json --filter "no_such_test" "$ALPHA" 2>/dev/null)"

  assert_same "0" "$(printf '%s' "$output" | jq -r '.count')"
  assert_same "0" "$(printf '%s' "$output" | jq -r '.tests | length')"
}

function test_an_unsupported_list_format_is_rejected() {
  local output
  output="$(./bashunit --list --list-format yaml "$ALPHA" 2>&1)" || true

  assert_contains "yaml" "$output"
}

function test_an_unsupported_list_format_exits_non_zero() {
  local exit_code=0
  ./bashunit --list --list-format yaml "$ALPHA" >/dev/null 2>&1 || exit_code=$?

  # Paired with the supported-value case: an unknown *flag* would also exit 1,
  # so on its own this proves nothing.
  local ok_code=0
  ./bashunit --list --list-format text "$ALPHA" >/dev/null 2>&1 || ok_code=$?

  assert_equals 1 "$exit_code"
  assert_equals 0 "$ok_code"
}

# A data provider expands to N executions but is one test function; listing it
# once keeps the output a stable identifier list.
function test_a_data_provider_test_is_listed_once() {
  local output
  output="$(./bashunit --list "$FIXTURES_PATH/provider.sh" 2>/dev/null)"

  assert_same "$FIXTURES_PATH/provider.sh::test_provided" "$output"
}
