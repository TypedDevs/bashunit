#!/usr/bin/env bash

# precompute_file_stats fills the cache every renderer reads, and get_file_stats
# computes one file on demand. They must agree exactly: the cache is what the
# report shows, and a file the cache missed falls through to the on-demand path
# mid-report. This pins the two together so the batch path cannot drift (#1088).

function set_up() {
  WORK="$(bashunit::temp_dir)/precompute"
  mkdir -p "$WORK"
  # The tracked list collapses a doubled slash and the hit blocks are named
  # after the recorded path, so the fixture has to record the same spelling the
  # tracked list holds -- `/tmp//bashunit` would key its blocks differently and
  # read back as zero hits.
  local slash="/"
  WORK="${WORK//\/\//$slash}"

  # Plain: three executable lines, one comment, one blank.
  printf 'function plain() {\n  local a=1\n\n  # note\n  echo "$a"\n}\n' >"$WORK/plain.sh"
  # A statement continued over two lines: the hit on the first must carry to
  # the second, which is the rule the batch pass has to reproduce (#722).
  printf 'function cont() {\n  echo "one" \\\n    "two"\n  echo "three"\n}\n' >"$WORK/cont.sh"
  # Never executed at all.
  printf 'function cold() {\n  echo "never"\n}\n' >"$WORK/cold.sh"

  # The paths have to be in place before init: it is what decides the tracked
  # set the report is about.
  # shellcheck disable=SC2034  # read by coverage::init and the seeding
  BASHUNIT_COVERAGE_PATHS="$WORK"
  # shellcheck disable=SC2034  # read by coverage::init and the seeding
  BASHUNIT_COVERAGE_EXCLUDE=""
  # shellcheck disable=SC2034  # read by coverage::init
  BASHUNIT_COVERAGE="true"
  bashunit::coverage::init

  {
    echo "$WORK/plain.sh:2"
    echo "$WORK/plain.sh:2"
    echo "$WORK/plain.sh:5"
    echo "$WORK/cont.sh:2"
  } >>"$_BASHUNIT_COVERAGE_DATA_FILE"
  bashunit::coverage::invalidate_hits_aggregation
}

function test_the_batch_pass_matches_the_per_file_path_for_every_file() {
  bashunit::coverage::precompute_file_stats

  local file
  for file in "$WORK/plain.sh" "$WORK/cont.sh" "$WORK/cold.sh"; do
    assert_same "$(bashunit::coverage::get_file_stats "$file")" \
      "$(bashunit::coverage::get_cached_stats "$file")"
  done
}

function test_the_batch_pass_carries_a_hit_across_a_line_continuation() {
  bashunit::coverage::precompute_file_stats

  # `echo "one" \` runs and its continuation counts as run with it, so 2 of the
  # 3 executable lines are hit -- the trailing `echo "three"` never ran.
  assert_same "3:2:66:medium" "$(bashunit::coverage::get_cached_stats "$WORK/cont.sh")"
}

function test_a_file_no_test_executed_counts_with_zero_hits() {
  bashunit::coverage::precompute_file_stats

  assert_same "1:0:0:low" "$(bashunit::coverage::get_cached_stats "$WORK/cold.sh")"
}

function test_the_total_percentage_covers_every_tracked_file() {
  bashunit::coverage::precompute_file_stats

  # plain 2 executable / 2 hit, cont 3/2, cold 1/0 -> 4 of 6.
  assert_same "66" "$(bashunit::coverage::get_percentage)"
}
