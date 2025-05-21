#!/usr/bin/env bash
set -euo pipefail

function dependencies::has_perl() {
  command -v perl >/dev/null 2>&1
}

function dependencies::has_powershell() {
  command -v powershell > /dev/null 2>&1
}

function dependencies::has_adjtimex() {
  command -v adjtimex >/dev/null 2>&1
}

function dependencies::has_bc() {
  command -v bc >/dev/null 2>&1
}

function dependencies::has_awk() {
  command -v awk >/dev/null 2>&1
}

function dependencies::has_git() {
  command -v git >/dev/null 2>&1
}

function dependencies::has_curl() {
  command -v curl >/dev/null 2>&1
}

function dependencies::has_wget() {
  command -v wget >/dev/null 2>&1
}
