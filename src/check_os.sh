#!/bin/bash

OS="Unknown"

if [ "$(uname)" == "Linux" ]; then
    OS="Linux"
elif [ "$(uname)" == "Darwin" ]; then
    OS="OSX"
elif [[ $(uname) == *"MINGW"* ]]; then
    OS="Windows"
fi
