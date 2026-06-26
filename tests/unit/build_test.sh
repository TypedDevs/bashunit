#!/usr/bin/env bash

ROOT_DIR=""

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}

# Every src file the dev entrypoint sources (except dev-only helpers) must also be
# listed in build::dependencies, otherwise its functions are missing from the
# distributable single-file binary (regressions: bench #0.31.0, watch #735).
function test_build_dependencies_cover_every_sourced_src_file() {
  local entry_sources build_deps missing=""
  entry_sources=$(grep -oE 'src/[a-zA-Z0-9_/]+\.sh' "$ROOT_DIR/bashunit" | grep -v '^src/dev/')
  build_deps=$(grep -oE 'src/[a-zA-Z0-9_/]+\.sh' "$ROOT_DIR/build.sh")

  local file
  for file in $entry_sources; do
    if ! echo "$build_deps" | grep -qx "$file"; then
      missing="$missing $file"
    fi
  done

  assert_empty "$missing"
}

function test_built_binary_defines_watch_run() {
  local out_dir
  out_dir="$(mktemp -d)"

  bash "$ROOT_DIR/build.sh" "$out_dir" >/dev/null 2>&1

  assert_file_exists "$out_dir/bashunit"
  assert_equals "1" "$(grep -c 'function bashunit::watch::run()' "$out_dir/bashunit")"

  rm -rf "$out_dir"
}
