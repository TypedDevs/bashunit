#!/bin/bash

# shellcheck disable=SC2034
_OS="Unknown"
_DISTRO="Unknown"

if [[ "$(uname)" == "Linux" ]]; then
  _OS="Linux"
  if command -v apt > /dev/null; then
    _DISTRO="Ubuntu"
  elif command -v apk > /dev/null; then
    _DISTRO="Alpine"
  else
    _DISTRO="Other"
  fi
elif [[ "$(uname)" == "Darwin" ]]; then
  _OS="OSX"
elif [[ "$(uname)" == *"MINGW"* ]]; then
  _OS="Windows"
fi

export _OS
export _DISTRO
