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

  bashunit::snapshot::assert "$actual" "$snapshot_file" "$test_fn"
}

function assert_match_named_snapshot() {
  local snapshot_name=$1
  local _snapshot_normalized
  bashunit::snapshot::normalize_actual "$2"
  local actual=$_snapshot_normalized
  bashunit::helper::find_test_function_name_to_slot
  local test_fn=$_BASHUNIT_HELPER_TESTFN_OUT
  bashunit::snapshot::resolve_file "" "$test_fn" "$snapshot_name"
  local snapshot_file=$_BASHUNIT_SNAPSHOT_FILE_OUT

  bashunit::snapshot::assert "$actual" "$snapshot_file" "$test_fn"
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

  bashunit::snapshot::assert "$actual" "$snapshot_file" "$test_fn"
}

function assert_match_named_snapshot_ignore_colors() {
  local snapshot_name=$1
  # Keep this byte-compatible with assert_match_snapshot_ignore_colors: only
  # ANSI sequences ending in m/K are stripped, and only when ESC is present.
  local stripped=$2
  case "$stripped" in
  *$'\e'*) stripped=$(printf '%s' "$stripped" | sed 's/\x1B\[[0-9;]*[mK]//g') ;;
  esac
  local _snapshot_normalized
  bashunit::snapshot::normalize_actual "$stripped"
  local actual=$_snapshot_normalized
  bashunit::helper::find_test_function_name_to_slot
  local test_fn=$_BASHUNIT_HELPER_TESTFN_OUT
  bashunit::snapshot::resolve_file "" "$test_fn" "$snapshot_name"
  local snapshot_file=$_BASHUNIT_SNAPSHOT_FILE_OUT

  bashunit::snapshot::assert "$actual" "$snapshot_file" "$test_fn"
}

# Strips the `./` resolve_file prepends and squeezes doubled slashes, so a path
# recorded by an assertion and the same path as `find` prints it compare equal.
function bashunit::snapshot::normalize_path() {
  local path="$1"
  while [ "${path#./}" != "$path" ]; do
    path="${path#./}"
  done
  while [ "${path%%//*}" != "$path" ]; do
    path="${path%%//*}/${path#*//}"
  done
  builtin echo "$path"
}

# Lists the snapshot files under $@ that no test resolved this run, and says so.
# Deliberately reports only: a snapshot deleted by mistake is re-recorded on the
# next run and never fails again, so an automatic cleanup could quietly turn a
# real assertion into one that asserts nothing.
function bashunit::snapshot::report_unused() {
  local -a search_paths=()
  local path
  for path in "$@"; do
    if [ -d "$path" ]; then
      search_paths[${#search_paths[@]}]="$path"
    elif [ -f "$path" ]; then
      case "$path" in
      */*) search_paths[${#search_paths[@]}]="${path%/*}" ;;
      *) search_paths[${#search_paths[@]}]="." ;;
      esac
    fi
  done
  if [ "${#search_paths[@]}" -eq 0 ]; then
    search_paths[0]="."
  fi

  # A snapshot is named "<normalized test file>.<normalized function>.snapshot",
  # so it can be attributed to the test file that owns it. Only the files this
  # run discovered are considered: running one file or one directory must not
  # report every snapshot belonging to the files it did not run.
  local owners=""
  for path in "$@"; do
    [ -f "$path" ] || continue
    bashunit::helper::normalize_variable_name_to_slot "${path##*/}"
    owners="$owners$_BASHUNIT_HELPER_VARNAME_OUT
"
  done

  local used=""
  if [ -f "${SNAPSHOT_USED_OUTPUT_PATH:-}" ]; then
    local used_path
    while IFS= read -r used_path; do
      [ -z "$used_path" ] && continue
      used="$used$(bashunit::snapshot::normalize_path "$used_path")
"
    done <"$SNAPSHOT_USED_OUTPUT_PATH"
  fi

  local unused=""
  local total=0
  local dir file normalized
  while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    for file in "$dir"/*.snapshot; do
      [ -f "$file" ] || continue
      normalized="$(bashunit::snapshot::normalize_path "$file")"
      case "$used" in
      *"$normalized"$'\n'*) continue ;;
      esac
      local owner="${file##*/}"
      owner="${owner%%.*}"
      case "$owners" in
      *"$owner"$'\n'*) ;;
      *) continue ;;
      esac
      total=$((total + 1))
      unused="$unused  $normalized
