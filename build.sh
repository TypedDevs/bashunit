#!/bin/bash

source src/check_os.sh

mkdir -p bin
output_file="bin/bashunit"

echo '#!/usr/bin/env bash' > bin/temp.sh

echo "Generating bashunit in the 'bin' folder..."
cat src/*.sh >> bin/temp.sh
cat bashunit >> bin/temp.sh
grep -v '^source' bin/temp.sh > "$output_file"
rm bin/temp.sh
chmod u+x "$output_file"

if [[ "$_OS" == "OSX" ]]; then
  checksum=$(shasum -a 256 $output_file)
  echo "$checksum" > bin/checksum
  echo "$checksum"
fi

echo "⚡️Build completed⚡️"
