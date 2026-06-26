#!/usr/bin/env bash

ROOT_DIR=""

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}

function src_files_sourced_by_entrypoint() {
  # Dev-only helpers under src/dev/ are intentionally excluded from the build.
  grep -oE 'src/[a-zA-Z0-9_/]+\.sh' "$ROOT_DIR/bashunit" | grep -v '^src/dev/' | sort -u
}

function src_files_in_build() {
  grep -oE 'src/[a-zA-Z0-9_/]+\.sh' "$ROOT_DIR/build.sh" | sort -u
}

# Every src file the dev entrypoint sources (except dev-only helpers) must also be
# bundled by build.sh, otherwise its functions are missing from the distributable
# single-file binary (regressions: bench #0.31.0, watch #735).
function test_build_bundles_every_src_file_sourced_by_entrypoint() {
  local missing
  missing=$(comm -23 <(src_files_sourced_by_entrypoint) <(src_files_in_build))

  assert_empty "$missing"
}

function test_built_binary_defines_watch_run() {
  local build_dir
  build_dir=$(bashunit::temp_dir)

  (cd "$ROOT_DIR" && bash build.sh "$build_dir") >/dev/null 2>&1

  assert_file_exists "$build_dir/bashunit"
  assert_equals "1" "$(grep -c 'function bashunit::watch::run()' "$build_dir/bashunit")"
}