"
    done
  done < <(find "${search_paths[@]}" -type d -name snapshots 2>/dev/null | sort -u)

  if [ "$total" -eq 0 ]; then
    printf "\n%sNo unused snapshots.%s\n" \
      "${_BASHUNIT_COLOR_FAINT}" "${_BASHUNIT_COLOR_DEFAULT}"
    return
  fi

  printf "\n%sUnused snapshots (%s), no test resolved them:%s\n%s" \
    "${_BASHUNIT_COLOR_SKIPPED}" "$total" "${_BASHUNIT_COLOR_DEFAULT}" "$unused"
  printf "%sNothing was deleted. Delete them yourself once you have checked the tests are gone.%s\n" \
    "${_BASHUNIT_COLOR_FAINT}" "${_BASHUNIT_COLOR_DEFAULT}"
}

# The shared tail of both snapshot assertions: record a first-time snapshot,
# rewrite it under --snapshot-update, or compare against it.
# Arguments: $1 - actual value, $2 - snapshot path, $3 - test function name
function bashunit::snapshot::assert() {
  local actual="$1"
  local snapshot_file="$2"
  local test_fn="$3"

  if bashunit::env::is_snapshot_report_unused_enabled; then
    printf '%s\n' "$snapshot_file" >>"${SNAPSHOT_USED_OUTPUT_PATH:-/dev/null}" 2>/dev/null || true
  fi

  if [ ! -f "$snapshot_file" ]; then
    if ! bashunit::env::is_snapshot_create_enabled; then
      bashunit::snapshot::fail_missing "$snapshot_file" "$test_fn"
      return
    fi
    bashunit::snapshot::initialize "$snapshot_file" "$actual"
    return
  fi

  if bashunit::snapshot::update "$snapshot_file" "$actual"; then
    return
  fi

  bashunit::snapshot::compare "$actual" "$snapshot_file" "$test_fn"
}

# Fails because the snapshot has to exist already (--no-snapshot-create). The
# resolved path goes in the message: it is derived from the test file and
# function name, so a reader cannot otherwise tell which file to commit.
function bashunit::snapshot::fail_missing() {
  local path="$1"
  local func_name="$2"
  local label
  label=$(bashunit::helper::normalize_test_function_name "$func_name")

  bashunit::state::add_assertions_failed
  bashunit::console_results::print_failed_test "$label" "$path" \
    "does not exist; record it with a run without" "--no-snapshot-create"
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
    printf '%s' "$actual" | REGEX="$regex" perl -0 -e '
      my $r = $ENV{REGEX};
      my $input = join("", <STDIN>);
      exit($input =~ /$r/s ? 0 : 1);
    ' && return 0 || return 1
  fi

  # awk, not grep. grep applies the pattern per line, and a pattern that itself
  # contains newlines is read as several alternative patterns -- so a multi-line
  # snapshot whose placeholder sits on its own line contributed a bare `.*`,
  # which matches any line of any input. That made an unrelated value pass while
  # comparing nothing. Setting RS to a byte the input cannot contain gives awk
  # the whole value as one record, so the anchors and the placeholder behave as
  # they do under perl.
  if bashunit::dependencies::has_awk; then
    printf '%s' "$actual" | REGEX="$regex" awk '
      BEGIN { RS = "\001"; re = ENVIRON["REGEX"] }
      { exit !($0 ~ re) }
    ' && return 0 || return 1
  fi

  # Neither available: refuse rather than guess. A placeholder snapshot that
  # cannot be evaluated must not report success.
  printf '%sCannot match a snapshot placeholder: neither perl nor awk is available.%s\n' \
    "${_BASHUNIT_COLOR_FAILED:-}" "${_BASHUNIT_COLOR_DEFAULT:-}" >&2
  return 1
}

