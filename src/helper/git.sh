#!/usr/bin/env bash

# Remote tag lookup for the upgrade subcommand, and the working-tree queries
# behind --changed.

declare -r BASHUNIT_GIT_REPO="https://github.com/TypedDevs/bashunit"

function bashunit::helper::get_latest_tag() {
  if ! bashunit::dependencies::has_git; then
    return 1
  fi

  # Floating major tags (e.g. v0) are not releases and must not win
  git ls-remote --tags "$BASHUNIT_GIT_REPO" |
    awk '{print $2}' |
    sed 's|^refs/tags/||' |
    grep -v '\^{}' |
    grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$' |
    sort -Vr |
    head -n 1
}

##
# Returns 0 when the working directory sits inside a git work tree.
##
function bashunit::helper::git_is_repo() {
  if ! bashunit::dependencies::has_git; then
    return 1
  fi

  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

##
# Returns 0 when the ref resolves to a commit in the current repository.
# Arguments: $1 - the ref
##
function bashunit::helper::git_ref_exists() {
  git rev-parse --verify --quiet "$1^{commit}" >/dev/null 2>&1
}

##
# Echoes the ref --changed diffs against: BASHUNIT_CHANGED_REF when set, then
# origin/HEAD, then HEAD. HEAD is the last resort rather than an error because a
# shallow CI checkout has no remote-tracking branch, and diffing HEAD still
# reports the working-tree edits.
##
function bashunit::helper::git_changed_ref() {
  if [ -n "${BASHUNIT_CHANGED_REF:-}" ]; then
    echo "$BASHUNIT_CHANGED_REF"
  elif bashunit::helper::git_ref_exists "origin/HEAD"; then
    echo "origin/HEAD"
  else
    echo "HEAD"
  fi
}

##
# Echoes every file git reports as changed since the ref, one per line, relative
# to the working directory.
#
# Three sources are merged because none of them sees the others: the commit
# range covers what is committed, the diff against HEAD covers staged and
# unstaged edits, and ls-files covers a brand-new file no commit knows about.
# Deletions are dropped (--diff-filter=d) so a removed test file never reaches
# discovery, and -M turns a rename into its new path alone.
# Arguments: $1 - the ref
##
function bashunit::helper::git_changed_files() {
  local ref=$1
  local prefix
  prefix="$(git rev-parse --show-prefix 2>/dev/null)"

  # quotePath would octal-escape non-ASCII names, which no longer match the
  # paths discovery produced.
  {
    git -c core.quotePath=false diff -M --name-only --diff-filter=d "$ref...HEAD" 2>/dev/null
    git -c core.quotePath=false diff -M --name-only --diff-filter=d HEAD 2>/dev/null
    git -c core.quotePath=false ls-files --others --exclude-standard 2>/dev/null
  } | awk -v prefix="$prefix" '
    NF == 0 { next }
    prefix != "" {
      if (index($0, prefix) != 1) next
      $0 = substr($0, length(prefix) + 1)
    }
    !seen[$0]++'
}

##
# Echoes the given candidate files that changed since the ref, preserving the
# caller order and path spelling. A leading "./" is ignored on both sides:
# discovery emits the paths the user typed, git always emits repo-relative ones.
# Arguments: $1 - the ref, $@ - candidate files
##
function bashunit::helper::git_filter_changed() {
  local ref=$1
  shift

  local changed
  changed="$(bashunit::helper::git_changed_files "$ref")"
  [ -n "$changed" ] || return 0

  local file normalized
  for file in "$@"; do
    normalized="${file#./}"
    case "
$changed
" in
    *"
$normalized
"*) printf '%s\n' "$file" ;;
    esac
  done
}

# Also written by find_total_tests so a main-shell caller can read the count
# without a $() capture (which would discard the provider-map cache built here).
_BASHUNIT_HELPER_TOTAL_TESTS_OUT=0

