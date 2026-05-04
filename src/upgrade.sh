#!/usr/bin/env bash

function bashunit::upgrade::upgrade() {
  local install_dir="${BASHUNIT_INSTALL_DIR:-}"
  if [ -z "$install_dir" ]; then
    install_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi
  local target="$install_dir/bashunit"

  local latest_tag
  latest_tag="$(bashunit::helper::get_latest_tag)"

  if [ -z "$latest_tag" ]; then
    echo "Failed to resolve latest bashunit version. Check your internet connection and that 'git' is installed." >&2
    return 1
  fi

  if [ "$BASHUNIT_VERSION" = "$latest_tag" ]; then
    echo "> You are already on latest version"
    return 0
  fi

  echo "> Upgrading bashunit to latest version"

  local url="https://github.com/TypedDevs/bashunit/releases/download/$latest_tag/bashunit"
  local err_file
  err_file="$(mktemp 2>/dev/null || echo "/tmp/bashunit_upgrade_err.$$")"
  local download_status=0
  bashunit::io::download_to "$url" "$target" 2>"$err_file" || download_status=$?

  if [ "$download_status" -ne 0 ]; then
    echo "Failed to download bashunit $latest_tag from $url" >&2
    if [ -s "$err_file" ]; then
      echo "Reason:" >&2
      sed 's/^/  /' "$err_file" >&2
    fi
    rm -f "$err_file" "$target"
    return 1
  fi
  rm -f "$err_file"

  if [ ! -s "$target" ]; then
    echo "Failed to download bashunit $latest_tag from $url (empty file)" >&2
    rm -f "$target"
    return 1
  fi

  if ! chmod u+x "$target"; then
    echo "Failed to make $target executable" >&2
    return 1
  fi

  echo "> bashunit upgraded successfully to latest version $latest_tag"
}
