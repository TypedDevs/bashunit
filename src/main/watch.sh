#!/usr/bin/env bash

# The --watch polling loop and its checksum.

function bashunit::main::watch_get_checksum() {
  local IFS=$' \t\n'
  local -a paths=("$@")

  local file checksum=""
  for file in "${paths[@]+"${paths[@]}"}"; do
    if [ -d "$file" ]; then
      local found
      found=$(find "$file" -name '*.sh' -type f \
        -exec stat -c '%Y %n' {} + 2>/dev/null ||
        find "$file" -name '*.sh' -type f \
          -exec stat -f '%m %N' {} + 2>/dev/null) || true
      checksum="${checksum}${found}"
    elif [ -f "$file" ]; then
      local mtime
      mtime=$(stat -c '%Y' "$file" 2>/dev/null ||
        stat -f '%m' "$file" 2>/dev/null) || true
      checksum="${checksum}${mtime} ${file}"
    fi
  done
  echo "$checksum"
}

function bashunit::main::watch_loop() {
  local filter="$1"
  local tag_filter="${2:-}"
  local exclude_tag_filter="${3:-}"
  shift 3

  local IFS=$' \t\n'
  local -a watch_paths=("$@")
  [ -d "src" ] && watch_paths[${#watch_paths[@]}]="src"

  trap 'printf "\n%sWatch mode stopped.%s\n" \
    "${_BASHUNIT_COLOR_SKIPPED}" "${_BASHUNIT_COLOR_DEFAULT}"; \
    exit 0' INT

  local last_checksum=""
  while true; do
    local current_checksum
    current_checksum=$(bashunit::main::watch_get_checksum \
      "${watch_paths[@]}")

    if [ "$current_checksum" != "$last_checksum" ]; then
      last_checksum="$current_checksum"
      bashunit::io::clear_screen
      printf "%s[watch] Running tests...%s\n\n" \
        "${_BASHUNIT_COLOR_SKIPPED}" \
        "${_BASHUNIT_COLOR_DEFAULT}"

      (
        if [ $# -gt 0 ]; then
          bashunit::main::exec_tests \
            "$filter" "$tag_filter" \
            "$exclude_tag_filter" "$@"
        else
          bashunit::main::exec_tests \
            "$filter" "$tag_filter" \
            "$exclude_tag_filter"
        fi
      ) || true

      printf "\n%s[watch] Waiting for changes...%s\n" \
        "${_BASHUNIT_COLOR_SKIPPED}" \
        "${_BASHUNIT_COLOR_DEFAULT}"
    fi
    sleep 1
  done
}

#############################
# Test execution
#############################
