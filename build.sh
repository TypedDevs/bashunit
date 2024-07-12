#!/bin/bash

source src/check_os.sh

function generate_bin() {
  local output_file=$1
  echo '#!/usr/bin/env bash' > bin/temp.sh

  echo "Generating bashunit in the 'bin' folder..."
  cat src/*.sh >> bin/temp.sh
  cat bashunit >> bin/temp.sh
  grep -v '^source' bin/temp.sh > "$output_file"
  rm bin/temp.sh
  chmod u+x "$output_file"
}

function generate_checksum() {
  if [[ "$_OS" == "Windows" ]]; then
    return
  fi

  local file=$1
  if [[ "$_OS" == "OSX" ]]; then
    checksum=$(shasum -a 256 "$file")
  elif [[ "$_OS" == "Linux" ]]; then
    checksum=$(sha256sum "$file")
  fi

  echo "$checksum" > bin/checksum
  echo "$checksum"
}

########################
######### MAIN #########
########################

mkdir -p bin
output_file="bin/bashunit"

generate_bin "$output_file"
generate_checksum "$output_file"

echo "⚡️Build completed⚡️"
