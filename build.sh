#!/bin/bash

mkdir -p bin

output_file="bin/bashunit"

echo '#!/usr/bin/env bash' > bin/temp.sh

echo "Generating bashunit in the 'bin' folder..."
cat src/*.sh >> bin/temp.sh
cat bashunit >> bin/temp.sh
grep -v '^source' bin/temp.sh > "$output_file"
rm bin/temp.sh
chmod u+x "$output_file"

echo "⚡️Build completed⚡️"
