#!/usr/bin/env bash

ROOT_DIR=""
PKG_FILE=""

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  PKG_FILE="$ROOT_DIR/package.json"
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

function test_package_json_keeps_docs_scripts() {
  local pkg
  pkg=$(cat "$PKG_FILE")
  assert_contains 'docs:dev' "$pkg"
  assert_contains 'docs:build' "$pkg"
}
