#!/usr/bin/env bash

# Settings and CLI flags are checked against the docs; the assertions never
# were. A new assertion ships in `src/` and nobody notices it is missing from
# the reference page until a user goes looking for it — the same drift that
# left 17 settings undocumented before `docs_parity_test.sh` existed.
#
# Both pages count: the spy and mock assertions live in `docs/test-doubles.md`,
# the rest in `docs/assertions.md`. Checking only the latter reports the whole
# `assert_have_been_called*` family as undocumented, which is how this started.

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  DOC_PAGES="$ROOT_DIR/docs/assertions.md $ROOT_DIR/docs/test-doubles.md"
}

# Public assertions: `function assert_x()` anywhere under src/. The namespaced
# `bashunit::assert::*` helpers are internal and deliberately excluded.
function _src_assertions() {
  # shellcheck disable=SC2086
  find "$ROOT_DIR/src" -name '*.sh' -print0 |
    xargs -0 "$GREP" -hoE '^function assert_[a-z0-9_]+' |
    sed 's/^function //' | LC_ALL=C sort -u
}

function _documented_assertions() {
  # shellcheck disable=SC2086
  "$GREP" -hoE '^## assert_[a-z0-9_]+$' $DOC_PAGES |
    sed 's/^## //' | LC_ALL=C sort -u
}

# Guards the guard: both extractors returning nothing would make every
# comparison below pass while checking nothing.
function test_both_extractors_find_assertions() {
  assert_greater_than 40 "$(_src_assertions | wc -l)"
  assert_greater_than 40 "$(_documented_assertions | wc -l)"
}

function test_every_assertion_in_src_is_documented() {
  local missing
  missing=$(comm -23 <(_src_assertions) <(_documented_assertions) | tr '\n' ' ')

  assert_empty "$missing"
}

function test_every_documented_assertion_exists_in_src() {
  local unknown
  unknown=$(comm -13 <(_src_assertions) <(_documented_assertions) | tr '\n' ' ')

  assert_empty "$unknown"
}
