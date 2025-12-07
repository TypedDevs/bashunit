#!/usr/bin/env bash

function bashunit::io::download_to() {
  local url="$1"
  local output="$2"
  if bashunit::dependencies::has_curl; then
    curl -L -J -o "$output" "$url" 2>/dev/null
  elif bashunit::dependencies::has_wget; then
    wget -q -O "$output" "$url" 2>/dev/null
  else
    return 1
  fi
}
