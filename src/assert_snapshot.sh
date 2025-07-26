#!/usr/bin/env bash
# shellcheck disable=SC2155

function assert_match_snapshot() {
  local actual=$(echo -n "$1" | tr -d '\r')
  local snapshot_file=$(snapshot::resolve_file "${2:-}" "${FUNCNAME[1]}")

  if [[ ! -f "$snapshot_file" ]]; then
    snapshot::initialize "$snapshot_file" "$actual"
    return
  fi

  snapshot::compare "$actual" "$snapshot_file" "${FUNCNAME[1]}"
}

function assert_match_snapshot_ignore_colors() {
  local actual=$(echo -n "$1" | sed 's/\x1B\[[0-9;]*[mK]//g' | tr -d '\r')
  local snapshot_file=$(snapshot::resolve_file "${2:-}" "${FUNCNAME[1]}")

  if [[ ! -f "$snapshot_file" ]]; then
    snapshot::initialize "$snapshot_file" "$actual"
    return
  fi

  snapshot::compare "$actual" "$snapshot_file" "${FUNCNAME[1]}"
}

function snapshot::match_with_placeholder() {
  local actual="$1"
  local snapshot="$2"
  local placeholder="${BASHUNIT_SNAPSHOT_PLACEHOLDER:-::ignore::}"
  local token="__BASHUNIT_IGNORE__"

  local sanitized="${snapshot//$placeholder/$token}"
  local escaped=$(printf '%s' "$sanitized" | sed -e 's/[.[\\^$*+?{}()|]/\\&/g')
  local regex="^${escaped//$token/(.|\\n)*}$"

  if which perl >/dev/null 2>&1; then
    echo "$actual" | REGEX="$regex" perl -0 -e '
      my $r = $ENV{REGEX};
      my $input = join("", <STDIN>);
      exit($input =~ /$r/s ? 0 : 1);
    ' && return 0 || return 1
  else
    local fallback=$(printf '%s' "$snapshot" | sed -e "s|$placeholder|.*|g" -e 's/[][\.^$*+?{}|()]/\\&/g')
    fallback="^${fallback}$"
    echo "$actual" | grep -Eq "$fallback" && return 0 || return 1
  fi
}

function snapshot::resolve_file() {
  local file_hint="$1"
  local func_name="$2"

  if [[ -n "$file_hint" ]]; then
    echo "$file_hint"
  else
    local dir="./$(dirname "${BASH_SOURCE[2]}")/snapshots"
    local test_file="$(helper::normalize_variable_name "$(basename "${BASH_SOURCE[2]}")")"
    local name="$(helper::normalize_variable_name "$func_name").snapshot"
    echo "${dir}/${test_file}.${name}"
  fi
}

function snapshot::initialize() {
  local path="$1"
  local content="$2"
  mkdir -p "$(dirname "$path")"
  echo "$content" > "$path"
  state::add_assertions_snapshot
}

function snapshot::compare() {
  local actual="$1"
  local snapshot_path="$2"
  local func_name="$3"

  local snapshot
  snapshot=$(tr -d '\r' < "$snapshot_path")

  if ! snapshot::match_with_placeholder "$actual" "$snapshot"; then
    local label=$(helper::normalize_test_function_name "$func_name")
    state::add_assertions_failed
    console_results::print_failed_snapshot_test "$label" "$snapshot_path" "$actual"
    return 1
  fi

  state::add_assertions_passed
}
