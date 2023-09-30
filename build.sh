#!/bin/bash

mkdir -p bin

cat src/*.sh > bin/temp.sh
cat bashunit >> bin/temp.sh
grep -v '^source' bin/temp.sh > bin/bashunit
rm bin/temp.sh

chmod +x bin/bashunit

echo "Build complete. bashunit has been generated in the bin folder."
