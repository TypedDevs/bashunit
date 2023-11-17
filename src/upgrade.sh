#!/bin/bash

function upgrade::upgrade() {
  local script_path
  local latest_tag

  script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  latest_tag="$(helpers::get_latest_tag)"

  if [[ $BASHUNIT_VERSION == "$latest_tag" ]]; then
    echo "> You are already on latest release"
    return
  fi

  echo "> Upgrading bashunit to latest release"
  cd "$script_path" || exit
  curl  -L -J -o bashunit "https://github.com/TypedDevs/bashunit/releases/download/$latest_tag/bashunit" 2>/dev/null
  chmod u+x "bashunit"

  echo "> bashunit upgraded successfully to latest version $BASHUNIT_VERSION"
}
