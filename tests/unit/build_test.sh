#!/usr/bin/env bash

ROOT_DIR=""

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}

function src_files_sourced_by_entrypoint() {
  # Dev-only helpers under src/dev/ are intentionally excluded from the build.
  grep -oE 'src/[a-zA-Z0-9_/]+\.sh' "$ROOT_DIR/bashunit" | grep -v '^src/dev/' | sort -u
}

function build_dependencies() {
  (cd "$ROOT_DIR" && bash -c 'source ./build.sh && build::dependencies')
}

# Every src file the dev entrypoint sources (except dev-only helpers) must also be
# bundled by build.sh, otherwise its functions are missing from the distributable
# single-file binary (regressions: bench #0.31.0, watch #735).
function test_build_bundles_every_src_file_sourced_by_entrypoint() {
  local missing
  missing=$(comm -23 <(src_files_sourced_by_entrypoint) <(build_dependencies | sort -u))

  assert_empty "$missing"
}

# The reverse direction: the build must not bundle files the entrypoint does not
# source (a stale hand-maintained list shipped benchmark.sh while dev mode lacked
# it — the two must stay a single source of truth).
function test_build_bundles_only_files_sourced_by_entrypoint() {
  local extra
  extra=$(comm -13 <(src_files_sourced_by_entrypoint) <(build_dependencies | sort -u))

  assert_empty "$extra"
}

function test_build_dependencies_include_benchmark() {
  assert_contains "src/benchmark.sh" "$(build_dependencies)"
}

function test_build_script_is_sourceable_without_running_a_build() {
  local output
  output=$(cd "$ROOT_DIR" && bash -c 'source ./build.sh && declare -F build::verify' 2>&1)

  assert_not_contains "Generating" "$output"
  assert_contains "build::verify" "$output"
}

function test_build_verify_exits_nonzero_when_suite_fails() {
  local fake_dir
  fake_dir=$(bashunit::temp_dir)
  printf '#!/usr/bin/env bash\nexit 1\n' >"$fake_dir/bashunit"
  chmod +x "$fake_dir/bashunit"

  local exit_code=0
  (cd "$ROOT_DIR" && bash -c 'source ./build.sh && build::verify "$1"' _ "$fake_dir/bashunit") \
    >/dev/null 2>&1 || exit_code=$?

  assert_not_equals 0 "$exit_code"
}

function test_build_verify_succeeds_when_suite_passes() {
  local fake_dir
  fake_dir=$(bashunit::temp_dir)
  printf '#!/usr/bin/env bash\nexit 0\n' >"$fake_dir/bashunit"
  chmod +x "$fake_dir/bashunit"

  local output
  local exit_code=0
  output=$(cd "$ROOT_DIR" && bash -c 'source ./build.sh && build::verify "$1"' _ "$fake_dir/bashunit" 2>&1) \
    || exit_code=$?

  assert_equals 0 "$exit_code"
  assert_contains "verified" "$output"
}

function test_build_embed_docs_fails_on_missing_markers() {
  local file
  file=$(bashunit::temp_file)
  printf '#!/usr/bin/env bash\necho hi\n' >"$file"

  local exit_code=0
  (cd "$ROOT_DIR" && bash -c 'source ./build.sh && build::embed_docs "$1"' _ "$file") \
    >/dev/null 2>&1 || exit_code=$?

  assert_not_equals 0 "$exit_code"
  # The artifact must not be replaced with a truncated file on failure.
  assert_contains "echo hi" "$(cat "$file")"
}

function test_build_process_file_embeds_a_file_only_once() {
  local dir
  dir=$(bashunit::temp_dir)
  printf '#!/usr/bin/env bash\nsource ./a.sh\nsource ./b.sh\n' >"$dir/root.sh"
  printf '#!/usr/bin/env bash\nsource ./common.sh\n' >"$dir/a.sh"
  printf '#!/usr/bin/env bash\nsource ./common.sh\n' >"$dir/b.sh"
  printf '#!/usr/bin/env bash\nfunction common_fn() { :; }\n' >"$dir/common.sh"

  (cd "$ROOT_DIR" && bash -c 'source ./build.sh && build::process_file "$1" "$2"' _ "$dir/root.sh" "$dir/out.tmp") \
    >/dev/null 2>&1

  assert_equals "1" "$(grep -c '^# common.sh$' "$dir/out.tmp")"
}

function test_build_assert_valid_syntax_rejects_broken_file() {
  local file
  file=$(bashunit::temp_file)
  printf '#!/usr/bin/env bash\nif then fi (\n' >"$file"

  local exit_code=0
  (cd "$ROOT_DIR" && bash -c 'source ./build.sh && build::assert_valid_syntax "$1"' _ "$file") \
    >/dev/null 2>&1 || exit_code=$?

  assert_not_equals 0 "$exit_code"
}

function test_built_binary_defines_watch_run() {
  local build_dir
  build_dir=$(bashunit::temp_dir)

  (cd "$ROOT_DIR" && bash build.sh "$build_dir") >/dev/null 2>&1

  assert_file_exists "$build_dir/bashunit"
  assert_equals "1" "$(grep -c 'function bashunit::watch::run()' "$build_dir/bashunit")"
}

function test_built_binary_embeds_each_src_file_exactly_once() {
  local build_dir
  build_dir=$(bashunit::temp_dir)

  (cd "$ROOT_DIR" && bash build.sh "$build_dir") >/dev/null 2>&1

  local duplicated
  duplicated=$(grep -E '^# [a-z_]+\.sh$' "$build_dir/bashunit" | sort | uniq -d)

  assert_empty "$duplicated"
}
