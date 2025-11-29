#!/usr/bin/env bash

source src/check_os.sh

BASHUNIT_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BASHUNIT_ROOT_DIR

function build() {
  local out=$1

  build::generate_bin "$out"
  build::generate_checksum "$out"

  echo "⚡️ Build completed ⚡️"
}

function build::verify() {
  local out=$1

  echo "Verifying build ⏱️"

  "$out" tests \
    --simple \
    --parallel \
    --log-junit "bin/log-junit.xml" \
    --report-html "bin/report.html" \
    --stop-on-failure

  # shellcheck disable=SC2181
  if [[ $? -eq 0 ]]; then
    echo "✅ Build verified ✅"
  fi
}

function build::generate_bin() {
  local out=$1
  local temp
  temp="$(dirname "$out")/temp.sh"

  echo '#!/usr/bin/env bash' > "$temp"
  echo "Generating bashunit in the '$(dirname "$out")' folder..."

  for file in $(build::dependencies); do
    build::process_file "$file" "$temp"
  done

  cat bashunit >> "$temp"
  grep -v '^source' "$temp" > "$out"
  rm "$temp"
  chmod u+x "$out"

  # Embed the assertions.md docs into the binary
  build::embed_docs "$out"
}

# Recursive function to process each file and any files it sources
function build::process_file() {
  local file=$1
  local temp=$2

  {
    echo "# $(basename "$file")"
    tail -n +2 "$file" >> "$temp"
    echo ""
  } >> "$temp"

  # Search for any 'source' lines in the current file
  grep '^source ' "$file" | while read -r line; do
    # Extract the path from the 'source' command
    local sourced_file
    sourced_file=$(echo "$line" | awk '{print $2}' | sed 's/^"//;s/"$//') # Remove any quotes

    # Handle cases where the path uses $BASHUNIT_ROOT_DIR or other variables
    sourced_file=$(eval echo "$sourced_file")

    # Handle relative paths if necessary
    if [[ ! "$sourced_file" =~ ^/ ]]; then
      sourced_file="$(dirname "$file")/$sourced_file"
    fi

    # Recursively process the sourced file if it exists
    if [[ -f "$sourced_file" ]]; then
      build::process_file "$sourced_file" "$temp"
    fi
  done
}

function build::dependencies() {
  deps=(
    "src/check_os.sh"
    "src/str.sh"
    "src/globals.sh"
    "src/dependencies.sh"
    "src/io.sh"
    "src/math.sh"
    "src/parallel.sh"
    "src/env.sh"
    "src/clock.sh"
    "src/state.sh"
    "src/colors.sh"
    "src/console_header.sh"
    "src/console_results.sh"
    "src/helpers.sh"
    "src/test_title.sh"
    "src/upgrade.sh"
    "src/assertions.sh"
    "src/reports.sh"
    "src/runner.sh"
    "src/init.sh"
    "src/learn.sh"
    "src/doc.sh"
    "src/bashunit.sh"
    "src/main.sh"
  )

  echo "${deps[@]}"
}

function build::embed_docs() {
  local file=$1
  local docs_file="docs/assertions.md"
  local temp_file="${file}.tmp"

  # Build the replacement content
  {
    # Print everything before the start marker (excluding the marker line)
    local line_num
    line_num=$(grep -n "# __BASHUNIT_EMBEDDED_DOCS_START__" "$file" | cut -d: -f1)
    head -n "$((line_num - 1))" "$file"

    # Print the heredoc with embedded docs
    echo "  cat <<'__BASHUNIT_DOCS_EOF__'"
    cat "$docs_file"
    echo "__BASHUNIT_DOCS_EOF__"

    # Print everything after the end marker
    sed -n '/# __BASHUNIT_EMBEDDED_DOCS_END__/,$p' "$file" | tail -n +2
  } > "$temp_file"

  mv "$temp_file" "$file"
  chmod u+x "$file"
}

function build::generate_checksum() {
  local out=$1

  if [[ "$_OS" == "Windows" ]]; then
    return
  fi

  # Use a single command for both macOS and Linux
  if command -v shasum &>/dev/null; then
    checksum=$(shasum -a 256 "$out")
  else
    checksum=$(sha256sum "$out")
  fi

  echo "$checksum" > "$(dirname "$out")/checksum"
  echo "$checksum"
}

########################
######### MAIN #########
########################

DIR="bin"
SHOULD_VERIFY_BUILD=false

for arg in "$@"; do
  case $arg in
    -v|--verify)
      SHOULD_VERIFY_BUILD=true
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
  build::verify "$OUT"
fi
