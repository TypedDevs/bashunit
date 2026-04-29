#!/usr/bin/env bash

_BASHUNIT_BASELINE_FILES=()
_BASHUNIT_BASELINE_NAMES=()
_BASHUNIT_BASELINE_STATUSES=()

##
# Escape XML special characters for use inside attribute values.
# Arguments: $1 - text
##
function bashunit::baseline::__xml_escape_attr() {
  # sed handles & and \" literals consistently across Bash versions; bash
  # parameter expansion with patsub_replacement (5.2+) treats & in the
  # replacement specially, which would corrupt entity strings.
  printf '%s' "$1" \
    | sed -e 's/&/\&amp;/g' \
      -e 's/</\&lt;/g' \
      -e 's/>/\&gt;/g' \
      -e 's/"/\&quot;/g' \
      -e "s/'/\&apos;/g"
}

##
# Decode the XML entities used by bashunit::baseline::__xml_escape_attr.
# Arguments: $1 - text
##
function bashunit::baseline::__xml_unescape_attr() {
  # &amp; must be decoded last so we don't double-decode.
  printf '%s' "$1" \
    | sed -e 's/&lt;/</g' \
      -e 's/&gt;/>/g' \
      -e 's/&quot;/"/g' \
      -e "s/&apos;/'/g" \
      -e 's/&amp;/\&/g'
}

##
# Generate a baseline XML file listing the current run's failed/risky/incomplete tests.
# Arguments: $1 - output file path
##
function bashunit::baseline::generate() {
  local output_file="$1"

  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<baseline version="1.0">'

    local i status file name
    for i in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
      status="${_BASHUNIT_REPORTS_TEST_STATUSES[$i]:-}"

      case "$status" in
      failed | risky | incomplete) ;;
      *) continue ;;
      esac

      file="$(bashunit::baseline::__xml_escape_attr "${_BASHUNIT_REPORTS_TEST_FILES[$i]:-}")"
      name="$(bashunit::baseline::__xml_escape_attr "${_BASHUNIT_REPORTS_TEST_NAMES[$i]:-}")"
      echo "  <test file=\"$file\" name=\"$name\" status=\"$status\"/>"
    done

    echo '</baseline>'
  } >"$output_file"
}

##
# Load entries from a baseline XML file into the lookup arrays.
# Arguments: $1 - input file path
# Returns: 0 success, 1 if file missing
##
function bashunit::baseline::load() {
  local input_file="$1"

  if [ ! -f "$input_file" ]; then
    return 1
  fi

  _BASHUNIT_BASELINE_FILES=()
  _BASHUNIT_BASELINE_NAMES=()
  _BASHUNIT_BASELINE_STATUSES=()

  local line file name status
  while IFS= read -r line; do
    case "$line" in
    *"<test "*)
      file=""
      name=""
      status=""

      case "$line" in
      *file=\"*)
        file="${line#*file=\"}"
        file="${file%%\"*}"
        ;;
      esac
      case "$line" in
      *name=\"*)
        name="${line#*name=\"}"
        name="${name%%\"*}"
        ;;
      esac
      case "$line" in
      *status=\"*)
        status="${line#*status=\"}"
        status="${status%%\"*}"
        ;;
      esac

      file="$(bashunit::baseline::__xml_unescape_attr "$file")"
      name="$(bashunit::baseline::__xml_unescape_attr "$name")"

      _BASHUNIT_BASELINE_FILES[${#_BASHUNIT_BASELINE_FILES[@]}]="$file"
      _BASHUNIT_BASELINE_NAMES[${#_BASHUNIT_BASELINE_NAMES[@]}]="$name"
      _BASHUNIT_BASELINE_STATUSES[${#_BASHUNIT_BASELINE_STATUSES[@]}]="$status"
      ;;
    esac
  done <"$input_file"
}

##
# Whether the run should consult the loaded baseline to suppress matched issues.
# Returns: 0 if --use-baseline is active, 1 otherwise
##
function bashunit::baseline::is_use_enabled() {
  [ -n "${BASHUNIT_BASELINE_USE:-}" ]
}

##
# Suppress a failing/risky/incomplete test if it matches an entry in the baseline.
# Records a "baselined" entry in the report arrays and increments the baselined counter.
# Arguments: $1 - file, $2 - label, $3 - status, $4 - duration, $5 - assertions
# Returns: 0 if matched and suppressed, 1 otherwise (caller should proceed normally)
##
function bashunit::baseline::match_and_record() {
  local file="$1"
  local label="$2"
  local status="$3"
  local duration="${4:-0}"
  local assertions="${5:-0}"

  bashunit::baseline::is_use_enabled || return 1
  bashunit::baseline::contains "$file" "$label" "$status" || return 1

  bashunit::state::add_tests_baselined
  # Force-track the baselined entry regardless of report flags.
  local _prev="${BASHUNIT_BASELINE_GENERATE:-}"
  BASHUNIT_BASELINE_GENERATE="${BASHUNIT_BASELINE_GENERATE:-baselined}"
  bashunit::reports::add_test "$file" "$label" "$duration" "$assertions" "baselined"
  BASHUNIT_BASELINE_GENERATE="$_prev"
  return 0
}

##
# Check whether a (file, name, status) triple exists in the loaded baseline.
# Arguments: $1 - file, $2 - test name, $3 - status
# Returns: 0 if present, 1 otherwise
##
function bashunit::baseline::contains() {
  local file="$1"
  local name="$2"
  local status="$3"

  local i
  for i in "${!_BASHUNIT_BASELINE_FILES[@]}"; do
    if [ "${_BASHUNIT_BASELINE_FILES[$i]}" = "$file" ] &&
      [ "${_BASHUNIT_BASELINE_NAMES[$i]}" = "$name" ] &&
      [ "${_BASHUNIT_BASELINE_STATUSES[$i]}" = "$status" ]; then
      return 0
    fi
  done

  return 1
}
