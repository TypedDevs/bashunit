#!/usr/bin/env bash

# Anti-drift contract for ADR-011's module table.
#
# That table has been wrong twice, both times because it was counted with a
# one-level glob rather than from the tree:
#
#   * `doubles/` was missing outright. The table was generated from the
#     entrypoint's `source` lines, and `doubles/` is the one module the
#     entrypoint does not source -- `assert/index.sh` does -- so it fell through
#     while the prose above it said "seventeen" from a directory count.
#   * `learn/` was listed at 5 files / 240 lines because `src/learn/*.sh` does
#     not descend into `learn/lessons/`, which holds 9 more files.
#
# Neither is visible to a human reading the ADR, which is what makes a test the
# right tool. Checking the file counts *sum* to `src/` catches an under-count in
# any single row without pinning every number to an exact value.

ADR=""
ROOT_DIR=""

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  ADR="$ROOT_DIR/adrs/adr-011-source-layout-and-build-pipeline.md"
}

# Without this, renaming the ADR would make every other assertion here compare
# empty output against empty output and pass while checking nothing -- the
# failure mode that let a layering contract rot unnoticed in #946.
function test_the_adr_being_checked_exists() {
  assert_file_exists "$ADR"
}

function adr_table_modules() {
  grep -E '^\| [0-9]+ \| `[a-z]+/`' "$ADR" |
    sed 's/^| *[0-9]* *| *`\([a-z]*\)\/` *|.*/\1/' | LC_ALL=C sort
}

# Enumerated with `find`, not `git ls-files`: the Bash 3.0 jobs run in a container
# where git refuses to read the repo (dubious-ownership), so `git ls-files` exits
# non-zero and yields nothing -- which reads here as "src/ has no modules" and
# fails for a reason that has nothing to do with the ADR.
function src_modules() {
  (cd "$ROOT_DIR" && find src -name '*.sh' | cut -d/ -f2 | LC_ALL=C sort -u)
}

function test_every_src_module_has_a_row_in_the_adr_table() {
  assert_same "$(src_modules)" "$(adr_table_modules)"
}

function adr_table_file_total() {
  grep -E '^\| [0-9]+ \| `[a-z]+/`' "$ADR" | awk -F'|' '{ sum += $4 } END { print sum + 0 }'
}

function src_file_total() {
  (cd "$ROOT_DIR" && find src -name '*.sh' | wc -l | tr -d ' ')
}

function test_adr_table_file_counts_account_for_every_src_file() {
  assert_same "$(src_file_total)" "$(adr_table_file_total)"
}
