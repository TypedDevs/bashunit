#!/usr/bin/env bash

ROOT_DIR=""
PKG_FILE=""
DOCS_PKG_FILE=""

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  PKG_FILE="$ROOT_DIR/package.json"
  DOCS_PKG_FILE="$ROOT_DIR/docs/package.json"
}

function test_package_json_name_is_bashunit() {
  local pkg
  pkg=$(cat "$PKG_FILE")
  assert_matches '"name"[[:space:]]*:[[:space:]]*"bashunit"' "$pkg"
}

function test_package_json_declares_bin_entry() {
  local pkg
  pkg=$(cat "$PKG_FILE")
  assert_matches '"bin"[[:space:]]*:' "$pkg"
  assert_matches '"bashunit"[[:space:]]*:[[:space:]]*"\./bin/bashunit"' "$pkg"
}

function test_package_json_whitelists_publish_files() {
  local pkg
  pkg=$(cat "$PKG_FILE")
  assert_matches '"files"[[:space:]]*:' "$pkg"
  assert_contains 'bin/bashunit' "$pkg"
  assert_contains 'LICENSE' "$pkg"
  assert_contains 'README.md' "$pkg"
}

function test_package_json_restricts_os_to_unix() {
  local pkg
  pkg=$(cat "$PKG_FILE")
  assert_matches '"os"[[:space:]]*:' "$pkg"
  assert_contains '"darwin"' "$pkg"
  assert_contains '"linux"' "$pkg"
}

function test_package_json_keeps_version_field() {
  local pkg
  pkg=$(cat "$PKG_FILE")
  assert_matches '"version"[[:space:]]*:[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' "$pkg"
}

function test_package_json_keeps_checksum_field() {
  local pkg
  pkg=$(cat "$PKG_FILE")
  assert_matches '"checksum"[[:space:]]*:' "$pkg"
}

function test_package_json_excludes_docs_scripts() {
  local pkg
  pkg=$(cat "$PKG_FILE")
  assert_not_contains 'vitepress' "$pkg"
}

function test_docs_package_json_declares_vitepress_scripts() {
  local pkg
  pkg=$(cat "$DOCS_PKG_FILE")
  assert_contains '"dev": "vitepress dev' "$pkg"
  assert_contains '"build": "vitepress build' "$pkg"
  assert_contains '"preview": "vitepress preview' "$pkg"
}

function test_docs_package_json_name_is_bashunit_docs() {
  local pkg
  pkg=$(cat "$DOCS_PKG_FILE")
  assert_matches '"name"[[:space:]]*:[[:space:]]*"bashunit-docs"' "$pkg"
}

function test_package_json_excludes_docs_dependencies() {
  local pkg
  pkg=$(cat "$PKG_FILE")
  assert_not_contains 'vitepress' "$pkg"
  assert_not_contains 'chart.js' "$pkg"
  assert_not_contains 'vanilla-tilt' "$pkg"
  assert_not_contains '"vue"' "$pkg"
}

function test_package_json_declares_no_dependencies_block() {
  local pkg
  pkg=$(cat "$PKG_FILE")
  assert_not_matches '"dependencies"[[:space:]]*:' "$pkg"
  assert_not_matches '"devDependencies"[[:space:]]*:' "$pkg"
  assert_not_matches '"peerDependencies"[[:space:]]*:' "$pkg"
}

function test_package_json_declares_no_scripts_block() {
  local pkg
  pkg=$(cat "$PKG_FILE")
  assert_not_matches '"scripts"[[:space:]]*:' "$pkg"
}

function test_docs_package_json_marked_private() {
  local pkg
  pkg=$(cat "$DOCS_PKG_FILE")
  assert_matches '"private"[[:space:]]*:[[:space:]]*true' "$pkg"
}

function test_docs_package_json_declares_vitepress_devdep() {
  local pkg
  pkg=$(cat "$DOCS_PKG_FILE")
  assert_matches '"devDependencies"[[:space:]]*:' "$pkg"
  assert_contains 'vitepress' "$pkg"
}
