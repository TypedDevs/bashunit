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
    echo "polling"
  fi
}

function bashunit::watch::run() {
  local path="${1:-.}"
  shift
  # Declare and assign separately: bash 3.0 does not expand a compound array
  # assignment attached to `local`, it collapses "$@" into one literal element.
  local extra_args
  extra_args=("$@")

  local tool
  tool=$(bashunit::watch::is_available)

  if [ "$tool" = "polling" ]; then
    bashunit::watch::_print_polling_notice "$path"
  else
    printf "%sbashunit --watch%s  watching: %s\n\n" \
      "${_BASHUNIT_COLOR_PASSED}" "${_BASHUNIT_COLOR_DEFAULT}" "$path"
  fi

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

function bashunit::watch::_print_polling_notice() {
  local path="$1"
  printf "%sbashunit --watch%s  polling: %s (every %ss)\n\n" \
    "${_BASHUNIT_COLOR_PASSED}" "${_BASHUNIT_COLOR_DEFAULT}" \
    "$path" "${BASHUNIT_WATCH_INTERVAL:-2}"
  printf "  No 'inotifywait' or 'fswatch' found; using pure-shell polling.\n"
  printf "  Install one for instant triggers:\n"
  printf "    Linux:  sudo apt install inotify-tools\n"
  printf "    macOS:  brew install fswatch\n\n"
}

# Lists watched *.sh files modified since the sentinel file was touched.
# Non-empty output means a rerun is due. `find -newer` is POSIX and avoids the
# GNU/BSD `stat` flag divergence.
function bashunit::watch::_poll_changes() {
  local sentinel="$1"
  local path="$2"
  find "$path" -name '*.sh' -newer "$sentinel" -print 2>/dev/null
}

function bashunit::watch::wait_for_change() {
  local tool="$1"
  local path="$2"

  case "$tool" in
  polling)
    local sentinel
    sentinel="$(bashunit::temp_dir watch)/sentinel"
    while true; do
      : >"$sentinel"
      sleep "${BASHUNIT_WATCH_INTERVAL:-2}"
      if [ -n "$(bashunit::watch::_poll_changes "$sentinel" "$path")" ]; then
        return 0
      fi
    done
    ;;
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
