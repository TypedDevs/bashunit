#!/bin/bash

# shellcheck disable=SC2034
_OS="Unknown"

if [[ "$(uname)" == "Linux" ]]; then
  _OS="Linux"
elif [[ "$(uname)" == "Darwin" ]]; then
  _OS="OSX"
elif [[ $(uname) == *"MINGW"* ]]; then
  _OS="Windows"
fi
