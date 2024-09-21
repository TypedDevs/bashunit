#!/bin/bash

# shellcheck disable=SC2034
_OS="Unknown"

if [[ "$(uname)" == "Linux" ]]; then
    if command -v apt > /dev/null; then
        _OS="Linux - Ubuntu"
    elif command -v apk > /dev/null; then
        _OS="Linux - Alpine"
    else
        _OS="Linux - Other"
    fi
elif [[ "$(uname)" == "Darwin" ]]; then
    _OS="OSX"
elif [[ "$(uname)" == *"MINGW"* ]]; then
    _OS="Windows"
fi
