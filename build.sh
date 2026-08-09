#!/usr/bin/env bash
set -euo pipefail

source src/system/check_os.sh
bashunit::check_os::init

BASHUNIT_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BASHUNIT_ROOT_DIR

# Files already embedded by build::process_file, keyed by repo-relative path.
# Without the dedupe a cross-module source would bundle a file twice (duplicate
# function definitions and double top-level execution).
_BUILD_EMBEDDED_FILES=""

function build() {
  local out=$1

  build::generate_bin "$out"
  build::generate_checksum "$out"

  echo "⚡️ Build completed ⚡️"
}

function build::verify() {
  local out=$1
  local out_dir
  out_dir="$(dirname "$out")"

  echo "Verifying build ⏱️"

  if ! BASHUNIT_BUILD_DIR="$out_dir" "$out" tests \
    --simple \
    --parallel \
    --log-junit "$out_dir/log-junit.xml" \
    --report-html "$out_dir/report.html" \
    --stop-on-failure; then
    echo "❌ Build verification failed" >&2
    exit 1
  fi

  echo "✅ Build verified ✅"
}

function build::generate_bin() {
  local out=$1
  local temp
  temp="$(dirname "$out")/temp.$$.sh"

  echo '#!/usr/bin/env bash' >"$temp"
  echo "Generating bashunit in the '$(dirname "$out")' folder..."

  local file
  for file in $(build::dependencies); do
    build::process_file "$file" "$temp"
  done

  cat bashunit >>"$temp"
  grep -v '^source ' "$temp" >"$out"
  rm "$temp"
  chmod u+x "$out"

  # Embed the assertions.md docs into the binary
  build::embed_docs "$out"

  # Keep the source tree documented without shipping those comments in every
  # standalone binary. A shell parser is required here: the built file contains
  # heredocs whose Markdown and example scripts legitimately start with `#`.
  # Structural build tests use the raw form so platforms without release-tool
  # dependencies still exercise bundling; release builds always take this path.
  if [[ ${_BASHUNIT_BUILD_SKIP_COMMENT_STRIP:-false} != true ]]; then
    build::strip_comments "$out"
  fi

  build::assert_valid_syntax "$out"
}

# Recursive function to process each file and any files it sources
function build::process_file() {
  local file=$1
  local temp=$2

  # Key the dedupe and the marker on a repo-relative path, never a basename: the
  # top-level loop passes `src/x.sh` while the recursion passes an absolute path,
  # and two modules can hold the same basename (src/config/parallel.sh vs
  # src/runner/parallel.sh). `$file` itself stays untouched so the `tail` and
  # `dirname` below work on whichever form the caller passed.
  local marker="${file#"$BASHUNIT_ROOT_DIR"/}"

  case " $_BUILD_EMBEDDED_FILES " in
  *" $marker "*) return ;;
  esac
  _BUILD_EMBEDDED_FILES="$_BUILD_EMBEDDED_FILES $marker"

  {
    echo "# $marker"
    tail -n +2 "$file"
    echo ""
  } >>"$temp"

  # Recurse into any 'source' lines of the current file. Process substitution
  # (not a pipe) keeps the loop in this shell so _BUILD_EMBEDDED_FILES persists.
  local line
  while read -r line; do
    local sourced_file
    sourced_file=$(echo "$line" | awk '{print $2}' | sed 's/^"//;s/"$//') # Remove any quotes

    # Expand the literal $BASHUNIT_ROOT_DIR prefix without eval
    sourced_file="${sourced_file/\$BASHUNIT_ROOT_DIR/$BASHUNIT_ROOT_DIR}"

    # Handle relative paths if necessary. Strip a leading `./` first, or each
    # recursion level appends another `/.` segment and the same file reaches the
    # dedupe under two spellings.
    local _absolute_path_pattern='^/'
    if [[ ! "$sourced_file" =~ $_absolute_path_pattern ]]; then
      sourced_file="$(dirname "$file")/${sourced_file#./}"
    fi

    # Recursively process the sourced file if it exists
    if [[ -f "$sourced_file" ]]; then
      build::process_file "$sourced_file" "$temp"
    fi
  done < <(grep '^source ' "$file" || true)
}

