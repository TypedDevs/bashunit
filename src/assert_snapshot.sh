#!/usr/bin/env bash

function snapshot::match_with_placeholder() {
  local actual="$1"
  local snapshot="$2"
  local placeholder="${BASHUNIT_SNAPSHOT_PLACEHOLDER:-::ignore::}"
  local token="__BASHUNIT_IGNORE__"

  local sanitized_snapshot="${snapshot//$placeholder/$token}"
  local regex
  regex=$(printf '%s' "$sanitized_snapshot" | sed -e 's/[.[\\^$*+?{}()|]/\\&/g')
  regex="${regex//$token/(.|\\n)*}"
  regex="^${regex}$"

  if command -v perl >/dev/null 2>&1; then
    if REGEX="$regex" perl -0 -e 'my $r=$ENV{REGEX}; exit((join("",<>)) =~ /$r/s ? 0 : 1);' <<< "$actual"; then
      return 0
    else
      return 1
    fi
  else
    # fallback: only supports single-line ignores
    local fallback_pattern
    fallback_pattern=$(printf '%s' "$snapshot" | sed "s|$placeholder|.*|g")
    # escape other special regex chars
    fallback_pattern=$(printf '%s' "$fallback_pattern" | sed -e 's/[][\.^$*+?{}|()]/\\&/g')
    fallback_pattern="^${fallback_pattern}$"

    if printf '%s\n' "$actual" | grep -Eq "$fallback_pattern"; then
      return 0
    else
      return 1
    fi
  fi
}

# shellcheck disable=SC2155
function assert_match_snapshot() {
  local actual
  actual=$(echo -n "$1" | tr -d '\r')
  local snapshot_file="${2-}"

  if [[ -z "$snapshot_file" ]]; then
    local directory="./$(dirname "${BASH_SOURCE[1]}")/snapshots"
    local test_file="$(helper::normalize_variable_name "$(basename "${BASH_SOURCE[1]}")")"
    local snapshot_name="$(helper::normalize_variable_name "${FUNCNAME[1]}").snapshot"
    snapshot_file="${directory}/${test_file}.${snapshot_name}"
  fi

  if [[ ! -f "$snapshot_file" ]]; then
    mkdir -p "$(dirname "$snapshot_file")"
    echo "$actual" > "$snapshot_file"

    state::add_assertions_snapshot
    return
  fi

  local snapshot
  snapshot=$(tr -d '\r' < "$snapshot_file")

  if ! snapshot::match_with_placeholder "$actual" "$snapshot"; then
    local label
    label=$(helper::normalize_test_function_name "${FUNCNAME[1]}")

    state::add_assertions_failed
    console_results::print_failed_snapshot_test "$label" "$snapshot_file"

    return
  fi

  state::add_assertions_passed
}

# shellcheck disable=SC2155
function assert_match_snapshot_ignore_colors() {
  local actual
  actual=$(echo -n "$1" | sed -r 's/\x1B\[[0-9;]*[mK]//g' | tr -d '\r')

  local snapshot_file="${2-}"
  if [[ -z "$snapshot_file" ]]; then
    local directory="./$(dirname "${BASH_SOURCE[1]}")/snapshots"
    local test_file="$(helper::normalize_variable_name "$(basename "${BASH_SOURCE[1]}")")"
    local snapshot_name="$(helper::normalize_variable_name "${FUNCNAME[1]}").snapshot"
    snapshot_file="${directory}/${test_file}.${snapshot_name}"
  fi

  if [[ ! -f "$snapshot_file" ]]; then
    mkdir -p "$(dirname "$snapshot_file")"
    echo "$actual" > "$snapshot_file"

    state::add_assertions_snapshot
    return
  fi

  local snapshot
  snapshot=$(tr -d '\r' < "$snapshot_file")

  if ! snapshot::match_with_placeholder "$actual" "$snapshot"; then
    local label
    label=$(helper::normalize_test_function_name "${FUNCNAME[1]}")

    state::add_assertions_failed
    console_results::print_failed_snapshot_test "$label" "$snapshot_file"

    return
  fi

  state::add_assertions_passed
}
