#!/usr/bin/env bash

# Remote tag lookup, used by the upgrade subcommand.

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

# Also written by find_total_tests so a main-shell caller can read the count
# without a $() capture (which would discard the provider-map cache built here).
_BASHUNIT_HELPER_TOTAL_TESTS_OUT=0