# The embed list is derived from the entrypoint's own source order: a single
# source of truth, so a src file added to the entrypoint can never be missing
# from the distributable (regressions: bench #0.31.0, watch #735).
function build::dependencies() {
  grep '^source ' bashunit \
    | sed -e 's|^source "\$BASHUNIT_ROOT_DIR/||' -e 's|"$||' \
    | grep -v '^src/dev/'
}

function build::embed_docs() {
  local file=$1
  local docs_file="docs/assertions.md"
  local temp_file="${file}.tmp"

  local start_line
  start_line=$(grep -n "# __BASHUNIT_EMBEDDED_DOCS_START__" "$file" | cut -d: -f1 | head -n 1) || true
  if [[ -z "$start_line" ]]; then
    echo "❌ Embed marker __BASHUNIT_EMBEDDED_DOCS_START__ not found in $file" >&2
    exit 1
  fi
  if ! grep -q "# __BASHUNIT_EMBEDDED_DOCS_END__" "$file"; then
    echo "❌ Embed marker __BASHUNIT_EMBEDDED_DOCS_END__ not found in $file" >&2
    exit 1
  fi

  # Build the replacement content
  {
    # Print everything before the start marker (excluding the marker line)
    head -n "$((start_line - 1))" "$file"

    # Print the heredoc with embedded docs
    echo "  cat <<'__BASHUNIT_DOCS_EOF__'"
    cat "$docs_file"
    echo "__BASHUNIT_DOCS_EOF__"

    # Print everything after the end marker
    sed -n '/# __BASHUNIT_EMBEDDED_DOCS_END__/,$p' "$file" | tail -n +2
  } >"$temp_file"

  mv "$temp_file" "$file"
  chmod u+x "$file"
}

function build::strip_comments() {
  local file=$1
  local temp_file="${file}.tmp"

  local dependency
  for dependency in shfmt jq; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
      echo "❌ $dependency is required to build the standalone binary" >&2
      return 1
    fi
  done

  # shfmt distinguishes real shell comments from `#` text inside heredocs. Keep
  # the executable shebang and the tiny source-boundary markers: they make the
  # flattened artifact navigable and let the build tests detect duplicate
  # embeds. Everything else remains available in the repository source.
  local jq_filter='walk(
    if type == "object" and has("Comments") then
      .Comments |= map(select(
        ((.Text // "") | startswith("!")) or
        ((.Text // "") | test("^ src/.*\\.sh$"))
      ))
    else . end
  )'
  if ! shfmt -ln=bash --to-json <"$file" \
    | jq "$jq_filter" \
    | shfmt -i 2 --from-json >"$temp_file"; then
    rm -f "$temp_file"
    echo "❌ Failed to strip comments from $file" >&2
    return 1
  fi

  mv "$temp_file" "$file"
  chmod u+x "$file"
}

function build::assert_valid_syntax() {
  local file=$1

  if ! bash -n "$file"; then
    echo "❌ Generated artifact failed bash -n syntax check: $file" >&2
    exit 1
  fi
}

function build::generate_checksum() {
  local out=$1

  if [[ "$_BASHUNIT_OS" == "Windows" ]]; then
    return
  fi

  # Use a single command for both macOS and Linux
  if command -v shasum &>/dev/null; then
    checksum=$(shasum -a 256 "$out")
  else
    checksum=$(sha256sum "$out")
  fi

  echo "$checksum" >"$(dirname "$out")/checksum"
  echo "$checksum"
}

########################
######### MAIN #########
########################

# Skip when sourced (tests source this file to exercise the functions above)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  DIR="bin"
  SHOULD_VERIFY_BUILD=false
  SHOULD_CLEANUP=false

  for arg in "$@"; do
    case $arg in
    -v | --verify)
      SHOULD_VERIFY_BUILD=true
      ;;
    -c | --cleanup)
      SHOULD_CLEANUP=true
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

  if [[ $SHOULD_CLEANUP == true ]]; then
    echo "🧹 Cleaning up build directory: $DIR"
    rm -rf "$DIR"
  fi
fi
