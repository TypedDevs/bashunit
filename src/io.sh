#!/bin/bash

function io::download_to() {
  local url="$1"
  local output="$2"
  if dependencies::has_curl; then
    curl -L -J -o "$output" "$url" 2>/dev/null
  elif dependencies::has_wget; then
    wget -q -O "$output" "$url" 2>/dev/null
  else
    return 1
  fi
}
