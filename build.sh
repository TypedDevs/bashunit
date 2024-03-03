#!/bin/bash

mkdir -p bin

echo '#!/usr/bin/env bash' > bin/temp.sh

cat src/*.sh >> bin/temp.sh
cat bashunit >> bin/temp.sh
grep -v '^source' bin/temp.sh > bin/bashunit
rm bin/temp.sh

chmod u+x bin/bashunit

echo "Build complete. bashunit has been generated in the bin folder."
