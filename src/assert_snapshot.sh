#!/usr/bin/env bash
# shellcheck disable=SC2155

# Strips all carriage returns, then any trailing newlines, entirely in bash.
# Reproduces the previous `$(echo -n "$in" | tr -d '\r')` (command substitution
# drops trailing newlines) without the two forks. Result in _snapshot_normalized.
function bashunit::snapshot::normalize_actual() {
  local normalized="${1//$'\r'/}"
  while [ "${normalized%$'\n'}" != "$normalized" ]; do
    normalized="${normalized%$'\n'}"
  done
  _snapshot_normalized=$normalized
}

function assert_match_snapshot() {
  local _snapshot_normalized
  bashunit::snapshot::normalize_actual "$1"
  local actual=$_snapshot_normalized
  bashunit::helper::find_test_function_name_to_slot
  local test_fn=$_BASHUNIT_HELPER_TESTFN_OUT
  bashunit::snapshot::resolve_file "${2:-}" "$test_fn"
  local snapshot_file=$_BASHUNIT_SNAPSHOT_FILE_OUT

  if [ ! -f "$snapshot_file" ]; then
    bashunit::snapshot::initialize "$snapshot_file" "$actual"
    return
  fi

  bashunit::snapshot::compare "$actual" "$snapshot_file" "$test_fn"
}

function assert_match_snapshot_ignore_colors() {
  # Only fork sed when the input actually carries an escape sequence; plain,
  # colorless output takes a pure-bash fast path. The sed pattern is kept
  # identical to the historic one (strip `\x1B[...[mK]` only) so on-disk
  # snapshots stay byte-compatible.
  local stripped=$1
  case "$stripped" in
  *$'\e'*) stripped=$(printf '%s' "$stripped" | sed 's/\x1B\[[0-9;]*[mK]//g') ;;
  esac
  local _snapshot_normalized
  bashunit::snapshot::normalize_actual "$stripped"
  local actual=$_snapshot_normalized
  bashunit::helper::find_test_function_name_to_slot
  local test_fn=$_BASHUNIT_HELPER_TESTFN_OUT
  bashunit::snapshot::resolve_file "${2:-}" "$test_fn"
  local snapshot_file=$_BASHUNIT_SNAPSHOT_FILE_OUT

  if [ ! -f "$snapshot_file" ]; then
    bashunit::snapshot::initialize "$snapshot_file" "$actual"
    return
  fi

  bashunit::snapshot::compare "$actual" "$snapshot_file" "$test_fn"
}

function bashunit::snapshot::match_with_placeholder() {
  local actual="$1"
  local snapshot="$2"
  local placeholder="${BASHUNIT_SNAPSHOT_PLACEHOLDER:-::ignore::}"
  local token="__BASHUNIT_IGNORE__"

  local sanitized="${snapshot//$placeholder/$token}"
  local escaped=$(printf '%s' "$sanitized" | sed -e 's/[.[\\^$*+?{}()|]/\\&/g')
  local regex="^${escaped//$token/(.|\\n)*}$"

  if command -v perl >/dev/null 2>&1; then
    echo "$actual" | REGEX="$regex" perl -0 -e '
      my $r = $ENV{REGEX};
      my $input = join("", <STDIN>);
      exit($input =~ /$r/s ? 0 : 1);
    ' && return 0 || return 1
  else
    # No perl: build the pattern exactly like the perl branch — swap the
    # placeholder for a token that survives escaping, escape the regex
    # metacharacters, then turn the token into `.*`. (The previous order,
    # escaping after inserting `.*`, escaped the `.*` itself and broke every
    # fallback match.) grep matches line-by-line, so unlike the perl branch a
    # placeholder cannot span multiple lines here.
    local fallback="${snapshot//$placeholder/$token}"
    fallback=$(printf '%s' "$fallback" | sed -e 's/[.[\\^$*+?{}()|]/\\&/g')
    fallback="^${fallback//$token/.*}$"
    echo "$actual" | grep -Eq "$fallback" && return 0 || return 1
  fi
}

# Writes the resolved snapshot path into _BASHUNIT_SNAPSHOT_FILE_OUT (no fork).
# Derives the path from BASH_SOURCE[2] using parameter expansion instead of
# dirname/basename, keeping the exact string the previous version produced.
_BASHUNIT_SNAPSHOT_FILE_OUT=""
function bashunit::snapshot::resolve_file() {
  local file_hint="$1"
  local func_name="$2"

  if [ -n "$file_hint" ]; then
    _BASHUNIT_SNAPSHOT_FILE_OUT=$file_hint
    return
  fi

  # dirname via parameter expansion. `dirname "foo.sh"` (no slash) is ".", which
  # `${src%/*}` cannot yield, so special-case the slashless path.
  local src="${BASH_SOURCE[2]}"
  local dir_part
  case "$src" in
  */*) dir_part="${src%/*}" ;;
  *) dir_part="." ;;
  esac
  local base_part="${src##*/}"

  bashunit::helper::normalize_variable_name_to_slot "$base_part"
  local test_file=$_BASHUNIT_HELPER_VARNAME_OUT
  bashunit::helper::normalize_variable_name_to_slot "$func_name"
  local name="$_BASHUNIT_HELPER_VARNAME_OUT.snapshot"

  _BASHUNIT_SNAPSHOT_FILE_OUT="./${dir_part}/snapshots/${test_file}.${name}"
}

function bashunit::snapshot::initialize() {
  local path="$1"
  local content="$2"
  mkdir -p "$(dirname "$path")"
  echo "$content" >"$path"
  bashunit::state::add_assertions_snapshot
}

function bashunit::snapshot::compare() {
  local actual="$1"
  local snapshot_path="$2"
  local func_name="$3"

  # `$(<file)` reads without forking cat/tr; command substitution drops trailing
  # newlines exactly like the previous `$(tr -d '\r' <file)`. Strip the carriage
  # returns in bash afterwards.
  local snapshot
  snapshot=$(<"$snapshot_path")
  snapshot="${snapshot//$'\r'/}"

  if ! bashunit::snapshot::match_with_placeholder "$actual" "$snapshot"; then
    local label=$(bashunit::helper::normalize_test_function_name "$func_name")
    bashunit::state::add_assertions_failed
    bashunit::console_results::print_failed_snapshot_test "$label" "$snapshot_path" "$actual"
    return 1
  fi

  bashunit::state::add_assertions_passed
}
