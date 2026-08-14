#!/usr/bin/env bash

# The version is written in four places, and `release.sh` bumps all four
# together (update_install_version, update_action_version,
# update_package_json_version, plus BASHUNIT_VERSION in the entrypoint).
#
# Those updaters are tested against mock files, which proves the functions work
# — not that the repo's own four copies currently agree. They can drift from a
# release that failed partway, a hand-edit, or a merge resolved the wrong way,
# and each copy fails differently and quietly:
#
#   action.yml     every `TypedDevs/bashunit@v0` user installs an old binary
#   install.sh     the documented curl-installer pins the wrong release
#   package.json   npm publishes under a version that is not this code
#
# None of that shows up in a test run, so check it here.

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  EXPECTED=$("$GREP" -oE 'BASHUNIT_VERSION="[0-9]+\.[0-9]+\.[0-9]+"' "$ROOT_DIR/bashunit" |
    head -1 | "$GREP" -oE '[0-9]+\.[0-9]+\.[0-9]+')
}

# Guards the guard: if this extraction ever stops matching, every assertion
# below would compare "" against "" and pass while checking nothing.
function test_the_entrypoint_version_was_actually_found() {
  assert_matches "^[0-9]+\.[0-9]+\.[0-9]+$" "$EXPECTED"
}

function test_the_action_pins_the_current_version() {
  local pinned
  pinned=$("$GREP" -oE "default: '[0-9]+\.[0-9]+\.[0-9]+'" "$ROOT_DIR/action.yml" |
    head -1 | "$GREP" -oE '[0-9]+\.[0-9]+\.[0-9]+')

  assert_same "$EXPECTED" "$pinned"
}

function test_the_installer_pins_the_current_version() {
  local pinned
  pinned=$("$GREP" -oE 'LATEST_BASHUNIT_VERSION="[0-9]+\.[0-9]+\.[0-9]+"' "$ROOT_DIR/install.sh" |
    head -1 | "$GREP" -oE '[0-9]+\.[0-9]+\.[0-9]+')

  assert_same "$EXPECTED" "$pinned"
}

function test_the_npm_package_declares_the_current_version() {
  local declared
  declared=$("$GREP" -oE '"version": "[0-9]+\.[0-9]+\.[0-9]+"' "$ROOT_DIR/package.json" |
    head -1 | "$GREP" -oE '[0-9]+\.[0-9]+\.[0-9]+')

  assert_same "$EXPECTED" "$declared"
}
