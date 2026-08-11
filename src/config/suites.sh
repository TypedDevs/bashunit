#!/usr/bin/env bash

# Named suites in .bashunitrc.
#
# A `[suite:<name>]` section names a set of paths and the options they run
# with, so a project with several tiers of tests keeps them in its config
# instead of in a Makefile:
#
#   [suite:unit]
#   paths = tests/unit
#   parallel = true
#   test-timeout = 60
#
# Every key but the reserved `paths` is a long option without its leading
# dashes (underscores are accepted for the dashes). `= true` means the bare
# flag, `= false` means "leave it out", anything else is the option's value.
# The suite's options are placed BEFORE the caller's on the command line, so an
# explicit flag still wins.
#
# The per-suite argv is stored as one newline-separated string because Bash 3.0
# has no array of arrays; a value may therefore contain spaces but not
# newlines.

_BASHUNIT_SUITE_NAMES=()
_BASHUNIT_SUITE_PATHS=()
_BASHUNIT_SUITE_ARGS=()
_BASHUNIT_SUITES_LOADED_FILE=""

_BASHUNIT_SUITE_PATHS_OUT=""
_BASHUNIT_SUITE_ARGS_OUT=""

##
# Aborts with a message quoting the line the config file could not be read as.
# Arguments: $1 - file, $2 - what is wrong, $3 - the offending line
##
function bashunit::suites::_abort() {
  printf "%sError: %s in %s: '%s'.%s\n" \
    "${_BASHUNIT_COLOR_FAILED:-}" "$2" "$1" "$3" "${_BASHUNIT_COLOR_DEFAULT:-}" >&2
  exit 1
}

##
# Parses the `[suite:<name>]` sections of a config file into the maps above.
# Memoized by path: the pre-scan and the expansion both call it.
# Arguments: $1 - config file (default .bashunitrc)
##
function bashunit::suites::load() {
  local file=${1:-.bashunitrc}

  if [ "$file" = "$_BASHUNIT_SUITES_LOADED_FILE" ]; then
    return 0
  fi
  _BASHUNIT_SUITES_LOADED_FILE="$file"
  _BASHUNIT_SUITE_NAMES=()
  _BASHUNIT_SUITE_PATHS=()
  _BASHUNIT_SUITE_ARGS=()

  [ -f "$file" ] || return 0

  local line raw key val index=-1
  # shellcheck disable=SC2094 # _abort takes the path only to name it in the
  # message it prints on stderr; nothing here writes to the file being read.
  while IFS= read -r line || [ -n "$line" ]; do
    raw=$line
    line=${line#"${line%%[![:space:]]*}"}
    line=${line%"${line##*[![:space:]]}"}

    case "$line" in
    '' | '#'* | ';'*) continue ;;
    esac

    # A section header: `[suite:name]` opens one, any other section closes the
    # current one so the global KEY=value lines after it are left to
    # load_config_file.
    case "$line" in
    '['*']')
      case "$line" in
      '[suite:'*']')
        local name=${line#\[suite:}
        name=${name%\]}
        name=${name#"${name%%[![:space:]]*}"}
        name=${name%"${name##*[![:space:]]}"}
        if [ -z "$name" ]; then
          bashunit::suites::_abort "$file" "a suite section needs a name" "$raw"
        fi
        index=$((${#_BASHUNIT_SUITE_NAMES[@]}))
        _BASHUNIT_SUITE_NAMES[index]="$name"
        _BASHUNIT_SUITE_PATHS[index]=""
        _BASHUNIT_SUITE_ARGS[index]=""
        ;;
      *) index=-1 ;;
      esac
      continue
      ;;
    esac

    # Outside a suite section this is a global setting, load_config_file's job.
    if [ "$index" -lt 0 ]; then
      continue
    fi

    case "$line" in
    *=*) ;;
    *) bashunit::suites::_abort "$file" "a suite entry must be 'key = value'" "$raw" ;;
    esac

    key=${line%%=*}
    val=${line#*=}
    key=${key%"${key##*[![:space:]]}"}
    val=${val#"${val%%[![:space:]]*}"}
    val=${val%"${val##*[![:space:]]}"}
    case "$val" in
    \"*\") val=${val#\"} val=${val%\"} ;;
    \'*\') val=${val#\'} val=${val%\'} ;;
    esac

    if [ "$key" = "paths" ] || [ "$key" = "path" ]; then
      _BASHUNIT_SUITE_PATHS[index]="$val"
      continue
    fi

    # Underscores read as dashes so `test_timeout` and `test-timeout` are the
    # same key, matching how the settings are spelled elsewhere.
    key=$(printf '%s' "$key" | tr '_' '-')
    case "$key" in
    '' | *[!a-z0-9-]*)
      bashunit::suites::_abort "$file" "a suite option must be a long flag name" "$raw"
      ;;
    esac

    case "$val" in
    false) continue ;;
    true) bashunit::suites::_append "$index" "--$key" ;;
    *) bashunit::suites::_append "$index" "--$key" "$val" ;;
    esac
  done <"$file"
}

##
# Appends argv entries to a suite's newline-separated list.
# Arguments: $1 - suite index, $@ - argv entries
##
function bashunit::suites::_append() {
  local index=$1
  shift
  local current=${_BASHUNIT_SUITE_ARGS[index]}
  local entry
  for entry in "$@"; do
    if [ -z "$current" ]; then
      current="$entry"
    else
      current="$current
$entry"
    fi
  done
  _BASHUNIT_SUITE_ARGS[index]="$current"
}

##
# Prints the defined suite names, one per line.
##
function bashunit::suites::names() {
  local i=0
  local total=${#_BASHUNIT_SUITE_NAMES[@]}
  while [ "$i" -lt "$total" ]; do
    printf '%s\n' "${_BASHUNIT_SUITE_NAMES[i]}"
    i=$((i + 1))
  done
}

##
# Resolves a suite into _BASHUNIT_SUITE_PATHS_OUT and _BASHUNIT_SUITE_ARGS_OUT
# (newline-separated argv). An unknown name aborts, listing what is defined:
# running the whole suite instead would look like the name had worked.
# Arguments: $1 - suite name
##
function bashunit::suites::resolve() {
  local wanted=$1
  local i=0
  local total=${#_BASHUNIT_SUITE_NAMES[@]}

  while [ "$i" -lt "$total" ]; do
    if [ "${_BASHUNIT_SUITE_NAMES[i]}" = "$wanted" ]; then
      _BASHUNIT_SUITE_PATHS_OUT="${_BASHUNIT_SUITE_PATHS[i]}"
      _BASHUNIT_SUITE_ARGS_OUT="${_BASHUNIT_SUITE_ARGS[i]}"
      return 0
    fi
    i=$((i + 1))
  done

  local defined
  defined=$(bashunit::suites::names | tr '\n' ' ')
  defined=${defined%" "}
  if [ -z "$defined" ]; then
    defined="none defined in .bashunitrc"
  fi
  printf "%sError: unknown suite '%s'. Defined: %s.%s\n" \
    "${_BASHUNIT_COLOR_FAILED:-}" "$wanted" "$defined" "${_BASHUNIT_COLOR_DEFAULT:-}" >&2
  exit 1
}
