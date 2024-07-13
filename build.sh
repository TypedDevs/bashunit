#!/bin/bash

source src/check_os.sh

function build() {
  local out=$1

  generate_bin "$out"
  generate_checksum "$out"

  echo "⚡️Build completed⚡️"
}

function verify_build() {
  local out=$1

  echo "Verifying build ⏱️"

  "$out" tests --simple \
    --log-junit="build.xml" \
    --export-html=build.html \
    --stop-on-failure

  echo "✅ Build verified ✅"
}

function generate_bin() {
  local out=$1
  local temp
  temp="$(dirname "$out")/temp.sh"

  echo '#!/bin/bash' > "$temp"
  echo "Generating bashunit in the '$(dirname "$out")' folder..."
  for file in src/*.sh; do
    {
      echo "# $file"
      tail -n +2 "$file" >> "$temp"
      echo ""
    } >> "$temp"
  done

  cat bashunit >> "$temp"
  grep -v '^source' "$temp" > "$out"
  rm "$temp"
  chmod u+x "$out"
}

function generate_checksum() {
  local out=$1

  if [[ "$_OS" == "Windows" ]]; then
    return
  fi

  if [[ "$_OS" == "OSX" ]]; then
    checksum=$(shasum -a 256 "$out")
  elif [[ "$_OS" == "Linux" ]]; then
    checksum=$(sha256sum "$out")
  fi

  echo "$checksum" > "$(dirname "$out")/checksum"
  echo "$checksum"
}


########################
######### MAIN #########
########################

DIR="bin"
SHOULD_VERIFY_BUILD=true

for arg in "$@"; do
  case $arg in
    --ignore-verify)
      SHOULD_VERIFY_BUILD=false
      ;;
    *)
      DIR=$arg
      ;;
  esac
done

mkdir -p "$DIR"
OUT="$DIR/bashunit"

build "$OUT"

if [[ $SHOULD_VERIFY_BUILD == true ]]; then
  verify_build "$OUT"
fi
