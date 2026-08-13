#!/usr/bin/env bash

ROOT_DIR=""

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  # Four tests below inspect the same unoptimized artifact and only ever read
  # it, so they built it four times over -- ~0.9s each, and four builds
  # competing for CPU under --parallel. Build it once for the file.
  SHARED_BUILD_DIR="$(bashunit::temp_dir shared_build)"
  build_unoptimized "$SHARED_BUILD_DIR" >/dev/null 2>&1
}

function src_files_sourced_by_entrypoint() {
  # Anchored on `^source ` like build::dependencies is, not on anything
  # path-shaped anywhere in the file: a comment mentioning a src/ path used to
  # register here as a bundled dependency and fail this contract for no reason.
  # Dev-only helpers under src/dev/ are intentionally excluded from the build.
  grep '^source ' "$ROOT_DIR/bashunit" |
    grep -oE 'src/[a-zA-Z0-9_/]+\.sh' | grep -v '^src/dev/' | sort -u
}

function build_dependencies() {
  (cd "$ROOT_DIR" && bash -c 'source ./build.sh && build::dependencies')
}

function build_unoptimized() {
  (cd "$ROOT_DIR" && _BASHUNIT_BUILD_SKIP_COMMENT_STRIP=true bash build.sh "$1")
}

function build_optimizer_is_available() {
  command -v shfmt >/dev/null 2>&1 && command -v jq >/dev/null 2>&1
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
  assert_contains "src/benchmark/index.sh" "$(build_dependencies)"
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

function test_build_strip_comments_preserves_heredocs_shebang_and_source_markers() {
  if ! build_optimizer_is_available; then
    bashunit::skip "shfmt and jq are required for standalone optimization"
    return
  fi

  local file
  file=$(bashunit::temp_file)
  cat >"$file" <<'EOF'
#!/usr/bin/env bash
# src/example.sh
# ordinary source comment
value="# quoted value"
cat <<'DOC'
# Markdown heading
  # indented example comment
DOC
printf '%s\n' "$value" # inline source comment
EOF

  (cd "$ROOT_DIR" && bash -c 'source ./build.sh && build::strip_comments "$1"' _ "$file")

  assert_same "#!/usr/bin/env bash" "$(head -n 1 "$file")"
  assert_file_contains "$file" "# src/example.sh"
  assert_file_not_contains "$file" "ordinary source comment"
  assert_file_not_contains "$file" "inline source comment"
  assert_file_contains "$file" '# Markdown heading'
  assert_file_contains "$file" '  # indented example comment'
  assert_file_contains "$file" 'value="# quoted value"'
  local exit_code=0
  bash -n "$file" || exit_code=$?
  assert_equals 0 "$exit_code"
}

# build::process_file emits a file's body and *then* recurses into its `source`
# lines, so an aggregator holding anything else at top level would run that code
# before its dependencies in the built binary but after them in dev mode.
#
# Discovered by glob, never by a hand-maintained list: the previous list named
# src/assertions.sh and src/runner.sh, and src/coverage.sh was added in #928
# without being appended, so the rule silently stopped covering it. Every
# aggregator is now src/<module>/index.sh (ADR-010), so the glob covers them all
# -- src/assertions.sh was the last flat-file exception and became
# src/assert/index.sh in #940.
function build_aggregators() {
  local index
  for index in "$ROOT_DIR"/src/*/index.sh; do
    [ -f "$index" ] || continue
    echo "${index#"$ROOT_DIR"/}"
  done
}

function test_module_aggregators_hold_only_source_lines_and_comments() {
  local offenders=""
  local aggregator
  while IFS= read -r aggregator; do
    if grep -qvE '^[[:space:]]*(#|source |$)' "$ROOT_DIR/$aggregator"; then
      offenders="$offenders $aggregator"
    fi
  done < <(build_aggregators)

  assert_empty "$offenders"
}

# The glob above is only a safety net if it actually finds the modules.
function test_module_aggregator_discovery_finds_every_module() {
  local found
  found=$(build_aggregators | tr '\n' ' ')

  assert_contains "src/runner/index.sh" "$found"
  assert_contains "src/coverage/index.sh" "$found"
  assert_contains "src/assert/index.sh" "$found"
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

  assert_equals "1" "$(grep -cFx "# $dir/common.sh" "$dir/out.tmp")"
}

# build::dependencies yields repo-relative paths while the recursion yields absolute
# ones, so the dedupe must normalise both spellings or a cross-module source bundles
# the same file twice (duplicate function definitions in the distributable).
function test_build_process_file_embeds_a_file_only_once_across_relative_and_absolute_paths() {
  local dir
  dir=$(bashunit::temp_dir)
  mkdir -p "$dir/src"
  printf '#!/usr/bin/env bash\nsource "$BASHUNIT_ROOT_DIR/src/common.sh"\n' >"$dir/src/a.sh"
  printf '#!/usr/bin/env bash\nfunction common_fn() { :; }\n' >"$dir/src/common.sh"

  (cd "$ROOT_DIR" && bash -c '
    source ./build.sh
    BASHUNIT_ROOT_DIR="$1"
    cd "$1" || exit 1
    build::process_file "src/a.sh" out.tmp
    build::process_file "src/common.sh" out.tmp
  ' _ "$dir") >/dev/null 2>&1

  assert_equals "1" "$(grep -c 'function common_fn()' "$dir/out.tmp")"
}

# A basename marker collides across directories, which both hides a genuine
# duplicate and reports a false one for two distinct files.
function test_build_process_file_marks_same_basename_files_in_different_dirs_distinctly() {
  local dir
  dir=$(bashunit::temp_dir)
  mkdir -p "$dir/src/mod"
  printf '#!/usr/bin/env bash\nsource "$BASHUNIT_ROOT_DIR/src/mod/parallel.sh"\n' >"$dir/src/parallel.sh"
  printf '#!/usr/bin/env bash\nfunction mod_parallel_fn() { :; }\n' >"$dir/src/mod/parallel.sh"

  (cd "$ROOT_DIR" && bash -c '
    source ./build.sh
    BASHUNIT_ROOT_DIR="$1"
    cd "$1" || exit 1
    build::process_file "src/parallel.sh" out.tmp
  ' _ "$dir") >/dev/null 2>&1

  assert_equals "1" "$(grep -cFx '# src/parallel.sh' "$dir/out.tmp")"
  assert_equals "1" "$(grep -cFx '# src/mod/parallel.sh' "$dir/out.tmp")"
}

# A three-level module tree: aggregator -> nested aggregator -> leaf in a
# sub-subdirectory. Echoes the fixture root.
function build_nested_module_fixture() {
  local dir
  dir=$(bashunit::temp_dir)
  mkdir -p "$dir/src/mod/deep"
  printf '#!/usr/bin/env bash\nsource "$BASHUNIT_ROOT_DIR/src/mod/mid.sh"\n' >"$dir/src/mod.sh"
  printf '#!/usr/bin/env bash\nsource "$BASHUNIT_ROOT_DIR/src/mod/deep/leaf.sh"\n' >"$dir/src/mod/mid.sh"
  printf '#!/usr/bin/env bash\nfunction deep_leaf_fn() { :; }\n' >"$dir/src/mod/deep/leaf.sh"
  echo "$dir"
}

function build_process_fixture_root() {
  (cd "$ROOT_DIR" && bash -c '
    source ./build.sh
    BASHUNIT_ROOT_DIR="$1"
    cd "$1" || exit 1
    build::process_file "src/mod.sh" out.tmp
  ' _ "$1") >/dev/null 2>&1
}

# build::process_file walks `source` statements, not directories, so nesting
# depth is invisible to it. Module directories may therefore nest freely
# (adrs/adr-010-src-module-directories.md); without this test nothing says so.
function test_build_process_file_embeds_modules_nested_at_any_depth() {
  local dir
  dir=$(build_nested_module_fixture)

  build_process_fixture_root "$dir"

  assert_equals "1" "$(grep -cFx '# src/mod.sh' "$dir/out.tmp")"
  assert_equals "1" "$(grep -cFx '# src/mod/mid.sh' "$dir/out.tmp")"
  assert_equals "1" "$(grep -cFx '# src/mod/deep/leaf.sh' "$dir/out.tmp")"
  assert_equals "1" "$(grep -c 'function deep_leaf_fn()' "$dir/out.tmp")"
}

# The ordering contract behind the "aggregators hold only source lines" rule: a
# file's own body is emitted *before* the bodies of the files it sources. Were it
# reversed, an aggregator's statements would run after its dependencies in the
# built binary but before them in dev mode.
function test_build_process_file_emits_a_file_before_the_files_it_sources() {
  local dir
  dir=$(build_nested_module_fixture)

  build_process_fixture_root "$dir"

  local order
  order=$(grep -oE '^# src/[a-z/]+\.sh$' "$dir/out.tmp" | tr '\n' '|')

  assert_same "# src/mod.sh|# src/mod/mid.sh|# src/mod/deep/leaf.sh|" "$order"
}

# The embed dedupe keys on the repo-relative path (#923). Two modules holding the
# same basename must both survive -- the situation every further module split
# creates (src/config/parallel.sh vs src/runner/parallel.sh today).
function test_build_process_file_embeds_same_basename_from_two_module_dirs() {
  local dir
  dir=$(bashunit::temp_dir)
  mkdir -p "$dir/src/one" "$dir/src/two"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'source "$BASHUNIT_ROOT_DIR/src/one/helpers.sh"\n'
    printf 'source "$BASHUNIT_ROOT_DIR/src/two/helpers.sh"\n'
  } >"$dir/src/root.sh"
  printf '#!/usr/bin/env bash\nfunction one_helpers_fn() { :; }\n' >"$dir/src/one/helpers.sh"
  printf '#!/usr/bin/env bash\nfunction two_helpers_fn() { :; }\n' >"$dir/src/two/helpers.sh"

  (cd "$ROOT_DIR" && bash -c '
    source ./build.sh
    BASHUNIT_ROOT_DIR="$1"
    cd "$1" || exit 1
    build::process_file "src/root.sh" out.tmp
  ' _ "$dir") >/dev/null 2>&1

  assert_equals "1" "$(grep -c 'function one_helpers_fn()' "$dir/out.tmp")"
  assert_equals "1" "$(grep -c 'function two_helpers_fn()' "$dir/out.tmp")"
}

# The distributable is one flat script: every `source` line is stripped, so a
# surviving one would try to read a src/ tree the installed binary does not ship
# with (regressions: bench #0.31.0, watch #735).
function test_built_binary_contains_no_source_lines() {
  local build_dir=$SHARED_BUILD_DIR

  assert_file_exists "$build_dir/bashunit"
  assert_equals "0" "$(grep -c '^source ' "$build_dir/bashunit")"
}

# The budget is a guard against the artifact growing without anyone noticing,
# not a hard product limit. It was raised from 512000 to 557056 (544 KiB) in
# #1045, to 589824 (576 KiB) in #1022, and to 622592 (608 KiB) in #1029, as the
# bench reports and the baseline gate landed (590355 bytes measured). The #1045
# alternatives to raising it were both worse:
#
#   as-is                518493 bytes   over
#   strip blank lines    515249 bytes   still over — and unsafe, because a blank
#                                       line inside a heredoc is content (#990)
#   shfmt --minify       471673 bytes   reaches it, by stripping every bit of
#                                       indentation out of the shipped artifact
#
# So: keep the artifact readable and move the line, with headroom for a few more
# features. Raise it deliberately and record the number again when it is hit —
# do not silence it.
#
# Raised again to 655360 (640 KiB) after the coverage rewrite: the report phase
# and the capture path grew several embedded awk programs (#1084, #1088, #1090,
# #1096, #1098, #1099), which are code and survive the comment strip. Measured
# 622526 bytes at that point — 66 bytes under the old line, so the next change
# of any size would have tripped it.
#
# Note this check needs shfmt and jq, and skips without them. It runs in the
# Build & Verify workflow, which installs shfmt; the copy of the suite in the
# Tests workflow skips it, as does a contributor without those tools. So a
# green local run is not evidence the artifact is inside the budget (#1125).
function test_built_binary_stays_below_640_kib() {
  if ! build_optimizer_is_available; then
    bashunit::skip "shfmt and jq are required for standalone optimization"
    return
  fi

  local build_dir
  build_dir=$(bashunit::temp_dir)

  (cd "$ROOT_DIR" && bash build.sh "$build_dir") >/dev/null 2>&1

  local bytes
  bytes=$(wc -c <"$build_dir/bashunit" | tr -d ' ')
  assert_less_or_equal_than 655360 "$bytes"
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
  local build_dir=$SHARED_BUILD_DIR

  assert_file_exists "$build_dir/bashunit"
  assert_equals "1" "$(grep -c 'function bashunit::watch::run()' "$build_dir/bashunit")"
}

function test_built_binary_embeds_each_src_file_exactly_once() {
  local build_dir=$SHARED_BUILD_DIR

  local duplicated
  duplicated=$(grep -E '^# src/[a-z_0-9/]+\.sh$' "$build_dir/bashunit" | sort | uniq -d)

  assert_empty "$duplicated"
}

# The marker guard above only catches a file embedded twice under the *same*
# spelling; this one catches the symptom directly, whatever the cause.
function test_built_binary_defines_each_bashunit_function_exactly_once() {
  local build_dir=$SHARED_BUILD_DIR

  # Scoped to the bashunit:: namespace on purpose: an unqualified `^function `
  # also matches the example code inside the embedded docs/assertions.md heredoc.
  local duplicated
  duplicated=$(grep -oE '^function bashunit::[a-zA-Z_:]+\(\)' "$build_dir/bashunit" | sort | uniq -d)

  assert_empty "$duplicated"
}
