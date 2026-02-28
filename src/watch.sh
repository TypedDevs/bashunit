#!/usr/bin/env bash

# bashunit watch mode
# Watches test and source files for changes and re-runs tests automatically.
# Requires: inotifywait (inotify-tools) on Linux, or fswatch on macOS.

function bashunit::watch::_command_exists() {
  command -v "$1" &>/dev/null
}

function bashunit::watch::is_available() {
  if bashunit::watch::_command_exists inotifywait; then
    echo "inotifywait"
  elif bashunit::watch::_command_exists fswatch; then
    echo "fswatch"
  else
    echo ""
  fi
}

function bashunit::watch::run() {
  local path="${1:-.}"
  shift
  local extra_args=("$@")

  local tool
  tool=$(bashunit::watch::is_available)

  if [[ -z "$tool" ]]; then
    printf "%sError: watch mode requires 'inotifywait' (Linux) or 'fswatch' (macOS).%s\n" \
      "${_BASHUNIT_COLOR_FAILED}" "${_BASHUNIT_COLOR_DEFAULT}"
    printf "  Linux:  sudo apt install inotify-tools\n"
    printf "  macOS:  brew install fswatch\n"
    exit 1
  fi

  printf "%sbashunit --watch%s  watching: %s\n\n" \
    "${_BASHUNIT_COLOR_PASSED}" "${_BASHUNIT_COLOR_DEFAULT}" "$path"

  # Run once immediately before entering the watch loop
  bashunit::watch::run_tests "$path" "${extra_args[@]+"${extra_args[@]}"}"

  while true; do
    bashunit::watch::wait_for_change "$tool" "$path"
    printf "\n%s[change detected — re-running tests]%s\n\n" \
      "${_BASHUNIT_COLOR_SKIPPED}" "${_BASHUNIT_COLOR_DEFAULT}"
    bashunit::watch::run_tests "$path" "${extra_args[@]+"${extra_args[@]}"}"
  done
}

function bashunit::watch::run_tests() {
  local path="$1"
  shift
  # Re-invoke bashunit test in a subshell so state resets cleanly each run
  "$BASHUNIT_ROOT_DIR/bashunit" test "$path" "$@"
  return $?
}

function bashunit::watch::wait_for_change() {
  local tool="$1"
  local path="$2"

  case "$tool" in
  inotifywait)
    inotifywait \
      --quiet \
      --recursive \
      --event modify,create,delete,move \
      --include '.*\.sh$' \
      "$path" 2>/dev/null
    ;;
  fswatch)
    # fswatch outputs one line per event; we only need the first one
    fswatch \
      --recursive \
      --include='.*\.sh$' \
      --exclude='.*' \
      --one-event \
      "$path" 2>/dev/null
    ;;
  esac
}
