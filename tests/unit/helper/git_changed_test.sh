#!/usr/bin/env bash

# Builds a throwaway repo with two committed test files and a `base` branch on
# that first commit, so a diff against `base` has something to report. A branch
# rather than a tag: a global tag.forceSignAnnotated or tag.annotate makes a
# bare `git tag` abort with "no tag message?" on the contributor's machine.
# The default branch is set explicitly because init.defaultBranch varies across
# the git versions CI runs.
function _changed_repo() {
  local repo
  repo="$(bashunit::temp_dir changed_repo)"
  (
    cd "$repo" || exit 1
    git init -q
    git symbolic-ref HEAD refs/heads/main
    git config user.email "test@bashunit.dev"
    git config user.name "bashunit test"
    git config commit.gpgsign false
    printf 'function test_base() { :; }\n' >base_test.sh
    printf 'function test_other() { :; }\n' >other_test.sh
    git add .
    git commit -q -m "initial"
    git branch base
  ) >/dev/null 2>&1
  echo "$repo"
}

function test_git_changed_files_lists_a_file_committed_after_the_ref() {
  local repo
  repo="$(_changed_repo)"
  (
    cd "$repo" || exit 1
    printf 'function test_base() { :; }\nfunction test_extra() { :; }\n' >base_test.sh
    git commit -q -am "touch base"
  ) >/dev/null 2>&1

  assert_same "base_test.sh" "$(cd "$repo" && bashunit::helper::git_changed_files base)"
}

function test_git_changed_files_includes_an_uncommitted_modification() {
  local repo
  repo="$(_changed_repo)"
  printf 'function test_base() { :; }\nfunction test_dirty() { :; }\n' >"$repo/base_test.sh"

  assert_same "base_test.sh" "$(cd "$repo" && bashunit::helper::git_changed_files base)"
}

function test_git_changed_files_includes_a_staged_modification() {
  local repo
  repo="$(_changed_repo)"
  (
    cd "$repo" || exit 1
    printf 'function test_base() { :; }\nfunction test_staged() { :; }\n' >base_test.sh
    git add base_test.sh
  ) >/dev/null 2>&1

  assert_same "base_test.sh" "$(cd "$repo" && bashunit::helper::git_changed_files base)"
}

function test_git_changed_files_includes_an_untracked_file() {
  local repo
  repo="$(_changed_repo)"
  printf 'function test_new() { :; }\n' >"$repo/new_test.sh"

  assert_same "new_test.sh" "$(cd "$repo" && bashunit::helper::git_changed_files base)"
}

function test_git_changed_files_excludes_a_deleted_file() {
  local repo
  repo="$(_changed_repo)"
  (
    cd "$repo" || exit 1
    git rm -q other_test.sh
    git commit -q -m "drop other"
  ) >/dev/null 2>&1

  assert_same "" "$(cd "$repo" && bashunit::helper::git_changed_files base)"
}

function test_git_changed_files_reports_only_the_new_path_of_a_rename() {
  local repo
  repo="$(_changed_repo)"
  (
    cd "$repo" || exit 1
    git mv other_test.sh renamed_test.sh
    git commit -q -m "rename other"
  ) >/dev/null 2>&1

  assert_same "renamed_test.sh" "$(cd "$repo" && bashunit::helper::git_changed_files base)"
}

function test_git_changed_files_is_empty_when_nothing_changed() {
  local repo
  repo="$(_changed_repo)"

  assert_same "" "$(cd "$repo" && bashunit::helper::git_changed_files base)"
}

function test_git_filter_changed_keeps_only_the_changed_candidates() {
  local repo
  repo="$(_changed_repo)"
  printf 'function test_base() { :; }\nfunction test_dirty() { :; }\n' >"$repo/base_test.sh"

  assert_same "./base_test.sh" \
    "$(cd "$repo" && bashunit::helper::git_filter_changed base ./base_test.sh ./other_test.sh)"
}

function test_git_filter_changed_keeps_the_caller_path_spelling() {
  local repo
  repo="$(_changed_repo)"
  printf 'function test_base() { :; }\nfunction test_dirty() { :; }\n' >"$repo/base_test.sh"

  assert_same "base_test.sh" \
    "$(cd "$repo" && bashunit::helper::git_filter_changed base base_test.sh other_test.sh)"
}

function test_git_filter_changed_is_empty_when_no_candidate_changed() {
  local repo
  repo="$(_changed_repo)"

  assert_same "" \
    "$(cd "$repo" && bashunit::helper::git_filter_changed base ./base_test.sh ./other_test.sh)"
}

# `cmd; echo $?` would abort the command substitution under --strict before the
# echo ran, so the outcome is turned into text by an explicit if.
function _outcome_of() {
  if "$@"; then echo "yes"; else echo "no"; fi
}

function test_git_is_repo_is_false_outside_a_work_tree() {
  local outside
  outside="$(bashunit::temp_dir outside_repo)"

  assert_same "no" "$(cd "$outside" && _outcome_of bashunit::helper::git_is_repo)"
}

function test_git_is_repo_is_true_inside_a_work_tree() {
  local repo
  repo="$(_changed_repo)"

  assert_same "yes" "$(cd "$repo" && _outcome_of bashunit::helper::git_is_repo)"
}

function test_git_ref_exists_resolves_a_known_ref() {
  local repo
  repo="$(_changed_repo)"

  assert_same "yes" "$(cd "$repo" && _outcome_of bashunit::helper::git_ref_exists base)"
}

function test_git_ref_exists_rejects_an_unknown_ref() {
  local repo
  repo="$(_changed_repo)"

  assert_same "no" "$(cd "$repo" && _outcome_of bashunit::helper::git_ref_exists no_such_ref)"
}

function test_git_changed_ref_prefers_the_explicit_ref() {
  local repo
  repo="$(_changed_repo)"

  # shellcheck disable=SC2030  # confining the override to the subshell is the point
  assert_same "base" "$(cd "$repo" && export BASHUNIT_CHANGED_REF=base && bashunit::helper::git_changed_ref)"
}

function test_git_changed_ref_falls_back_to_head_without_an_origin() {
  local repo
  repo="$(_changed_repo)"

  # shellcheck disable=SC2031  # ditto: the empty override must not outlive the subshell
  assert_same "HEAD" "$(cd "$repo" && export BASHUNIT_CHANGED_REF='' && bashunit::helper::git_changed_ref)"
}
