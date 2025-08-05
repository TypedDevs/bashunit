#!/usr/bin/env bash

function upgrade::upgrade() {
  local script_path
  script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local latest_tag
  latest_tag="$(helper::get_latest_tag)"

  if [[ "$BASHUNIT_VERSION" == "$latest_tag" ]]; then
    echo "> You are already on latest version"
    return
  fi

  echo "> Upgrading bashunit to latest version"
  cd "$script_path" || exit

  if ! io::download_to  "https://github.com/TypedDevs/bashunit/releases/download/$latest_tag/bashunit" "bashunit"; then
    echo "Failed to download bashunit"
  fi

  chmod u+x "bashunit"

  echo "> bashunit upgraded successfully to latest version $latest_tag"
}
