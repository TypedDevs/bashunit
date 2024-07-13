#!/bin/bash

source src/check_os.sh

function generate_bin() {
  local output_file=$1
  local temp=bin/temp.sh
  echo '#!/bin/bash' > "$temp"

  echo "Generating bashunit in the '$(dirname "$output_file")' folder..."
  for file in src/*.sh; do
    {
      echo "# $file"
      tail -n +2 "$file" >> "$temp"
      echo ""
    } >> "$temp"
  done

  cat bashunit >> "$temp"
  grep -v '^source' "$temp" > "$output_file"
  rm "$temp"
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

function build() {
  generate_bin "$1"
  generate_checksum "$1"
  echo "⚡️Build completed⚡️"
}

########################
######### MAIN #########
########################

DIR=${1:-bin}
mkdir -p "$DIR"
output_file="$DIR/bashunit"

build "$output_file"