# Writes the resolved snapshot path into _BASHUNIT_SNAPSHOT_FILE_OUT (no fork).
# Derives the path from BASH_SOURCE[2] using parameter expansion instead of
# dirname/basename, keeping the exact string the previous version produced.
_BASHUNIT_SNAPSHOT_FILE_OUT=""
function bashunit::snapshot::resolve_file() {
  local file_hint="$1"
  local func_name="$2"
  local snapshot_name="${3:-}"

  if [ -n "$file_hint" ]; then
    _BASHUNIT_SNAPSHOT_FILE_OUT=$file_hint
    return
  fi

  # dirname via parameter expansion. `dirname "foo.sh"` (no slash) is ".", which
  # `${src%/*}` cannot yield, so special-case the slashless path.
  #
  # $4 exists for the tests: BASH_SOURCE[2] is the test file only when this is
  # reached through assert_match_snapshot, so a test calling it directly would
  # otherwise resolve against the runner's own source.
  local src="${4:-${BASH_SOURCE[2]}}"
  local dir_part
  case "$src" in
  */*) dir_part="${src%/*}" ;;
  *) dir_part="." ;;
  esac
  local base_part="${src##*/}"

  bashunit::helper::normalize_variable_name_to_slot "$base_part"
  local test_file=$_BASHUNIT_HELPER_VARNAME_OUT
  bashunit::helper::normalize_variable_name_to_slot "$func_name"
  local name=$_BASHUNIT_HELPER_VARNAME_OUT
  if [ -n "$snapshot_name" ]; then
    bashunit::helper::normalize_variable_name_to_slot "$snapshot_name"
    name="$name.$_BASHUNIT_HELPER_VARNAME_OUT"
  fi

  # An absolute directory must stay absolute. Prefixing "./" turned
  # "/abs/dir" into a path relative to the caller's cwd, so the real snapshot
  # was never read and a stray one was recorded elsewhere -- every snapshot
  # assertion in that run passed while comparing nothing.
  case "$dir_part" in
  /*) _BASHUNIT_SNAPSHOT_FILE_OUT="${dir_part}/snapshots/${test_file}.${name}.snapshot" ;;
  *) _BASHUNIT_SNAPSHOT_FILE_OUT="./${dir_part}/snapshots/${test_file}.${name}.snapshot" ;;
  esac
}

function bashunit::snapshot::initialize() {
  local path="$1"
  local content="$2"
  mkdir -p "$(dirname "$path")"
  echo "$content" >"$path"
  bashunit::state::add_assertions_snapshot
}

# Under --snapshot-update, rewrites $1 with the actual value $2 and counts it as
# a recorded snapshot. Returns 1 when the caller must fall back to a normal
# comparison: either the mode is off, or the snapshot carries a placeholder.
#
# A placeholder is deliberate: it marks a part of the output the author decided
# not to pin. Overwriting would silently replace it with whatever this run
# produced, turning a tolerant snapshot into a brittle one with no way back, so
# such a file is left alone and the run says so on stderr.
function bashunit::snapshot::update() {
  local path="$1"
  local actual="$2"

  bashunit::env::is_snapshot_update_enabled || return 1

  local placeholder="${BASHUNIT_SNAPSHOT_PLACEHOLDER:-::ignore::}"
  local snapshot
  snapshot=$(<"$path")
  case "$snapshot" in
  *"$placeholder"*)
    printf "%sNot updating %s: it contains the placeholder '%s'.%s\n" \
      "${_BASHUNIT_COLOR_SKIPPED:-}" "$path" "$placeholder" "${_BASHUNIT_COLOR_DEFAULT:-}" >&2
    return 1
    ;;
  esac

  echo "$actual" >"$path"
  bashunit::state::add_assertions_snapshot
  return 0
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

  # Literal snapshots need only a builtin string comparison. The placeholder
  # matcher shells out to sed and perl/grep, so reserve it for snapshots that
  # actually contain the configured marker.
  if [ "$actual" = "$snapshot" ]; then
    bashunit::state::add_assertions_passed
    return
  fi

  local placeholder="${BASHUNIT_SNAPSHOT_PLACEHOLDER:-::ignore::}"
  case "$snapshot" in
  *"$placeholder"*)
    if bashunit::snapshot::match_with_placeholder "$actual" "$snapshot"; then
      bashunit::state::add_assertions_passed
      return
    fi
    ;;
  esac

  local label=$(bashunit::helper::normalize_test_function_name "$func_name")
  bashunit::state::add_assertions_failed
  bashunit::console_results::print_failed_snapshot_test "$label" "$snapshot_path" "$actual"
  return 1
}
