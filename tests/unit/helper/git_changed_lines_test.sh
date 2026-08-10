#!/usr/bin/env bash

# Changed-line extraction behind --coverage-diff (#1032). Mirrors the three
# sources git_changed_files merges (commit range, working tree, untracked), but
# reports line numbers rather than paths.

function _lines_repo() {
  local repo
  repo="$(bashunit::temp_dir changed_lines_repo)"
  (
    cd "$repo" || exit 1
    git init -q
    git symbolic-ref HEAD refs/heads/main
    git config user.email "test@bashunit.dev"
    git config user.name "bashunit test"
    git config commit.gpgsign false
    printf 'one\ntwo\nthree\nfour\nfive\n' >lib.sh
    git add .
    git commit -q -m "initial"
    git branch base
  ) >/dev/null 2>&1
  echo "$repo"
}

function test_changed_lines_reports_a_modified_line() {
  local repo
  repo="$(_lines_repo)"
  printf 'one\nTWO\nthree\nfour\nfive\n' >"$repo/lib.sh"

  assert_same "2" "$(cd "$repo" && bashunit::helper::git_changed_lines base lib.sh)"
}

function test_changed_lines_reports_a_contiguous_block() {
  local repo
  repo="$(_lines_repo)"
  printf 'one\nTWO\nTHREE\nfour\nfive\n' >"$repo/lib.sh"

  assert_same "\
2
3" "$(cd "$repo" && bashunit::helper::git_changed_lines base lib.sh)"
}

function test_changed_lines_reports_added_lines_at_the_end() {
  local repo
  repo="$(_lines_repo)"
  printf 'one\ntwo\nthree\nfour\nfive\nsix\n' >"$repo/lib.sh"

  assert_same "6" "$(cd "$repo" && bashunit::helper::git_changed_lines base lib.sh)"
}

# A pure deletion has no added lines, so there is nothing to hold coverage
# against — the hunk header reads "+N,0".
function test_changed_lines_ignores_a_pure_deletion() {
  local repo
  repo="$(_lines_repo)"
  printf 'one\nthree\nfour\nfive\n' >"$repo/lib.sh"

  assert_empty "$(cd "$repo" && bashunit::helper::git_changed_lines base lib.sh)"
}

function test_changed_lines_covers_a_committed_change() {
  local repo
  repo="$(_lines_repo)"
  (
    cd "$repo" || exit 1
    printf 'one\ntwo\nthree\nFOUR\nfive\n' >lib.sh
    git commit -q -am "change four"
  ) >/dev/null 2>&1

  assert_same "4" "$(cd "$repo" && bashunit::helper::git_changed_lines base lib.sh)"
}

# A brand-new file is entirely new, so every line counts as changed.
function test_changed_lines_treats_an_untracked_file_as_fully_changed() {
  local repo
  repo="$(_lines_repo)"
  printf 'alpha\nbeta\n' >"$repo/new.sh"

  assert_same "\
1
2" "$(cd "$repo" && bashunit::helper::git_changed_lines base new.sh)"
}

function test_changed_lines_is_empty_for_an_untouched_file() {
  local repo
  repo="$(_lines_repo)"

  assert_empty "$(cd "$repo" && bashunit::helper::git_changed_lines base lib.sh)"
}

function test_changed_lines_deduplicates_across_sources() {
  local repo
  repo="$(_lines_repo)"
  (
    cd "$repo" || exit 1
    printf 'one\nTWO\nthree\nfour\nfive\n' >lib.sh
    git commit -q -am "change two"
  ) >/dev/null 2>&1
  # Same line touched again, now uncommitted: it must be reported once.
  printf 'one\nTWO_AGAIN\nthree\nfour\nfive\n' >"$repo/lib.sh"

  assert_same "2" "$(cd "$repo" && bashunit::helper::git_changed_lines base lib.sh)"
}
