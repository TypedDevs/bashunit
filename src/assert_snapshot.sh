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

# Remove progress bar output from a given string. Progress bar sequences are
# wrapped between ESC7 and ESC8 control codes when a TTY is present.
function snapshot::strip_progress_line() {
  local input="$1"
  echo -n "$input" | sed $'s/\x1b7.*\x1b8//'
}

function assert_match_snapshot() {
  local actual
  actual=$(echo -n "$1" | tr -d '\r')
  actual=$(snapshot::strip_progress_line "$actual")
  local directory
  directory="./$(dirname "${BASH_SOURCE[1]}")/snapshots"
  local test_file
  test_file="$(helper::normalize_variable_name "$(basename "${BASH_SOURCE[1]}")")"
  local snapshot_name
  snapshot_name="$(helper::normalize_variable_name "${FUNCNAME[1]}").snapshot"
  local snapshot_file
  snapshot_file="${directory}/${test_file}.${snapshot_name}"

  if [[ ! -f "$snapshot_file" ]]; then
    mkdir -p "$directory"
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

function assert_match_snapshot_ignore_colors() {
  local actual
  actual=$(echo -n "$1" | sed -r 's/\x1B\[[0-9;]*[mK]//g' | tr -d '\r')
  actual=$(snapshot::strip_progress_line "$actual")

  local directory
  directory="./$(dirname "${BASH_SOURCE[1]}")/snapshots"
  local test_file
  test_file="$(helper::normalize_variable_name "$(basename "${BASH_SOURCE[1]}")")"
  local snapshot_name
  snapshot_name="$(helper::normalize_variable_name "${FUNCNAME[1]}").snapshot"
  local snapshot_file
  snapshot_file="${directory}/${test_file}.${snapshot_name}"

  if [[ ! -f "$snapshot_file" ]]; then
    mkdir -p "$directory"
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
